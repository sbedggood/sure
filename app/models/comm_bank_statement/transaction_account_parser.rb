# frozen_string_literal: true

module CommBankStatement
  # Everyday / savings / home-loan transaction listings:
  # Date | Transaction | Debit | Credit | Balance
  class TransactionAccountParser
    TABLE_HEADER = "Date\nTransaction\nDebit\nCredit\nBalance\n"
    OPENING_RE = /\A(?<year>\d{4})\s+OPENING\s+BALANCE\z/i
    CLOSING_RE = /\ACLOSING\s+BALANCE\z/i
    DATE_TOKEN_RE = /\A\d{1,2}\s+[A-Za-z]{3}\z/

    def initialize(text)
      @text = text
    end

    def parse
      warnings = []
      transactions = []
      opening_balance = nil
      closing_balance = nil
      year = nil
      prev_date = nil
      prev_balance = nil

      tables = extract_tables
      return empty_result(warnings: [ "No transaction table found" ]) if tables.empty?

      tables.each do |table|
        split_transaction_rows(table).each do |fields|
          next if fields.size < 2

          if (match = fields[1].match(OPENING_RE))
            year = match[:year].to_i
            if opening_balance.nil?
              opening_balance = balance_from_fields(fields) ||
                AmountParser.parse_balance(fields.last)
            end
            prev_date = parse_day_month(fields[0], year)
            prev_balance = opening_balance
            next
          end

          if fields.any? { |f| f.match?(CLOSING_RE) }
            closing_balance = balance_from_fields(fields) || prev_balance
            break
          end

          description_line = fields[1].to_s
          next if description_line.include?("BALANCE CARRIED FORWARD")

          next unless DATE_TOKEN_RE.match?(fields[0])
          next if year.nil?

          date = parse_day_month(fields[0], year)
          if prev_date && prev_date > date
            year += 1
            date = parse_day_month(fields[0], year)
          end

          amount, balance, description = extract_amount_balance_description(fields)
          next if amount.nil? || balance.nil?

          transactions << CommBankStatement::StatementLine.new(
            date: date,
            description: description,
            amount: amount,
            balance: balance,
            raw_lines: fields
          )

          prev_date = date
          prev_balance = balance
        end
      end

      closing_balance = prev_balance if closing_balance.nil?

      ParseResult.new(
        statement_type: :transaction_account,
        period_start_on: transactions.first&.date,
        period_end_on: transactions.last&.date,
        opening_balance: opening_balance,
        closing_balance: closing_balance,
        currency: "AUD",
        transactions: transactions,
        balance_check_passed: false,
        balance_check_errors: [],
        warnings: warnings,
        metadata: {}
      )
    end

    private

      def extract_tables
        @text.split(TABLE_HEADER).drop(1).map { |chunk| chunk.split("\f").first.to_s }
      end

      def split_transaction_rows(table)
        lines = table.lines.map(&:strip).reject(&:empty?)
        rows = []
        current = []

        lines.each do |line|
          if DATE_TOKEN_RE.match?(line)
            rows << current if current.any?
            current = [ line ]
          else
            current << line if current.any?
          end
        end

        rows << current if current.any?
        rows.map { |row| row.map(&:strip).reject(&:empty?) }.reject(&:empty?)
      end

      def balance_from_fields(fields)
        suffix = fields.last if fields.last.to_s.match?(/\A(CR|DR)\z/i)
        money_idx = fields.rindex { |f| f.to_s.match?(/\$?[\d,]+\.\d{2}/) }
        return nil unless money_idx

        tokens = [ fields[money_idx], suffix ].compact.join(" ")
        AmountParser.parse_balance(tokens)
      end

      def extract_amount_balance_description(fields)
        tokens = fields.dup
        tokens.shift # date

        suffix = nil
        if tokens.last.to_s.match?(/\A(CR|DR)\z/i)
          suffix = tokens.pop
        end

        balance = nil
        if tokens.last.to_s.match?(/\$?[\d,]+\.\d{2}/)
          balance = AmountParser.parse_balance([ tokens.pop, suffix ].compact.join(" "))
        end

        debit = nil
        credit = nil
        if tokens.last.to_s.match?(/^[\d,]+\.\d{2}$/)
          debit = tokens.pop
        elsif tokens.last.to_s.match?(/^\$?[\d,]+\.\d{2}$/)
          debit = tokens.pop.delete_prefix("$")
        end

        description = tokens.join(" ").strip
        if description.match?(/INTEREST EARNED/i) && debit.present? && credit.nil?
          credit = debit
          debit = nil
        end
        amount = AmountParser.signed_from_debit_credit(debit, credit)

        [ amount, balance, description.presence || "Transaction" ]
      end

      def parse_day_month(token, year)
        Date.strptime("#{token} #{year}", "%d %b %Y")
      rescue ArgumentError
        Date.strptime("#{token} #{year}", "%e %b %Y")
      end

      def empty_result(warnings:)
        ParseResult.new(
          statement_type: :transaction_account,
          period_start_on: nil,
          period_end_on: nil,
          opening_balance: nil,
          closing_balance: nil,
          currency: "AUD",
          transactions: [],
          balance_check_passed: false,
          balance_check_errors: [ "No transactions parsed" ],
          warnings: warnings,
          metadata: {}
        )
      end
  end
end
