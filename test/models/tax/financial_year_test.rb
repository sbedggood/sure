# frozen_string_literal: true

require "test_helper"

class Tax::FinancialYearTest < ActiveSupport::TestCase
  test "current start year before and after July" do
    assert_equal 2024, Tax::FinancialYear.current_start_year(on: Date.new(2024, 8, 1))
    assert_equal 2023, Tax::FinancialYear.current_start_year(on: Date.new(2024, 3, 1))
  end

  test "default wfh rate from FY25 onward" do
    assert_equal BigDecimal("0.67"), Tax::FinancialYear.new(2023).default_wfh_hourly_rate
    assert_equal BigDecimal("0.70"), Tax::FinancialYear.new(2024).default_wfh_hourly_rate
  end

  test "weeks start on mondays within range" do
    weeks = Tax::FinancialYear.new(2023).week_commencing_dates
    assert weeks.all?(&:monday?)
    assert weeks.first <= Date.new(2023, 7, 1)
    assert (weeks.first..weeks.first + 6).cover?(Date.new(2023, 7, 1))
  end
end
