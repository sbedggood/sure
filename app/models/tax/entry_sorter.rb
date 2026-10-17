# frozen_string_literal: true

module Tax
  class EntrySorter
    COLUMNS = %w[date name amount].freeze

    def self.sort(entries, sort:, direction:)
      sort, direction = SortParams.parse(sort: sort, direction: direction, allowed: COLUMNS)
      sorted = entries.sort_by { |entry| [ sort_key(entry, sort), entry.id ] }
      direction == "asc" ? sorted : sorted.reverse
    end

    def self.sort_key(entry, sort)
      case sort
      when "name"
        entry.name.to_s.downcase
      when "amount"
        entry.amount.to_d
      else
        entry.date || Date.new(1900, 1, 1)
      end
    end
  end
end
