# frozen_string_literal: true

module Tax
  class PropertyGrid
    attr_reader :financial_year, :settings, :summary_property

    def initialize(family:, start_year:)
      @family = family
      @financial_year = FinancialYear.new(start_year)
      @settings = TaxFySetting.find_or_initialize_for!(family: family, start_year: start_year)
      @summary = Summary.new(family: family, start_year: start_year)
      @summary_property = @summary.as_json[:property]
    end

    def expense_rows
      @summary_property[:expense_rows]
    end

    def rental_rows
      @summary_property.dig(:rental_income, :by_tag) || []
    end

    def months
      @summary_property[:months].map { |iso| Date.iso8601(iso) }
    end

    def cell_amount(tag_name, month)
      row = expense_rows.find { |r| r[:tag] == tag_name }
      return BigDecimal("0") unless row

      BigDecimal(row[:months][month.iso8601].to_s)
    end

    def entries_for_tag_month(tag_name, month)
      month_range = month.beginning_of_month..month.end_of_month
      @family.entries
        .joins("INNER JOIN transactions ON transactions.id = entries.entryable_id AND entries.entryable_type = 'Transaction'")
        .joins("INNER JOIN taggings ON taggings.taggable_id = transactions.id AND taggings.taggable_type = 'Transaction'")
        .joins("INNER JOIN tags ON tags.id = taggings.tag_id")
        .where(date: month_range)
        .where(date: financial_year.range)
        .where(tags: { name: tag_name })
        .includes(:account, entryable: :tags)
        .distinct
        .order(:date)
    end

    def search_entries(query:, tag_name:, month:)
      month_range = month.beginning_of_month..month.end_of_month
      scope = @family.entries
        .joins("INNER JOIN transactions ON transactions.id = entries.entryable_id AND entries.entryable_type = 'Transaction'")
        .where(date: month_range)
        .where(date: financial_year.range)
        .includes(:account, entryable: :tags)
        .order(:date)
        .limit(50)

      if query.present?
        scope = scope.where("entries.name ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%")
      end

      scope.reject { |entry| entry.transaction.tags.any? { |t| t.name == tag_name } }
    end
  end
end
