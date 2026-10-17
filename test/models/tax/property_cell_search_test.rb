# frozen_string_literal: true

require "test_helper"

class Tax::PropertyCellSearchTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @internet_tag = @family.tags.create!(name: "Tax: Property - Internet", color: "#6471eb")
  end

  test "internet september drawer does not suggest unrelated energy retailers" do
    month = Date.new(2025, 9, 1)
    create_transaction(
      account: @account,
      date: Date.new(2024, 8, 1),
      amount: 79,
      currency: "AUD",
      name: "MORE TELECOM",
      merchant: @family.merchants.create!(name: "More Telecom"),
      tags: [ @internet_tag ]
    )
    create_transaction(
      account: @account,
      date: Date.new(2025, 7, 1),
      amount: 95,
      currency: "AUD",
      name: "TELSTRA SERVICES",
      merchant: @family.merchants.create!(name: "Telstra Services"),
      tags: [ @internet_tag ]
    )
    create_transaction(
      account: @account,
      date: Date.new(2025, 9, 10),
      amount: 250.17,
      currency: "AUD",
      name: "Ezi*Supa Energy $250.17"
    )

    search = Tax::PropertyCellSearch.new(
      family: @family,
      tag_name: @internet_tag.name,
      month: month,
      start_year: 2025,
      linked_entry_ids: []
    )

    suggestions = search.suggestions(linked_entries: [])
    assert suggestions.all? { |e| e.name.match?(/telecom|telstra/i) },
      "expected only telecom payees, got: #{suggestions.map(&:name).join(", ")}"
    refute_includes suggestions.map(&:name), "Ezi*Supa Energy $250.17"
  end

  test "internet september drawer suggests only historical telecom payees" do
    month = Date.new(2025, 9, 1)
    create_transaction(
      account: @account,
      date: Date.new(2024, 8, 1),
      amount: 79,
      currency: "AUD",
      name: "MORE TELECOM",
      merchant: @family.merchants.create!(name: "More Telecom"),
      tags: [ @internet_tag ]
    )
    create_transaction(
      account: @account,
      date: Date.new(2025, 10, 2),
      amount: 79,
      currency: "AUD",
      name: "More Telecom South Melbour VIC",
      merchant: @family.merchants.find_or_create_by!(name: "More Telecom South Melbour VIC")
    )
    %w[Almakan Linkt Grouse\ cafe Chemist\ Warehouse].each_with_index do |name, index|
      create_transaction(
        account: @account,
        date: Date.new(2025, 10, 3 + index),
        amount: 20 + index,
        currency: "AUD",
        name: name
      )
    end

    search = Tax::PropertyCellSearch.new(
      family: @family,
      tag_name: @internet_tag.name,
      month: month,
      start_year: 2025,
      linked_entry_ids: []
    )

    suggestions = search.suggestions(linked_entries: [])
    assert_equal 1, suggestions.size
    assert_includes suggestions.first.name, "Telecom"
  end

  test "empty internet cell with no history suggests nothing" do
    month = Date.new(2026, 11, 1)
    create_transaction(
      account: @account,
      date: month + 5,
      amount: 10,
      currency: "AUD",
      name: "Paystay parking"
    )

    search = Tax::PropertyCellSearch.new(
      family: @family,
      tag_name: @internet_tag.name,
      month: month,
      start_year: 2026,
      linked_entry_ids: []
    )

    assert_empty search.suggestions(linked_entries: [])
  end

  test "fy26 telstra search ranks historical telstra services above super contribution" do
    month = Date.new(2025, 9, 1)
    telstra_services = @family.merchants.create!(name: "Telstra Services")
    create_transaction(
      account: @account,
      date: Date.new(2025, 7, 1),
      amount: 95,
      currency: "AUD",
      name: "TELSTRA SERVICES",
      merchant: telstra_services,
      tags: [ @internet_tag ]
    )
    services = create_transaction(
      account: @account,
      date: Date.new(2025, 9, 15),
      amount: 95,
      currency: "AUD",
      name: "TELSTRA SERVICES",
      merchant: telstra_services
    )
    super_payment = create_transaction(
      account: @account,
      date: Date.new(2025, 9, 20),
      amount: 500,
      currency: "AUD",
      name: "TELSTRA SUPER PTYLTD BPAY"
    )

    search = Tax::PropertyCellSearch.new(
      family: @family,
      tag_name: @internet_tag.name,
      month: month,
      start_year: 2025,
      linked_entry_ids: []
    )

    ranked = search.results(query: "telstra", fy_filter: "2025", account_id: nil)
    assert_equal services.id, ranked.first.id
    refute_equal super_payment.id, ranked.first.id
  end

  test "blank search does not surface unrelated transactions" do
    month = Date.new(2025, 9, 1)
    create_transaction(
      account: @account,
      date: Date.new(2024, 8, 1),
      amount: 79,
      currency: "AUD",
      name: "MORE TELECOM",
      merchant: @family.merchants.create!(name: "More Telecom"),
      tags: [ @internet_tag ]
    )
    create_transaction(
      account: @account,
      date: Date.new(2025, 9, 10),
      amount: 250.17,
      currency: "AUD",
      name: "Ezi*Supa Energy $250.17"
    )

    search = Tax::PropertyCellSearch.new(
      family: @family,
      tag_name: @internet_tag.name,
      month: month,
      start_year: 2025,
      linked_entry_ids: []
    )

    assert_empty search.results(query: "", fy_filter: "2025", account_id: nil)
  end

  test "search matches merchant names case insensitively with partial merchant" do
    month = Date.new(2023, 8, 1)
    merchant = @family.merchants.create!(name: "More Telecom South Melbour VIC")
    entry = create_transaction(
      account: @account,
      date: month + 5,
      amount: 88,
      currency: "AUD",
      name: "Utility debit",
      merchant: merchant
    )

    search = Tax::PropertyCellSearch.new(
      family: @family,
      tag_name: @internet_tag.name,
      month: month,
      start_year: 2023,
      linked_entry_ids: []
    )

    results = search.fetch_results(query: "TELECOM", fy_filter: "2023", account_id: nil)
    assert_includes results.map(&:id), entry.id
  end
end
