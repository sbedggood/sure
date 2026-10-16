# frozen_string_literal: true

require "test_helper"

class Tax::ExcelExporterTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @family.tax_fy_settings.create!(start_year: 2023)
  end

  test "builds xlsx package with expected sheets" do
    exporter = Tax::ExcelExporter.new(family: @family, start_year: 2023)
    package = exporter.package
    names = package.workbook.worksheets.map(&:name)

    assert names.any? { |n| n.start_with?("Property FY") }
    assert_includes names, "FY23"
    assert names.any? { |n| n.start_with?("Expenses FY") }
    assert names.any? { |n| n.include?("Calendar") }
  end
end
