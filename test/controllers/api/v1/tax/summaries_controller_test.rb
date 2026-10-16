# frozen_string_literal: true

require "test_helper"

class Api::V1::Tax::SummariesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @oauth_app = Doorkeeper::Application.create!(
      name: "Tax Test App",
      redirect_uri: "https://example.com/callback",
      scopes: "read read_write"
    )
    @read_token = Doorkeeper::AccessToken.create!(
      application: @oauth_app,
      resource_owner_id: @user.id,
      scopes: "read"
    )
    @start_year = 2023
    @user.family.tax_fy_settings.create!(start_year: @start_year)
  end

  test "show summary with oauth token" do
    get "/api/v1/tax/#{@start_year}/summary", headers: { "Authorization" => "Bearer #{@read_token.token}" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal @start_year, body["start_year"]
    assert_equal "FY24", body["label"]
    assert_equal 2024, body["end_year"]
    assert body.key?("property")
    assert body.key?("deductions")
  end

  test "summary accepts fy path shorthand for end year" do
    get "/api/v1/tax/25/summary", headers: { "Authorization" => "Bearer #{@read_token.token}" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2024, body["start_year"]
    assert_equal "FY25", body["label"]
  end

  test "requires authentication" do
    get "/api/v1/tax/#{@start_year}/summary"
    assert_response :unauthorized
  end
end
