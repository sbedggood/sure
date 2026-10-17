# frozen_string_literal: true

require "test_helper"

class Tax::ReviewDecisionsControllerTest < ActionDispatch::IntegrationTest
  include EntriesTestHelper

  setup do
    @user = users(:family_admin)
    sign_in @user
    @family = @user.family
    @account = accounts(:depository)
    @review = @family.tags.create!(name: Tax::TagCatalog::FOR_REVIEW_TAG, color: "#999999")
    @phone = @family.tags.create!(name: "Tax: Phone", color: "#4da568")
    @entry = create_transaction(
      account: @account,
      date: Date.new(2023, 8, 1),
      amount: 30,
      currency: "AUD",
      name: "Review me",
      tags: [ @review ]
    )
  end

  test "decline removes for review and adds declined tag" do
    post tax_review_decline_path, params: { entry_id: @entry.id, start_year: 2023 }

    tags = @entry.transaction.reload.tags.map(&:name)
    assert_includes tags, Tax::TagCatalog::DECLINED_TAG
    refute_includes tags, Tax::TagCatalog::FOR_REVIEW_TAG
  end

  test "accept moves to chosen tag" do
    post tax_review_accept_path, params: { entry_id: @entry.id, start_year: 2023, tag_id: @phone.id }

    tags = @entry.transaction.reload.tags.map(&:name)
    assert_includes tags, "Tax: Phone"
    refute_includes tags, Tax::TagCatalog::FOR_REVIEW_TAG
  end
end
