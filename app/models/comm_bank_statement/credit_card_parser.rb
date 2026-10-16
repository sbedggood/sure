# frozen_string_literal: true

module CommBankStatement
  # Credit card statements: Date | Transaction (details) | Amount (single column).
  class CreditCardParser
    HEADER_MARKERS = [
      "Date\nTransaction\nAmount\n",
      "Date\nTransaction Details\nCard used\nAmount\n",
      "Date\nTransaction Details\nAmount\n"
    ].freeze

    DATE_LINE_RE = /\A(\d{1,2}\s+[A-Za-z]{3})\s+(.+)\s+(-?\$?[\d,]+\.\d{2})\z/
    OPENING_RE = /opening\s+balance/i
    CLOSING_RE = /closing\s+balance/i

    def initialize(text)
      @text = text
    end

    def parse
      warnings = []
      year = infer_year
      transactions = []
      opening_balance = extract_summary_amount(OPENING_RE)
      closing_balance = extract_summary_amount(CLOSING_RE)

      body = extract_body
      if body.blank?
        return ParseResult.new(
          statement_type: :credit_card,
          period_start_on: nil,
          period_end_on: nil,
          opening_balance: opening_balance,
          closing_balance: closing_balance,
          currency: "AUD",
          transactions: [],
          balance_check_passed: false,
          balance_check_errors: [ "No credit card transaction section found" ],
          warnings: warnings,
          metadata: {}
        )
      end

      body.each_line do |line|
        line = line.strip
        next if line.blank?
        next if line.match?(OPENING_RE) || line.match?(CLOSING_RE)

        match = line.match(DATE_LINE_RE)
        next unless match

        date = parse_day_month(match[1], year)
        amount = AmountParser.parse_money(match[3])
        transactions << CommBankStatement::StatementLine.new(
          date: date,
          description: match[2].strip,
          amount: amount,
          balance: nil,
          raw_lines: [ line ]
        )
      end

      ParseResult.new(
        statement_type: :credit_card,
        period_start_on: infer_period_start(year),
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

      def extract_body
        HEADER_MARKERS.each do |marker|
          return @text.split(marker, 2).last if @text.include?(marker)
        end
        nil
      end

      def infer_year
        if (match = @text.match(/(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})\s*(?:to|-)\s*(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})/i))
          Date.strptime(match[1], "%d %b %Y").year
        elsif (match = @text.match(/Statement period[:\s]+(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})/i))
          Date.strptime(match[1], "%d %b %Y").year
        else
          Date.current.year
        end
      rescue ArgumentError
        Date.current.year
      end

      def infer_period_start(year)
        if (match = @text.match(/(\d{1,2}\s+[A-Za-z]{3})\s*(?:to|-)\s*(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})/i))
          parse_day_month(match[1], year)
        end
      rescue ArgumentError
        nil
      end

      def extract_summary_amount(pattern)
        line = @text.lines.find { |l| l.match?(pattern) }
        return nil unless line

        if (amount_match = line.match(/\$?([\d,]+\.\d{2})/))
          AmountParser.parse_money(amount_match[1])
        end
      end

      def parse_day_month(token, year)
        Date.strptime("#{token} #{year}", "%d %b %Y")
      rescue ArgumentError
        Date.strptime("#{token} #{year}", "%e %b %Y")
      end
  end
end
