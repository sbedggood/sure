# frozen_string_literal: true

require "test_helper"

class CommBankStatement::MappingTest < ActiveSupport::TestCase
  test "before_date_for prefers per-account override" do
    account_id = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    mapping = CommBankStatement::Mapping.new({
      "before_date" => "2024-01-01",
      "accounts" => {
        account_id => { "before_date" => "2026-07-20" }
      }
    })

    assert_equal "2026-07-20", mapping.before_date_for(account_id)
    assert_equal "2024-01-01", mapping.before_date_for("other-account-id")
  end
end
