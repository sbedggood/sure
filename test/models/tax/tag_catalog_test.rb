# frozen_string_literal: true

require "test_helper"

class Tax::TagCatalogTest < ActiveSupport::TestCase
  test "property expense tags are not deduction tags" do
    assert Tax::TagCatalog.property_expense?("Tax: Property - Interest")
    refute Tax::TagCatalog.deduction_tag?("Tax: Property - Interest")
    refute Tax::TagCatalog.deduction_tag?("Tax: Property - Electricity")
  end

  test "rental income and for review are not deduction tags" do
    refute Tax::TagCatalog.deduction_tag?("Tax: Rental Income - Cem")
    refute Tax::TagCatalog.deduction_tag?("Tax: For Review")
  end

  test "work deduction tags qualify" do
    assert Tax::TagCatalog.deduction_tag?("Tax: Phone")
    assert Tax::TagCatalog.deduction_group_tag?("Tax: For Review")
  end

  test "declined tag is excluded from deductions" do
    refute Tax::TagCatalog.deduction_tag?(Tax::TagCatalog::DECLINED_TAG)
    assert Tax::TagCatalog.excluded_from_tax_workflow?(Tax::TagCatalog::DECLINED_TAG)
  end
end
