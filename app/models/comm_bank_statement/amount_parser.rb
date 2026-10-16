# frozen_string_literal: true

module CommBankStatement
  module AmountParser
    module_function

    # Parses "$1,234.56 CR", "250.00 DR", "Nil", bare "$12.34"
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

    # Debit/credit column cell: "$63.20" or empty
    def parse_money(value)
      return nil if value.blank?

      cleaned = value.to_s.strip
      cleaned = cleaned.delete_prefix("$").delete_prefix("A$").gsub(",", "").strip
      return nil unless cleaned.match?(/^-?\d+(?:\.\d+)?$/)

      BigDecimal(cleaned)
    end

    # Signed movement from debit/credit columns (asset account convention).
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
