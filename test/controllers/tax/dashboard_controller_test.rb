# frozen_string_literal: true

require "test_helper"

class Tax::DashboardControllerTest < ActionDispatch::IntegrationTest
  include ApplicationHelper
  include EntriesTestHelper

  setup do
    sign_in users(:family_admin)
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @phone = @family.tags.create!(name: "Tax: Phone", color: "#4da568")
    @entry = create_transaction(
      account: @account,
      date: Date.new(2023, 10, 16),
      amount: 42,
      currency: "AUD",
      name: "Office supplies",
      tags: [ @phone ]
    )
  end

  test "deductions section shows formatted transaction dates" do
    get tax_dashboard_path(start_year: 2023, section: "deductions")

    assert_response :success
    assert_match format_date(@entry.date, :short_with_year), response.body
    assert_match "Office supplies", response.body
  end

  test "deductions sort links preserve financial year" do
    get tax_dashboard_path(start_year: 2023, section: "deductions", sort: "name", direction: "asc")

    assert_response :success
    assert_match "start_year=2023", response.body
    assert_match "sort=date", response.body
  end
end
