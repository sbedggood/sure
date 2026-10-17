# frozen_string_literal: true

require "test_helper"

class Transactions::TaxDeductionsTransactionViewTest < ActionView::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @user = users(:family_admin)
    @family.update!(currency: "AUD")
    Current.session = Session.create!(user: @user)
    @accessible_account_ids = @user.accessible_accounts.pluck(:id).to_set
    @split_parent_entry_ids = Set.new

    @entry = create_transaction(
      account: @account,
      date: Date.current,
      amount: -50,
      currency: "AUD",
      name: "JB Hi Fi Melbourne"
    )
  end

  test "tax deductions row uses editable category and tags instead of transfer badge" do
    html = render(
      partial: "transactions/transaction",
      locals: {
        entry: @entry,
        view_ctx: "tax_deductions",
        tax_deductions_start_year: 2025
      }
    )

    assert_includes html, Category.uncategorized.display_name
    refute_includes html, I18n.t("categories.virtual.transfer")
    assert_includes html, "tag_dropdown"
    assert_includes html, "category_dropdown"
  end
end
