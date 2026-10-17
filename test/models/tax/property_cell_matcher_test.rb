# frozen_string_literal: true

require "test_helper"

class Tax::PropertyCellMatcherTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @month = Date.new(2025, 9, 1)
    @internet_tag = @family.tags.create!(name: "Tax: Property - Internet", color: "#6471eb")
    @reference = create_transaction(
      account: @account,
      date: Date.new(2024, 9, 10),
      amount: 79,
      currency: "AUD",
      name: "MORE TELECOM SOUTH MELBOUR",
      merchant: @family.merchants.create!(name: "More Telecom"),
      tags: [ @internet_tag ]
    )
    @matcher = Tax::PropertyCellMatcher.new(
      linked_entries: [],
      month: @month,
      reference_entries: [ @reference ]
    )
  end

  test "suggestion candidates only include matching telecom payees" do
    match = create_transaction(
      account: @account,
      date: @month + 10,
      amount: 79,
      currency: "AUD",
      name: "More Telecom South Melbour VIC",
      merchant: @family.merchants.create!(name: "More Telecom South Melbour VIC")
    )
    noise = [
      create_transaction(account: @account, date: @month + 11, amount: 12, currency: "AUD", name: "Almakan"),
      create_transaction(account: @account, date: @month + 12, amount: 8, currency: "AUD", name: "Linkt"),
      create_transaction(account: @account, date: @month + 13, amount: 6, currency: "AUD", name: "Grouse cafe"),
      create_transaction(account: @account, date: @month + 14, amount: 30, currency: "AUD", name: "Chemist Warehouse")
    ]

    ranked = @matcher.suggestion_candidates([ match ] + noise)

    assert_equal [ match.id ], ranked.map { |c| c.entry.id }
  end

  test "returns no suggestions when payee profile is empty" do
    matcher = Tax::PropertyCellMatcher.new(linked_entries: [], month: @month, reference_entries: [])
    noise = create_transaction(
      account: @account,
      date: @month + 2,
      amount: 10,
      currency: "AUD",
      name: "Paystay parking"
    )

    assert_empty matcher.suggestion_candidates([ noise ])
  end
end
