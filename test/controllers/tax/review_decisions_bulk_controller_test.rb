# frozen_string_literal: true

require "test_helper"

class Tax::ReviewDecisionsBulkControllerTest < ActionDispatch::IntegrationTest
  include EntriesTestHelper

  setup do
    sign_in users(:family_admin)
    @family = users(:family_admin).family
    @account = accounts(:depository)
    @review = @family.tags.create!(name: Tax::TagCatalog::FOR_REVIEW_TAG, color: "#999999")
    @phone = @family.tags.create!(name: "Tax: Phone", color: "#4da568")
    @first = create_transaction(
      account: @account,
      date: Date.new(2023, 8, 1),
      amount: 30,
      currency: "AUD",
      name: "First review",
      tags: [ @review ]
    )
    @second = create_transaction(
      account: @account,
      date: Date.new(2023, 8, 2),
      amount: 40,
      currency: "AUD",
      name: "Second review",
      tags: [ @review ]
    )
  end

  test "bulk decline removes for review tags in one transaction" do
    post tax_review_bulk_path,
      params: {
        decision: "decline",
        entry_ids: [ @first.id, @second.id ],
        start_year: 2023,
        sort: "date",
        direction: "desc"
      },
      as: :turbo_stream

    assert_response :success
    [ @first, @second ].each do |entry|
      tags = entry.transaction.reload.tags.map(&:name)
      assert_includes tags, Tax::TagCatalog::DECLINED_TAG
      refute_includes tags, Tax::TagCatalog::FOR_REVIEW_TAG
    end
    assert_includes response.body, %(turbo-stream action="remove")
    assert_includes response.body, "tax-deductions-pending-review"
    assert_includes response.body, "tax-summary-pending-review"
  end

  test "bulk accept moves entries to chosen tag" do
    post tax_review_bulk_path,
      params: {
        decision: "accept",
        tag_id: @phone.id,
        entry_ids: [ @first.id, @second.id ],
        start_year: 2023
      },
      as: :turbo_stream

    assert_response :success
    [ @first, @second ].each do |entry|
      tags = entry.transaction.reload.tags.map(&:name)
      assert_includes tags, "Tax: Phone"
      refute_includes tags, Tax::TagCatalog::FOR_REVIEW_TAG
    end
  end
end
