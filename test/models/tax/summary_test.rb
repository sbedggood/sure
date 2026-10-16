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
end
