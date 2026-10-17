# frozen_string_literal: true

module Tax
  class DocumentLinkSearch
    include EntryCandidateFilters

    def initialize(family:, document:, entries_scope: nil)
      @family = family
      @document = document
      @entries_scope = entries_scope
    end

    def results(query:, fy_filter:, account_id: nil)
      scope = base_scope
      scope = apply_fy_filter(scope, fy_filter)
      scope = apply_account_filter(scope, account_id)

      entries = if query.present?
        fetch_with_query(scope, query)
      else
        scope.order(date: :desc).limit(200).to_a
      end

      DocumentLinkRanker.new(document: @document).rank(entries).first(50)
    end

    private

      def base_scope
        (@entries_scope || @family.entries)
          .joins("INNER JOIN transactions ON transactions.id = entries.entryable_id AND entries.entryable_type = 'Transaction'")
          .joins("LEFT JOIN merchants ON merchants.id = transactions.merchant_id")
          .preload(:account, entryable: :merchant)
      end

      def fetch_with_query(scope, query)
        stripped = query.to_s.strip
        return [] if stripped.blank?

        if EntryCandidateTextQuery.amount_like?(stripped)
          scope.order(date: :desc).limit(500).to_a
            .select { |entry| EntryCandidateTextQuery.matches_amount_prefix?(entry, stripped) }
        else
          EntryCandidateTextQuery.apply_text_query(scope, stripped, amount_match: :prefix)
            .order(date: :desc).limit(100).to_a
        end
      end
  end
end
