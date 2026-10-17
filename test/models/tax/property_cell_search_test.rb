# frozen_string_literal: true

require "test_helper"

class Tax::PropertyCellSearchTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @month = Date.new(2023, 8, 1)
    @tag = @family.tags.create!(name: "Tax: Property - Water", color: "#6471eb")
    @search = Tax::PropertyCellSearch.new(
      family: @family,
      tag_name: @tag.name,
      month: @month,
      start_year: 2023,
      linked_entry_ids: []
    )
  end

  test "search matches notes and merchant name" do
    merchant = @family.merchants.create!(name: "Origin Energy")
    create_transaction(
      account: @account,
      date: @month + 5,
      amount: 88,
      currency: "AUD",
      name: "Utility debit",
      notes: "Quarterly water",
      merchant: merchant
    )

    by_notes = @search.results(query: "quarterly", fy_filter: "2023", account_id: nil)
    by_merchant = @search.results(query: "origin", fy_filter: "2023", account_id: nil)

    assert_equal 1, by_notes.size
    assert_equal 1, by_merchant.size
  end

  test "suggestions exclude zero amounts fees and transfers" do
    create_transaction(
      account: @account,
      date: @month + 2,
      amount: 0,
      currency: "AUD",
      name: "INTNL TRANSACTION FEE, $ 0.69 FEE SAVED"
    )
    create_transaction(
      account: @account,
      date: @month + 3,
      amount: 120,
      currency: "AUD",
      name: "Water bill"
    )

    suggestions = @search.suggestions(linked_entries: [])
    names = suggestions.map(&:name)

    assert_includes names, "Water bill"
    refute names.any? { |n| n.include?("FEE") }
  end

  test "suggestions stay within month plus or minus one" do
    create_transaction(
      account: @account,
      date: @month - 2.months,
      amount: 50,
      currency: "AUD",
      name: "Too early"
    )
    create_transaction(
      account: @account,
      date: @month + 1.month,
      amount: 75,
      currency: "AUD",
      name: "In window"
    )

    suggestions = @search.suggestions(linked_entries: [])
    assert_equal [ "In window" ], suggestions.map(&:name)
  end
end
