# frozen_string_literal: true

require "test_helper"

class Tax::SortParamsTest < ActiveSupport::TestCase
  test "parse whitelists sort columns and defaults direction" do
    sort, direction = Tax::SortParams.parse(sort: "invalid", direction: "sideways", allowed: Tax::DocumentRowSorter::COLUMNS)

    assert_equal "date", sort
    assert_equal "desc", direction
  end

  test "next_direction toggles active column and defaults new columns to desc" do
    assert_equal "asc", Tax::SortParams.next_direction("date", "date", "desc")
    assert_equal "desc", Tax::SortParams.next_direction("date", "amount", "asc")
  end
end
