# frozen_string_literal: true

module Tax
  module SortParams
    DEFAULT_SORT = "date"
    DEFAULT_DIRECTION = "desc"

    module_function

    def parse(sort:, direction:, allowed:, default_sort: DEFAULT_SORT, default_direction: DEFAULT_DIRECTION)
      parsed_sort = allowed.include?(sort.to_s) ? sort.to_s : default_sort
      parsed_direction = %w[asc desc].include?(direction.to_s.downcase) ? direction.to_s.downcase : default_direction
      [ parsed_sort, parsed_direction ]
    end

    def next_direction(current_sort, column, current_direction)
      if current_sort == column
        current_direction == "desc" ? "asc" : "desc"
      else
        DEFAULT_DIRECTION
      end
    end
  end
end
