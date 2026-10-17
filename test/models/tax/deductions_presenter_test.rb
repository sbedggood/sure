# frozen_string_literal: true

require "test_helper"

class Tax::DeductionsPresenterTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @start_year = 2023
    @phone = @family.tags.create!(name: "Tax: Phone", color: "#4da568")
    @review = @family.tags.create!(name: Tax::TagCatalog::FOR_REVIEW_TAG, color: "#999999")
    @electricity = @family.tags.create!(name: "Tax: Property - Electricity", color: "#6471eb")

    create_transaction(
      account: @account,
      date: Date.new(2023, 8, 1),
      amount: 40,
      currency: "AUD",
      name: "Mobile",
      tags: [ @phone ]
    )

    create_transaction(
      account: @account,
      date: Date.new(2023, 8, 2),
      amount: 100,
      currency: "AUD",
      name: "Unknown expense",
      tags: [ @review ]
    )

    create_transaction(
      account: @account,
      date: Date.new(2023, 8, 3),
      amount: 55,
      currency: "AUD",
      name: "Power bill",
      tags: [ @electricity ]
    )
  end

  test "groups deduction tags and excludes property expenses" do
    presenter = Tax::DeductionsPresenter.new(family: @family, start_year: @start_year)
    tags = presenter.groups.map(&:tag)

    assert_includes tags, "Tax: Phone"
    assert_includes tags, Tax::TagCatalog::FOR_REVIEW_TAG
    refute_includes tags, "Tax: Property - Electricity"
  end

  test "payslip tagged income is excluded from deduction groups and claim" do
    payslip = @family.tags.create!(name: Tax::TagCatalog::PAYSLIP_TAG, color: "#6471eb")
    create_transaction(
      account: @account,
      date: Date.new(2023, 8, 4),
      amount: -13_041,
      currency: "AUD",
      name: "Salary",
      tags: [ payslip ]
    )

    presenter = Tax::DeductionsPresenter.new(family: @family, start_year: @start_year)
    tags = presenter.groups.map(&:tag)

    refute_includes tags, Tax::TagCatalog::PAYSLIP_TAG
    assert_equal BigDecimal("40"), presenter.claimable_grand_total
  end

  test "for review is excluded from claim groups" do
    presenter = Tax::DeductionsPresenter.new(family: @family, start_year: @start_year)

    assert presenter.for_review_group
    assert_equal 1, presenter.claim_groups.size
    refute presenter.claim_groups.any?(&:for_review)
    assert_equal BigDecimal("100"), presenter.pending_for_review_total.abs
  end
end
