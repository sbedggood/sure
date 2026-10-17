# frozen_string_literal: true

require "test_helper"

class Tax::PropertyCellMatcherTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @month = Date.new(2023, 8, 1)
    @internet_tag = @family.tags.create!(name: "Tax: Property - Internet", color: "#6471eb")
    @telecom_merchant = @family.merchants.create!(name: "More Telecom")
    @reference = create_transaction(
      account: @account,
      date: Date.new(2022, 5, 10),
      amount: 79,
      currency: "AUD",
      name: "MORE TELECOM SOUTH MELBOUR",
      merchant: @telecom_merchant,
      tags: [ @internet_tag ]
    )
    @matcher = Tax::PropertyCellMatcher.new(
      linked_entries: [],
      month: @month,
      reference_entries: [ @reference ]
    )
  end

  test "ranks merchant partial and amount matches for suggestions" do
    match = create_transaction(
      account: @account,
      date: @month + 10,
      amount: 79,
      currency: "AUD",
      name: "Card purchase",
      merchant: @family.merchants.create!(name: "More Telecom South Melbour VIC")
    )
    noise = create_transaction(
      account: @account,
      date: @month + 11,
      amount: 79,
      currency: "AUD",
      name: "Woolworths"
    )

    ranked = @matcher.suggestion_candidates([ match, noise ])

    assert_equal [ match.id ], ranked.map { |c| c.entry.id }
    assert ranked.first.signals[:merchant_partial]
    assert ranked.first.signals[:amount]
  end

  test "returns no suggestions when score is below threshold" do
    noise = create_transaction(
      account: @account,
      date: @month + 2,
      amount: 12,
      currency: "AUD",
      name: "Local cafe"
    )

    assert_empty @matcher.suggestion_candidates([ noise ])
  end
end
