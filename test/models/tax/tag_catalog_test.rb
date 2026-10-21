# frozen_string_literal: true

require "test_helper"

class Tax::TagCatalogTest < ActiveSupport::TestCase
  test "property expense tags are not deduction tags" do
    assert Tax::TagCatalog.property_expense?("Tax: Property - Interest")
    refute Tax::TagCatalog.deduction_tag?("Tax: Property - Interest")
    refute Tax::TagCatalog.deduction_tag?("Tax: Property - Electricity")
    assert Tax::TagCatalog.property_informational?(Tax::TagCatalog::TENANT_BILL_SHARE_TAG)
    refute Tax::TagCatalog.deduction_tag?(Tax::TagCatalog::TENANT_BILL_SHARE_TAG)
  end

  test "rental income and for review are not deduction tags" do
    refute Tax::TagCatalog.deduction_tag?("Tax: Rental Income - Cem")
    refute Tax::TagCatalog.deduction_tag?("Tax: For Review")
  end

  test "work deduction tags qualify" do
    assert Tax::TagCatalog.deduction_tag?("Tax: Phone")
    assert Tax::TagCatalog.deduction_group_tag?("Tax: For Review")
  end

  test "donations and agent fees are deduction tags with dedicated summary lines" do
    assert Tax::TagCatalog.deduction_tag?(Tax::TagCatalog::DONATIONS_TAG)
    assert Tax::TagCatalog.deduction_tag?(Tax::TagCatalog::AGENT_FEES_TAG)
    assert Tax::TagCatalog.summary_line_tag?(Tax::TagCatalog::DONATIONS_TAG)
    assert Tax::TagCatalog.summary_line_tag?(Tax::TagCatalog::AGENT_FEES_TAG)
    refute Tax::TagCatalog.summary_line_tag?("Tax: Phone")
  end

  test "payslip tag is document only and not a deduction tag" do
    assert Tax::TagCatalog.document_only_tag?(Tax::TagCatalog::PAYSLIP_TAG)
    refute Tax::TagCatalog.deduction_tag?(Tax::TagCatalog::PAYSLIP_TAG)
  end

  test "declined tag is excluded from deductions" do
    refute Tax::TagCatalog.deduction_tag?(Tax::TagCatalog::DECLINED_TAG)
    assert Tax::TagCatalog.excluded_from_tax_workflow?(Tax::TagCatalog::DECLINED_TAG)
  end
end
