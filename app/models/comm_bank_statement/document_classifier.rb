# frozen_string_literal: true

module CommBankStatement
  module DocumentClassifier
    module_function

    Skipped = Data.define(:reason)

    def classify(text, filename: nil)
      normalized = TextNormalizer.normalize(text)

      skip = detect_skip(normalized, filename: filename)
      return skip if skip

      if credit_card_statement?(normalized)
        :credit_card
      elsif home_loan_statement?(normalized)
        :home_loan
      else
        :transaction_account
      end
    end

    def detect_skip(text, filename: nil)
      if text.match?(/minimum repayments are increasing for your home loan/i) ||
          text.match?(/Your new minimum monthly required repayment/i) ||
          text.match?(/Your new monthly minimum/i) && text.match?(/Direct Debit/i) && !text.match?(/Date\s+Transaction.*Balance/i)
        return Skipped.new(reason: "home_loan_repayment_notice")
      end

      nil
    end

    def credit_card_statement?(text)
      return true if text.match?(/Amount\s*\(A\$\)/i) && text.match?(/Transactions/i)
      return true if text.match?(/Opening balance at\s+\d{1,2}\s+[A-Za-z]{3}/i)
      return true if text.match?(/Ultimate Awards Credit Card/i)
      return true if text.match?(/Credit limit/i) && text.match?(/Closing balance at/i)

      false
    end

    def home_loan_statement?(text)
      return true if text.match?(/Complete Home Loan/i) && text.match?(/Loan balance/i)
      return true if text.match?(/Transaction description.*Debits.*Credits.*Balance/i)
      return true if text.match?(/Complete Home Loan Transactions/i)

      false
    end
  end
end
