# frozen_string_literal: true

require "test_helper"

class Tax::PropertyCellSearchTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @month = Date.new(2023, 8, 1)
    @tag = @family.tags.create!(name: "Tax: Property - Internet", color: "#6471eb")
    @search = Tax::PropertyCellSearch.new(
      family: @family,
      tag_name: @tag.name,
      month: @month,
      start_year: 2023,
      linked_entry_ids: []
    )
  end

  test "search matches notes and merchant name case insensitively with partial merchant" do
    merchant = @family.merchants.create!(name: "More Telecom South Melbour VIC")
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
    by_merchant = @search.results(query: "TELECOM", fy_filter: "2023", account_id: nil)

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

    assert_empty @search.suggestions(linked_entries: [])
  end

  test "suggestions stay within month plus or minus one" do
    create_transaction(
      account: @account,
      date: Date.new(2022, 6, 1),
      amount: 79,
      currency: "AUD",
      name: "MORE TELECOM",
      tags: [ @tag ]
    )
    telecom_merchant = @family.merchants.find_or_create_by!(name: "More Telecom South Melbour VIC")
    create_transaction(
      account: @account,
      date: @month - 2.months,
      amount: 79,
      currency: "AUD",
      name: "More Telecom South Melbour VIC",
      merchant: telecom_merchant
    )
    in_window = create_transaction(
      account: @account,
      date: @month + 1.month,
      amount: 79,
      currency: "AUD",
      name: "More Telecom South Melbour VIC",
      merchant: telecom_merchant
    )

    suggestions = @search.suggestions(linked_entries: [])
    assert_equal [ in_window.id ], suggestions.map(&:id)
  end

  test "suggestions prefer historical internet merchants over unrelated purchases" do
    create_transaction(
      account: @account,
      date: Date.new(2022, 6, 1),
      amount: 79,
      currency: "AUD",
      name: "MORE TELECOM",
      tags: [ @tag ]
    )
    create_transaction(
      account: @account,
      date: @month + 3,
      amount: 79,
      currency: "AUD",
      name: "More Telecom South Melbour VIC",
      merchant: @family.merchants.create!(name: "More Telecom South Melbour VIC")
    )
    create_transaction(
      account: @account,
      date: @month + 4,
      amount: 79,
      currency: "AUD",
      name: "Spaceship purchase"
    )
    create_transaction(
      account: @account,
      date: @month + 5,
      amount: 79,
      currency: "AUD",
      name: "Woolworths"
    )

    suggestions = @search.suggestions(linked_entries: [])
    assert_equal 1, suggestions.size
    assert_includes suggestions.first.name, "Telecom"
  end

  test "suggestions exclude entries already linked to the cell" do
    create_transaction(
      account: @account,
      date: Date.new(2022, 6, 1),
      amount: 79,
      currency: "AUD",
      name: "MORE TELECOM",
      tags: [ @tag ]
    )
    linked = create_transaction(
      account: @account,
      date: @month + 2,
      amount: 79,
      currency: "AUD",
      name: "More Telecom South Melbour VIC",
      merchant: @family.merchants.create!(name: "More Telecom South Melbour VIC")
    )
    search = Tax::PropertyCellSearch.new(
      family: @family,
      tag_name: @tag.name,
      month: @month,
      start_year: 2023,
      linked_entry_ids: [ linked.id ]
    )

    assert_empty search.suggestions(linked_entries: [ linked ])
  end
end
