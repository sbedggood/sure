# frozen_string_literal: true

require "test_helper"

class Tax::SummaryTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @account.update!(currency: "AUD")
    @start_year = 2023
    @fy = Tax::FinancialYear.new(@start_year)

    @interest_tag = @family.tags.create!(name: "Tax: Property - Interest", color: "#6471eb")
    @phone_tag = @family.tags.create!(name: "Tax: Phone", color: "#4da568")
    @rent_tag = @family.tags.create!(name: "Tax: Rental Income - Cem", color: "#e99537")

    create_transaction(
      account: @account,
      date: Date.new(2023, 8, 15),
      amount: 200,
      currency: "AUD",
      name: "Mortgage interest",
      tags: [ @interest_tag ]
    )

    create_transaction(
      account: @account,
      date: Date.new(2023, 9, 1),
      amount: 50,
      currency: "AUD",
      name: "Mobile plan",
      tags: [ @phone_tag ]
    )

    create_transaction(
      account: @account,
      date: Date.new(2023, 8, 1),
      amount: -1500,
      currency: "AUD",
      name: "Rent received",
      tags: [ @rent_tag ]
    )

    @family.tax_fy_settings.create!(
      start_year: @start_year,
      deduction_business_use_percent: { "Tax: Phone" => 60 }
    )

    @family.tax_weekly_calendar_entries.create!(
      start_year: @start_year,
      week_commencing: Date.new(2023, 7, 3),
      wfh_hours: 10,
      km_driven: 100
    )
  end

  test "builds property and deduction totals from tax tags" do
    summary = Tax::Summary.new(family: @family, start_year: @start_year).as_json

    assert_equal 200.0, summary.dig(:property, :cost_total)
    assert_equal 1500.0, summary.dig(:property, :rental_income, :total)

    phone_line = summary.dig(:deductions, :tag_lines).find { |l| l[:tag] == "Tax: Phone" }
    assert_equal 50.0, phone_line[:amount]
    assert_equal 60.0, phone_line[:business_use_percent]
    assert_equal 30.0, phone_line[:claim]

    assert_equal 10.0, summary.dig(:deductions, :home_office, :wfh_hours_total)
    assert_equal 100.0, summary.dig(:deductions, :car, :km_total)
  end

  test "property interest and rental totals use absolute amounts for mixed signs" do
    create_transaction(
      account: @account,
      date: Date.new(2023, 8, 20),
      amount: -180,
      currency: "AUD",
      name: "Interest from statement",
      tags: [ @interest_tag ]
    )

    create_transaction(
      account: @account,
      date: Date.new(2023, 8, 25),
      amount: 1500,
      currency: "AUD",
      name: "Rent from sync",
      tags: [ @rent_tag ]
    )

    summary = Tax::Summary.new(family: @family, start_year: @start_year).as_json
    interest_row = summary.dig(:property, :expense_rows).find { |r| r[:tag] == "Tax: Property - Interest" }

    assert_equal 380.0, interest_row[:total]
    assert_equal 3000.0, summary.dig(:property, :rental_income, :total)
    assert_equal 380.0, summary.dig(:property, :cost_total)
  end

  test "tenant bill share is informational and excluded from cost total" do
    tenant_tag = @family.tags.create!(name: Tax::TagCatalog::TENANT_BILL_SHARE_TAG, color: "#6471eb")

    create_transaction(
      account: @account,
      date: Date.new(2023, 8, 12),
      amount: -80,
      currency: "AUD",
      name: "Tenant internet share",
      tags: [ tenant_tag ]
    )

    summary = Tax::Summary.new(family: @family, start_year: @start_year).as_json
    property = summary[:property]
    row = property[:informational_rows].find { |r| r[:tag] == tenant_tag.name }

    assert_equal 80.0, row[:total]
    assert_equal 200.0, property[:cost_total]
  end

  test "property totals exclude electricity and non-schedule property tags" do
    electricity = @family.tags.create!(name: "Tax: Property - Electricity", color: "#6471eb")

    create_transaction(
      account: @account,
      date: Date.new(2023, 8, 10),
      amount: 99,
      currency: "AUD",
      name: "Power bill",
      tags: [ electricity ]
    )

    summary = Tax::Summary.new(family: @family, start_year: @start_year).as_json
    assert_equal 200.0, summary.dig(:property, :cost_total)
    assert_nil summary.dig(:property, :expense_rows).find { |r| r[:tag] == electricity.name }
  end

  test "net rental profit yields expected tax payable" do
    @family.tax_fy_settings.find_by(start_year: @start_year).update!(
      property_allocation_percent: 100,
      marginal_tax_rate_percent: 47
    )

    create_transaction(
      account: @account,
      date: Date.new(2023, 8, 2),
      amount: -10_000,
      currency: "AUD",
      name: "Extra rent",
      tags: [ @rent_tag ]
    )

    summary = Tax::Summary.new(family: @family, start_year: @start_year).as_json
    property = summary[:property]

    assert_equal 11_500.0, property[:rental_income][:total]
    assert_equal 200.0, property[:cost_total]
    assert_equal 11_300.0, property[:net_rental]
    assert_equal "payable", property[:expected_tax][:kind]
    assert_in_delta 5_311.0, property[:expected_tax][:amount], 0.01
  end

  test "net rental loss yields positive expected tax refund" do
    @family.tax_fy_settings.find_by(start_year: @start_year).update!(
      property_allocation_percent: 100,
      marginal_tax_rate_percent: 50
    )

    create_transaction(
      account: @account,
      date: Date.new(2023, 8, 3),
      amount: 30_000,
      currency: "AUD",
      name: "Large interest",
      tags: [ @interest_tag ]
    )

    summary = Tax::Summary.new(family: @family, start_year: @start_year).as_json
    property = summary[:property]

    assert_equal 1_500.0, property[:rental_income][:total]
    assert_equal 30_200.0, property[:cost_total]
    assert_equal(-28_700.0, property[:net_rental])
    assert_equal "refund", property[:expected_tax][:kind]
    assert_in_delta 14_350.0, property[:expected_tax][:amount], 0.01
  end

  test "allocated costs apply allocation percent to expense total" do
    @family.tax_fy_settings.find_by(start_year: @start_year).update!(
      property_allocation_percent: 50,
      marginal_tax_rate_percent: 47
    )

    summary = Tax::Summary.new(family: @family, start_year: @start_year).as_json
    property = summary[:property]

    assert_equal 200.0, property[:cost_total]
    assert_equal 100.0, property[:allocated_costs]
    assert_equal 1_400.0, property[:net_rental]
    assert_equal "payable", property[:expected_tax][:kind]
    assert_in_delta 658.0, property[:expected_tax][:amount], 0.01
  end
end
