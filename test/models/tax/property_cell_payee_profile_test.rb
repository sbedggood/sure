# frozen_string_literal: true

require "test_helper"

class Tax::PropertyCellPayeeProfileTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @internet_tag = @family.tags.create!(name: "Tax: Property - Internet", color: "#6471eb")
    @more_telecom = @family.merchants.create!(name: "More Telecom")
    @telstra_services = @family.merchants.create!(name: "Telstra Services")
    @history = [
      create_transaction(
        account: @account,
        date: Date.new(2024, 9, 5),
        amount: 79,
        currency: "AUD",
        name: "MORE TELECOM SOUTH MELBOUR",
        merchant: @more_telecom,
        tags: [ @internet_tag ]
      ),
      create_transaction(
        account: @account,
        date: Date.new(2025, 8, 12),
        amount: 95,
        currency: "AUD",
        name: "TELSTRA SERVICES",
        merchant: @telstra_services,
        tags: [ @internet_tag ]
      )
    ]
    @profile = Tax::PropertyCellPayeeProfile.from_entries(@history)
  end

  test "matches telecom payees from internet history only" do
    telecom_candidate = create_transaction(
      account: @account,
      date: Date.new(2025, 10, 3),
      amount: 79,
      currency: "AUD",
      name: "More Telecom South Melbour VIC",
      merchant: @family.merchants.create!(name: "More Telecom South Melbour VIC")
    )
    noise = create_transaction(
      account: @account,
      date: Date.new(2025, 10, 4),
      amount: 42,
      currency: "AUD",
      name: "Grouse cafe"
    )

    assert @profile.matches_entry?(telecom_candidate)
    refute @profile.matches_entry?(noise)
  end

  test "does not treat telstra super as internet payee history" do
    super_payment = create_transaction(
      account: @account,
      date: Date.new(2025, 10, 1),
      amount: 500,
      currency: "AUD",
      name: "TELSTRA SUPER PTYLTD BPAY"
    )

    refute @profile.matches_entry?(super_payment)
  end
end
