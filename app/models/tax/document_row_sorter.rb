# frozen_string_literal: true

module Tax
  class DocumentRowSorter
    COLUMNS = %w[date merchant amount period type file].freeze

    def self.sort(rows, sort:, direction:)
      sort, direction = SortParams.parse(sort: sort, direction: direction, allowed: COLUMNS)
      return sort_by_amount(rows, direction) if sort == "amount"

      sorted = rows.sort_by { |row| [ sort_key(row, sort), row.filename.to_s.downcase ] }
      direction == "asc" ? sorted : sorted.reverse
    end

    def self.sort_by_amount(rows, direction)
      with_amount, without_amount = rows.partition { |row| row.entry_amount.present? }
      sorted = with_amount.sort_by { |row| row.entry_amount.to_d }
      sorted.reverse! if direction == "desc"
      sorted + without_amount
    end

    def self.sort_key(row, sort)
      case sort
      when "merchant"
        (row.entry_name.presence || row.filename).to_s.downcase
      when "amount"
        row.entry_amount&.to_d || BigDecimal("0")
      when "date"
        row.entry_date || Date.new(1900, 1, 1)
      when "period"
        [ row.start_year, row.period_label.to_s.downcase ]
      when "type"
        row.document_type.to_s.downcase
      when "file"
        row.filename.to_s.downcase
      else
        row.entry_date || Date.new(1900, 1, 1)
      end
    end
  end
end
