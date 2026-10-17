# frozen_string_literal: true

require "test_helper"

class Tax::EntrySorterTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @account = accounts(:depository)
  end

  test "sorts entries by amount ascending" do
    high = create_transaction(account: @account, date: Date.new(2023, 5, 1), amount: 200, currency: "AUD", name: "High")
    low = create_transaction(account: @account, date: Date.new(2023, 5, 2), amount: 50, currency: "AUD", name: "Low")

    sorted = Tax::EntrySorter.sort([ high, low ], sort: "amount", direction: "asc")

    assert_equal [ low.id, high.id ], sorted.map(&:id)
  end

  test "defaults invalid direction to desc for date" do
    older = create_transaction(account: @account, date: Date.new(2023, 4, 1), amount: 10, currency: "AUD", name: "Old")
    newer = create_transaction(account: @account, date: Date.new(2023, 8, 1), amount: 10, currency: "AUD", name: "New")

    sorted = Tax::EntrySorter.sort([ older, newer ], sort: "date", direction: "sideways")

    assert_equal [ newer.id, older.id ], sorted.map(&:id)
  end
end
