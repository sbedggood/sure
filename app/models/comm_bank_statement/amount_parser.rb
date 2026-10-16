# frozen_string_literal: true

module CommBankStatement
  module AmountParser
    # Optional $ before amount (FY26 everyday/savings drop the dollar sign on balances).
    BALANCE_AMOUNT_SUFFIX_RE = /(?:\$)?([\d,]+(?:[. ]\d{2}))\s*(CR|DR)\b/i

    module_function

    # Parses "$1,234.56 CR", "1,254.10 CR", "250.00 DR", "$12,199 39", bare "$12.34"
    def parse_balance(value)
      return nil if value.blank?

      normalized = value.to_s.strip
      return BigDecimal("0") if normalized.casecmp("nil").zero?

      cr_dr = nil
      if normalized.match?(/\bCR\b/i)
        cr_dr = :credit
        normalized = normalized.gsub(/\bCR\b/i, "")
      elsif normalized.match?(/\bDR\b/i)
        cr_dr = :debit
        normalized = normalized.gsub(/\bDR\b/i, "")
      end

      amount = parse_money(normalized)
      return nil if amount.nil?

      if cr_dr == :debit
        -amount.abs
      else
        amount.abs
      end
    end

    def parse_money(value)
      return nil if value.blank?

      cleaned = normalize_money_token(value.to_s.strip)
      trailing_negative = cleaned.end_with?("-")
      cleaned = cleaned.delete_suffix("-")
      cleaned = cleaned.delete_prefix("$").delete_prefix("A$").gsub(",", "").strip
      return nil unless cleaned.match?(/^-?\d+(?:\.\d+)?$/)

      amount = BigDecimal(cleaned)
      trailing_negative ? -amount.abs : amount
    end

    def normalize_money_token(value)
      token = value.dup
      if token.match?(/^-?\$?[\d,]+\s+\d{2}-?$/)
        token = token.sub(/\s+(\d{2})(-?)$/, '.\1\2')
      end
      token
    end

    def signed_from_debit_credit(debit, credit)
      debit_amt = parse_money(debit)
      credit_amt = parse_money(credit)

      if debit_amt.present? && debit_amt.nonzero?
        -debit_amt.abs
      elsif credit_amt.present? && credit_amt.nonzero?
        credit_amt.abs
      else
        BigDecimal("0")
      end
    end
  end
end
