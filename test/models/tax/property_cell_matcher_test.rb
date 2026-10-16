# frozen_string_literal: true

require "test_helper"

class Tax::PropertyCellMatcherTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @month = Date.new(2023, 8, 1)
    @linked = [
      create_transaction(account: @account, date: @month + 5, amount: 120, currency: "AUD", name: "Origin Energy")
    ]
    @candidate = create_transaction(account: @account, date: @month + 10, amount: 120, currency: "AUD", name: "Origin Energy bill")
  end

  test "ranks exact amount matches higher" do
    matcher = Tax::PropertyCellMatcher.new(linked_entries: @linked, month: @month)
    ranked = matcher.rank([ @candidate ])

    assert_equal @candidate.id, ranked.first.entry.id
    assert ranked.first.signals[:amount]
  end
end
