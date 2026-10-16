# frozen_string_literal: true

module CommBankStatement
  class CreditCardParser
    TXN_LINE_RE = /^\s*(\d{1,2}\s+[A-Za-z]{3})\s+(.*?)\s+(-?\$?[\d,]+\.\d{2}-?)\s*$/i
    ROW_START_RE = /^\s*(\d{1,2}\s+[A-Za-z]{3})\s+(.*)$/i
    OPENING_SUMMARY_RE = /Opening balance at\s+\d{1,2}\s+[A-Za-z]{3}\s+\$?([\d,]+\.\d{2})/i
    CLOSING_SUMMARY_RE = /Closing balance at\s+\d{1,2}\s+[A-Za-z]{3}\s+\$?([\d,]+\.\d{2})/i
    SKIP_LINE_RE = /Awards (transaction details|points summary|membership number)/i

    def initialize(text)
      @text = text
    end

    def parse
      period = PeriodParser.parse(@text)
      year = period&.start_on&.year || Date.current.year
      opening_balance = extract_summary_amount(OPENING_SUMMARY_RE)
      closing_balance = extract_summary_amount(CLOSING_SUMMARY_RE)

      transactions = []
      prev_date = nil
      buffer = []

      @text.each_line do |line|
        next if line.match?(SKIP_LINE_RE)
        next if TextNormalizer.margin_noise_line?(line)

        stripped = line.strip
        next if stripped.empty?
        next if stripped.match?(/^Date\s+Transaction details/i)
        next if stripped.match?(/^Amount\s*\(A\$\)/i)
        next if stripped.match?(/^Transactions$/i)
        next if stripped.match?(/^##\s/)

        if ROW_START_RE.match?(line)
          txn = build_from_buffer(buffer, year: year, prev_date: prev_date)
          if txn
            transactions << txn
            prev_date = txn.date
            year = txn.date.year
          end
          buffer = [ line ]
        elsif buffer.any?
          buffer << line
        end
      end

      txn = build_from_buffer(buffer, year: year, prev_date: prev_date)
      transactions << txn if txn

      ParseResult.new(
        statement_type: :credit_card,
        period_start_on: period&.start_on,
        period_end_on: period&.end_on,
        opening_balance: opening_balance,
        closing_balance: closing_balance,
        currency: "AUD",
        transactions: transactions,
        balance_check_passed: false,
        balance_check_errors: [],
        warnings: [],
        metadata: {}
      )
    end

    private

      def build_from_buffer(buffer, year:, prev_date:)
        return nil if buffer.empty?

        joined = buffer.join(" ").squeeze(" ")
        match = joined.match(TXN_LINE_RE)
        return nil unless match

        date = parse_day_month(match[1], year: year, prev_date: prev_date)
        amount = AmountParser.parse_money(match[3])
        description = match[2].strip.presence || "Transaction"

        CommBankStatement::StatementLine.new(
          date: date,
          description: description,
          amount: amount,
          balance: nil,
          raw_lines: buffer
        )
      end

      def extract_summary_amount(pattern)
        line = @text.lines.find { |l| l.match?(pattern) }
        return nil unless line

        match = line.match(pattern)
        AmountParser.parse_money(match[1]) if match
      end

      def parse_day_month(token, year:, prev_date:)
        date = Date.strptime("#{token} #{year}", "%d %b %Y")
        if prev_date && date < prev_date
          date = Date.strptime("#{token} #{year + 1}", "%d %b %Y")
        end
        date
      rescue ArgumentError
        Date.strptime("#{token} #{year}", "%e %b %Y")
      end
  end
end
