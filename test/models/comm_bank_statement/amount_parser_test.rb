# frozen_string_literal: true

require "test_helper"

class CommBankStatement::AmountParserTest < ActiveSupport::TestCase
  test "parse_balance handles CR and DR suffixes" do
    assert_equal BigDecimal("1000"), CommBankStatement::AmountParser.parse_balance("$1,000.00 CR")
    assert_equal BigDecimal("-50"), CommBankStatement::AmountParser.parse_balance("50.00 DR")
  end

  test "signed_from_debit_credit prefers debit column" do
    amount = CommBankStatement::AmountParser.signed_from_debit_credit("63.20", nil)
    assert_equal BigDecimal("-63.2"), amount
  end

  test "parse_money treats trailing minus as credit card payment" do
    assert_equal BigDecimal("-8141.93"), CommBankStatement::AmountParser.parse_money("8,141.93-")
  end
end
