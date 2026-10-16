# frozen_string_literal: true

require "test_helper"

class CommBankStatement::ParserTest < ActiveSupport::TestCase
  test "parses everyday account fixture with balance check" do
    text = file_fixture("commbank_statements/everyday_jul_2024.txt").read
    result = CommBankStatement::Parser.parse_text(text, filename: "everyday.pdf")

    assert_equal :transaction_account, result.statement_type
    assert result.balance_check_passed, result.balance_check_errors.inspect
    assert_equal 3, result.transactions.size
    assert_equal Date.new(2024, 7, 15), result.transactions.first.date
    assert_equal BigDecimal("-63.2"), result.transactions.first.amount
    assert_equal Date.new(2024, 7, 31), result.period_end_on
  end

  test "detects credit card layout" do
    text = <<~TEXT
      Awards Credit Card
      Statement period 1 Jul 2024 to 31 Jul 2024
      Opening balance $500.00
      Closing balance $650.00
      Date
      Transaction
      Amount
      15 Jul COLES 0663 ALTONA 63.20
      20 Jul PAYMENT RECEIVED -200.00
    TEXT

    result = CommBankStatement::Parser.parse_text(text, filename: "card.pdf")
    assert_equal :credit_card, result.statement_type
    assert_equal 2, result.transactions.size
  end
end
