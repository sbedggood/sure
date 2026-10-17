# frozen_string_literal: true

module Tax
  module EntryCandidateTextQuery
    AMOUNT_PATTERN = /\A-?\$?\s*[\d,]+(?:\.\d*)?\z/

    module_function

    def parse_amount_digits(query)
      normalized = query.to_s.gsub(/[$,\s]/, "")
      return nil unless normalized.match?(/\A-?\d+(?:\.\d+)?\z/)

      BigDecimal(normalized.delete_prefix("-")).abs
    rescue ArgumentError
      nil
    end

    def amount_like?(query)
      stripped = query.to_s.strip
      stripped.match?(AMOUNT_PATTERN) && parse_amount_digits(stripped)
    end

    def apply_text_query(scope, query, amount_match: :exact)
      stripped = query.to_s.strip
      return scope if stripped.blank?

      amount = parse_amount_digits(stripped)
      if amount
        apply_amount_query(scope, amount, amount_match)
      else
        like = "%#{ActiveRecord::Base.sanitize_sql_like(stripped)}%"
        scope.where(
          "entries.name ILIKE :q OR COALESCE(entries.notes, '') ILIKE :q OR merchants.name ILIKE :q",
          q: like
        )
      end
    end

    def apply_amount_query(scope, amount, amount_match)
      case amount_match
      when :prefix
        prefix = amount.to_s("F").sub(/\.?0+\z/, "")
        prefix = amount.to_s("F") if prefix.blank?
        pattern = "#{ActiveRecord::Base.sanitize_sql_like(prefix)}%"
        scope.where(
          "TRIM(TRAILING '0' FROM TRIM(TRAILING '.' FROM ABS(entries.amount)::text)) LIKE :pattern",
          pattern: pattern
        )
      else
        scope.where("ABS(entries.amount) = :amount OR entries.amount = :neg", amount: amount, neg: -amount)
      end
    end

    def normalize_amount_key(amount)
      abs = amount.abs
      str = abs.to_s("F")
      str.sub(/\.?0+\z/, "").presence || "0"
    end

    def matches_amount_prefix?(entry, query)
      digits = parse_amount_digits(query)
      return false unless digits

      key = normalize_amount_key(entry.amount)
      needle = normalize_amount_key(digits)
      key.start_with?(needle) || key.gsub(".", "").start_with?(needle.gsub(".", ""))
    end
  end
end
