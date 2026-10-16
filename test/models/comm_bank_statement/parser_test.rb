# frozen_string_literal: true

require "test_helper"

class CommBankStatement::ParserTest < ActiveSupport::TestCase
  test "parses everyday account fixture with balance check" do
    text = file_fixture("commbank_statements/everyday_jul_2024.txt").read
    result = CommBankStatement::Parser.parse_text(text, filename: "everyday.pdf")

    assert_equal :transaction_account, CommBankStatement::Parser.detect_type(text, filename: "everyday.pdf")
    assert result.balance_check_passed, result.balance_check_errors.inspect
    assert_equal 3, result.transactions.size
    assert_equal Date.new(2024, 7, 15), result.transactions.first.date
    assert_equal BigDecimal("-63.2"), result.transactions.first.amount
    assert_equal Date.new(2024, 7, 31), result.period_end_on
  end

  test "parses credit card layout" do
    text = file_fixture("commbank_statements/credit_card_sample.txt").read
    result = CommBankStatement::Parser.parse_text(text, filename: "card.pdf")

    assert_equal :credit_card, CommBankStatement::Parser.detect_type(text, filename: "card.pdf")
    assert result.balance_check_passed, result.balance_check_errors.inspect
    assert_equal 2, result.transactions.size
  end

  test "parses home loan statement" do
    text = file_fixture("commbank_statements/home_loan_sample.txt").read
    result = CommBankStatement::Parser.parse_text(text, filename: "loan.pdf")

    assert_equal :home_loan, CommBankStatement::Parser.detect_type(text, filename: "loan.pdf")
    assert result.balance_check_passed, result.balance_check_errors.inspect
    assert_equal 2, result.transactions.size
  end

  test "skips repayment notice documents" do
    text = file_fixture("commbank_statements/repayment_notice_sample.txt").read

    assert_equal :skipped, CommBankStatement::Parser.detect_type(text, filename: "notice.pdf")
    assert_raises(CommBankStatement::SkippedDocument) do
      CommBankStatement::Parser.parse_text(text, filename: "notice.pdf")
    end
  end

  test "everyday offset marketing copy does not classify as home loan" do
    text = file_fixture("commbank_statements/everyday_jul_2024.txt").read

    refute_equal :home_loan, CommBankStatement::Parser.detect_type(text, filename: "everyday.pdf")
  end

  test "parses fy26 credit card space decimal amounts" do
    text = file_fixture("commbank_statements/fy26_card_space_decimal.txt").read
    result = CommBankStatement::Parser.parse_text(text, filename: "card.pdf")

    assert result.balance_check_passed, result.balance_check_errors.inspect
    assert_equal 2, result.transactions.size
  end

  test "home loan quiet period with no movements passes balance check" do
    text = file_fixture("commbank_statements/home_loan_quiet_period.txt").read
    result = CommBankStatement::Parser.parse_text(text, filename: "loan.pdf")

    assert result.balance_check_passed, result.balance_check_errors.inspect
    assert_equal 0, result.transactions.size
  end

  test "parses fy26 everyday balances without dollar sign" do
    text = file_fixture("commbank_statements/fy26_everyday_no_dollar.txt").read
    result = CommBankStatement::Parser.parse_text(text, filename: "everyday.pdf")

    assert result.balance_check_passed, result.balance_check_errors.inspect
    assert_equal 2, result.transactions.size
    assert_equal BigDecimal("1000"), result.opening_balance
    assert_equal BigDecimal("816.8"), result.closing_balance
  end

  test "credit card interest footer lines are included" do
    text = file_fixture("commbank_statements/credit_card_interest_footer.txt").read
    result = CommBankStatement::Parser.parse_text(text, filename: "card.pdf")

    assert result.balance_check_passed, result.balance_check_errors.inspect
    assert_equal 2, result.transactions.size
  end
end
