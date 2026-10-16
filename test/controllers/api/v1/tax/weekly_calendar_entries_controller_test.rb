# frozen_string_literal: true

require "test_helper"

class Api::V1::Tax::WeeklyCalendarEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @oauth_app = Doorkeeper::Application.create!(
      name: "Tax Calendar App",
      redirect_uri: "https://example.com/callback",
      scopes: "read read_write"
    )
    @read_token = Doorkeeper::AccessToken.create!(
      application: @oauth_app,
      resource_owner_id: @user.id,
      scopes: "read"
    )
    @write_token = Doorkeeper::AccessToken.create!(
      application: @oauth_app,
      resource_owner_id: @user.id,
      scopes: "read_write"
    )
    @start_year = 2023
  end

  test "bulk upsert calendar entries" do
    put "/api/v1/tax/#{@start_year}/weekly_calendar_entries/bulk",
      params: {
        entries: [
          { week_commencing: "2023-07-03", wfh_hours: 8, km_driven: 12, note: "Client site" }
        ]
      },
      headers: { "Authorization" => "Bearer #{@write_token.token}" },
      as: :json

    assert_response :success
    entry = @user.family.tax_weekly_calendar_entries.find_by(week_commencing: Date.new(2023, 7, 3))
    assert_equal 8, entry.wfh_hours.to_f
    assert_equal 12, entry.km_driven.to_f
  end

  test "index lists entries" do
    @user.family.tax_weekly_calendar_entries.create!(
      start_year: @start_year,
      week_commencing: Date.new(2023, 7, 10),
      wfh_hours: 4
    )

    get "/api/v1/tax/#{@start_year}/weekly_calendar_entries",
      headers: { "Authorization" => "Bearer #{@read_token.token}" }

    assert_response :success
    assert_equal 1, JSON.parse(response.body).length
  end
end
