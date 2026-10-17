# frozen_string_literal: true

require "test_helper"

class Tax::DocumentTypeTest < ActiveSupport::TestCase
  test "infers payslip from payslip tag" do
    assert_equal "payslip", Tax::DocumentType.infer_from_tag_names([ "Tax: Payslip", "Tax: Phone" ])
  end

  test "defaults to receipt for other tax tags" do
    assert_equal "receipt", Tax::DocumentType.infer_from_tag_names([ "Tax: Phone" ])
  end
end
