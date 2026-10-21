# frozen_string_literal: true

module Tax
  class DeductionsPresenter
    DEDUCTION_ENTRY_INCLUDES = [
      :account,
      :parent_entry,
      entryable: [ :tags, :category, :merchant, { attachments_attachments: :blob } ],
      parent_entry: { entryable: { attachments_attachments: :blob } }
    ].freeze

    Group = Data.define(:tag, :tag_record, :entries, :total_amount, :claim_amount, :for_review)

    attr_reader :financial_year, :settings

    def initialize(family:, start_year:, sort: nil, direction: nil)
      @family = family
      @financial_year = FinancialYear.new(start_year)
      @settings = TaxFySetting.find_or_initialize_for!(family: family, start_year: start_year)
      @settings.save! if @settings.new_record?
      @sort, @direction = SortParams.parse(sort: sort, direction: direction, allowed: EntrySorter::COLUMNS)
    end

    def groups
      @groups ||= build_groups
    end

    def claim_groups
      groups.reject(&:for_review)
    end

    def for_review_group
      groups.find(&:for_review)
    end

    def claimable_grand_total
      claim_groups.sum(&:claim_amount) + calendar_claims
    end

    def pending_for_review_total
      for_review_group&.total_amount&.abs || BigDecimal("0")
    end

    def tax_tags_for_select
      @family.tags.where("name LIKE ?", "Tax:%").order(:name)
    end

    private

      def build_groups
        grouped = Hash.new { |h, k| h[k] = [] }
        tax_tags_by_name = @family.tags.where("name LIKE ?", "Tax:%").index_by(&:name)

        entries_in_fy.each do |entry|
          next if entry_declined?(entry)

          entry.entryable.tags.each do |tag|
            next unless TagCatalog.deduction_group_tag?(tag.name)

            grouped[tag.name] << entry
          end
        end

        ordered_names = grouped.keys.sort_by { |name| for_review_name?(name) ? "zzz" : name }

        ordered_names.map do |tag_name|
          entries = EntrySorter.sort(grouped[tag_name].uniq, sort: @sort, direction: @direction)
          total = entries.sum { |e| e.amount }
          for_review = TagCatalog.for_review?(tag_name)
          percent = settings.business_use_percent_for(tag_name)
          claim = for_review ? BigDecimal("0") : (total * percent / 100)
          Group.new(
            tag: tag_name,
            tag_record: tax_tags_by_name[tag_name],
            entries: entries,
            total_amount: total,
            claim_amount: claim,
            for_review: for_review
          )
        end
      end

      def entries_in_fy
        @entries_in_fy ||= @family.entries
          .joins("INNER JOIN transactions ON transactions.id = entries.entryable_id AND entries.entryable_type = 'Transaction'")
          .joins("INNER JOIN taggings ON taggings.taggable_id = transactions.id AND taggings.taggable_type = 'Transaction'")
          .joins("INNER JOIN tags ON tags.id = taggings.tag_id")
          .where(date: financial_year.range)
          .where("tags.name LIKE ?", "Tax:%")
          .includes(DEDUCTION_ENTRY_INCLUDES)
          .distinct
          .order(date: :desc)
      end

      def calendar_claims
        calendar = Summary.new(family: @family, start_year: financial_year.start_year).as_json[:deductions]
        BigDecimal(calendar.dig(:home_office, :claim).to_s) +
          BigDecimal(calendar.dig(:car, :claim).to_s)
      end

      def for_review_name?(name)
        TagCatalog.for_review?(name)
      end

      def entry_declined?(entry)
        entry.entryable.tags.any? { |t| TagCatalog.declined?(t.name) }
      end
  end
end
