# frozen_string_literal: true

require "test_helper"

class Tax::PropertyCellsControllerTest < ActionDispatch::IntegrationTest
  include EntriesTestHelper

  setup do
    sign_in users(:family_admin)
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @tag = @family.tags.create!(name: "Tax: Property - Internet", color: "#6471eb")
    @month = Date.new(2025, 9, 1)
    create_transaction(account: @account, date: Date.new(2025, 9, 5), amount: 10, currency: "AUD", name: "Small")
    create_transaction(account: @account, date: Date.new(2025, 9, 10), amount: 99, currency: "AUD", name: "Large")
  end

  test "show sorts search results by amount when requested" do
    get tax_property_cell_path(
      tag_name: @tag.name,
      month: @month.iso8601,
      start_year: 2025,
      fy: "2025",
      account_id: @account.id,
      sort: "amount",
      direction: "asc"
    )

    assert_response :success
    names = response.body.scan(/<p class="text-sm text-primary truncate">([^<]+)<\/p>/).flatten
    assert_equal [ "Small", "Large" ], names.first(2)
  end
end
