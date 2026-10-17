# frozen_string_literal: true

module Tax
  class PropertyCellSearch
    FEE_NAME_PATTERN = /fee|surcharge|international transaction/i

    attr_reader :family, :tag_name, :month, :financial_year, :linked_entry_ids

    def initialize(family:, tag_name:, month:, start_year:, linked_entry_ids: [])
      @family = family
      @tag_name = tag_name
      @month = month
      @financial_year = FinancialYear.new(start_year)
      @linked_entry_ids = linked_entry_ids.map(&:to_s)
    end

    def results(query:, fy_filter:, account_id: nil)
      entries = fetch_results(query: query, fy_filter: fy_filter, account_id: account_id)
      rank_search_results(entries, query)
    end

    def suggestions(linked_entries:)
      reference_entries = reference_entries_for_matching(linked_entries)
      payee_profile = PropertyCellPayeeProfile.from_entries(reference_entries)
      return [] if payee_profile.empty?

      range = (@month - 1.month).beginning_of_month..(@month + 1.month).end_of_month
      scope = base_scope.where(date: range)
      candidates = scope.order(date: :desc).limit(100).to_a
      candidates.reject! { |entry| linked_to_cell?(entry) || already_tagged?(entry) || exclude_from_suggestions?(entry) }
      matcher = PropertyCellMatcher.new(
        linked_entries: linked_entries,
        month: @month,
        reference_entries: reference_entries,
        payee_profile: payee_profile
      )
      matcher.suggestion_candidates(candidates).first(8).map(&:entry)
    end

    def fetch_results(query:, fy_filter:, account_id: nil)
      scope = base_scope
      scope = apply_fy_filter(scope, fy_filter)
      scope = apply_account_filter(scope, account_id)
      scope = apply_text_query(scope, query) if query.present?
      scope.order(date: :desc).limit(100).to_a
        .reject { |entry| linked_entry_ids.include?(entry.id) || already_tagged?(entry) }
        .first(50)
    end

    def rank_search_results(entries, query)
      reference_entries = reference_entries_for_matching([])
      payee_profile = PropertyCellPayeeProfile.from_entries(reference_entries)
      PropertyCellSearchRanker.new(payee_profile: payee_profile, query: query).rank(entries)
    end

    def reference_entries_for_matching(linked_entries)
      (linked_entries + historical_tagged_entries).uniq(&:id)
    end

    def historical_tagged_entries
      @historical_tagged_entries ||= family.entries
        .joins("INNER JOIN transactions ON transactions.id = entries.entryable_id AND entries.entryable_type = 'Transaction'")
        .joins("INNER JOIN taggings ON taggings.taggable_id = transactions.id AND taggings.taggable_type = 'Transaction'")
        .joins("INNER JOIN tags ON tags.id = taggings.tag_id")
        .where(tags: { name: tag_name })
        .includes(:account, entryable: :merchant)
        .distinct
        .to_a
    end

    def linked_to_cell?(entry)
      linked_entry_ids.include?(entry.id)
    end

    def exclude_from_suggestions?(entry)
      entry.amount.abs.zero? ||
        entry.transaction.transfer? ||
        fee_like?(entry)
    end

    private

      def base_scope
        family.entries
          .joins("INNER JOIN transactions ON transactions.id = entries.entryable_id AND entries.entryable_type = 'Transaction'")
          .joins("LEFT JOIN merchants ON merchants.id = transactions.merchant_id")
          .includes(:account, entryable: [ :tags, :merchant ])
      end

      def already_tagged?(entry)
        entry.transaction.tags.any? { |t| t.name == tag_name || TagCatalog.declined?(t.name) }
      end

      def apply_fy_filter(scope, fy_filter)
        return scope if fy_filter.blank? || fy_filter == "all"

        fy = FinancialYear.new(fy_filter.to_i)
        scope.where(date: fy.range)
      end

      def apply_account_filter(scope, account_id)
        return scope if account_id.blank?

        scope.where(account_id: account_id)
      end

      def apply_text_query(scope, query)
        stripped = query.to_s.strip
        return scope if stripped.blank?

        amount = parse_amount(stripped)
        if amount
          scope.where("ABS(entries.amount) = :amount OR entries.amount = :neg", amount: amount, neg: -amount)
        else
          like = "%#{ActiveRecord::Base.sanitize_sql_like(stripped)}%"
          scope.where(
            "entries.name ILIKE :q OR COALESCE(entries.notes, '') ILIKE :q OR merchants.name ILIKE :q",
            q: like
          )
        end
      end

      def parse_amount(query)
        normalized = query.gsub(/[$,\s]/, "")
        return nil unless normalized.match?(/\A-?\d+(?:\.\d+)?\z/)

        BigDecimal(normalized.delete_prefix("-")).abs
      rescue ArgumentError
        nil
      end

      def fee_like?(entry)
        entry.name.to_s.match?(FEE_NAME_PATTERN)
      end
  end
end
