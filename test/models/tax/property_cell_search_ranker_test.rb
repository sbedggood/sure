# frozen_string_literal: true

require "test_helper"

class Tax::PropertyCellSearchRankerTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @internet_tag = @family.tags.create!(name: "Tax: Property - Internet", color: "#6471eb")
    @telstra_services = @family.merchants.create!(name: "Telstra Services")
    history = create_transaction(
      account: @account,
      date: Date.new(2025, 7, 1),
      amount: 95,
      currency: "AUD",
      name: "TELSTRA SERVICES",
      merchant: @telstra_services,
      tags: [ @internet_tag ]
    )
    @profile = Tax::PropertyCellPayeeProfile.from_entries([ history ])
    @ranker = Tax::PropertyCellSearchRanker.new(payee_profile: @profile, query: "telstra")
  end

  test "ranks telstra services bill above telstra super bpay" do
    services = create_transaction(
      account: @account,
      date: Date.new(2025, 9, 15),
      amount: 95,
      currency: "AUD",
      name: "TELSTRA SERVICES",
      merchant: @telstra_services
    )
    super_payment = create_transaction(
      account: @account,
      date: Date.new(2025, 9, 20),
      amount: 500,
      currency: "AUD",
      name: "TELSTRA SUPER PTYLTD BPAY"
    )

    ranked = @ranker.rank([ super_payment, services ])
    assert_equal services.id, ranked.first.id
  end

  test "ranks telstra services above super when super merchant is telstra" do
    services = create_transaction(
      account: @account,
      date: Date.new(2025, 9, 15),
      amount: 95,
      currency: "AUD",
      name: "TELSTRA SERVICES",
      merchant: @telstra_services
    )
    super_payment = create_transaction(
      account: @account,
      date: Date.new(2025, 9, 22),
      amount: 500,
      currency: "AUD",
      name: "TELSTRA SUPER PTYLTD BPAY",
      merchant: @family.merchants.create!(name: "Telstra")
    )

    ranked = @ranker.rank([ super_payment, services ])
    assert_equal services.id, ranked.first.id
  end
end
