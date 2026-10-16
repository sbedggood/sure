# frozen_string_literal: true

module CommBankStatement
  # Parsed statement in bank-native signed amounts: credits increase asset
  # balances (positive movement), debits decrease them (negative movement).
  # Callers convert to Sure entry amounts per accountable type.
  ParseResult = Data.define(
    :statement_type,
    :period_start_on,
    :period_end_on,
    :opening_balance,
    :closing_balance,
    :currency,
    :transactions,
    :balance_check_passed,
    :balance_check_errors,
    :warnings,
    :metadata
  ) do
    def success?
      balance_check_passed && transactions.any?
    end
  end
end
