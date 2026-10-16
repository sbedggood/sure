# frozen_string_literal: true

require "test_helper"

class Tax::ExportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    sign_in @user
    @user.family.tax_fy_settings.create!(start_year: 2024)
  end

  test "export with fy param returns xlsx" do
    get tax_export_path(format: :xlsx), params: { fy: 25 }

    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", response.media_type
    assert_match(/FY25_tax_export\.xlsx/, response.headers["Content-Disposition"])
  end

  test "export with start_year param returns xlsx" do
    get tax_export_path, params: { start_year: 2024 }

    assert_response :success
    assert_match(/FY25_tax_export\.xlsx/, response.headers["Content-Disposition"])
  end
end
