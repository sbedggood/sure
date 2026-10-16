# frozen_string_literal: true

module CommBankStatement
  # Parses CommBank PDF tables with running balances (CR asset accounts, DR loans).
  class BalancedTableParser
    ROW_START_RE = /^\s*(\d{1,2}\s+[A-Za-z]{3}(?:\s+\d{4})?)\s+(.*)$/
    BALANCE_RE = /\$([\d,]+(?:[. ]\d{2}))\s*(CR|DR)\b/i
    OPENING_RE = /OPENING\s+BALANCE/i
    CLOSING_RE = /CLOSING\s+BALANCE/i
    HOME_OPENING_RE = /Opening balance/i
    HOME_CLOSING_RE = /Closing balance/i

    def initialize(text, statement_type:)
      @text = text
      @statement_type = statement_type
    end

    def parse
      period = PeriodParser.parse(@text)
      lines = TextNormalizer.transaction_table_lines(@text)
      blocks = group_row_blocks(lines)

      transactions = []
      opening_balance = nil
      closing_balance = nil
      running = nil
      year = period&.start_on&.year
      prev_date = nil

      blocks.each do |block|
        parsed = parse_block(block)
        next unless parsed

        date = resolve_date(parsed[:date_token], year: year, prev_date: prev_date, period: period)
        year = date.year
        prev_date = date

        balance = parsed[:balance]
        description = parsed[:description]

        if description.match?(OPENING_RE) || description.match?(HOME_OPENING_RE)
          opening_balance = balance
          running = balance
          next
        end

        if description.match?(CLOSING_RE) || description.match?(HOME_CLOSING_RE)
          closing_balance = balance
          next
        end

        next if balance.nil? || running.nil?

        amount = balance - running
        running = balance

        transactions << CommBankStatement::StatementLine.new(
          date: date,
          description: description,
          amount: amount,
          balance: balance,
          raw_lines: block
        )
      end

      closing_balance = running if closing_balance.nil?

      ParseResult.new(
        statement_type: @statement_type,
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

      def group_row_blocks(lines)
        blocks = []
        current = []

        lines.each do |line|
          stripped = line.strip
          next if stripped.empty?
          next if TextNormalizer.barcode_line?(line)

          if ROW_START_RE.match?(stripped)
            blocks << current if current.any?
            current = [ stripped ]
          elsif current.any?
            current << stripped unless TextNormalizer.barcode_line?(line)
          end
        end

        blocks << current if current.any?
        blocks
      end

      def parse_block(block)
        first = block.first.to_s.strip
        row_match = first.match(ROW_START_RE)
        return nil unless row_match

        block_text = block.join(" ").squeeze(" ")
        balance_matches = block_text.scan(BALANCE_RE)
        return nil if balance_matches.empty?

        amount_str, suffix = balance_matches.last
        balance = AmountParser.parse_balance("$#{amount_str} #{suffix}")

        date_token = row_match[1]
        description = strip_amount_columns(row_match[2].strip)

        {
          date_token: date_token,
          description: description.presence || "Transaction",
          balance: balance
        }
      end

      def strip_amount_columns(description)
        description
          .gsub(/\s+-?[\d,]+(?:[. ]\d{2})\s*[\$\(]\s*$/, "")
          .gsub(/\s+\$[\d,]+(?:[. ]\d{2})\s*$/, "")
          .gsub(/\s+[\d,]+(?:[. ]\d{2})\s*$/, "")
          .strip
      end

      def resolve_date(date_token, year:, prev_date:, period:)
        if date_token.match?(/\d{4}\z/)
          return Date.strptime(date_token, "%d %b %Y")
        end

        candidates = candidate_years(period, year, prev_date)
        candidates.each do |candidate_year|
          date = build_date(date_token, candidate_year)
          next unless date
          return date if period.nil? || date_in_period?(date, period)
        end

        build_date(date_token, candidates.first) || period&.end_on || Date.current
      end

      def candidate_years(period, year, prev_date)
        years = []
        if period&.start_on && period&.end_on
          years = (period.start_on.year..period.end_on.year).to_a
        elsif year
          years = [ year, year + 1 ]
        else
          years = [ Date.current.year ]
        end

        if prev_date && years.size == 1
          years << years.first + 1
        end
        years
      end

      def build_date(date_token, year)
        Date.strptime("#{date_token} #{year}", "%d %b %Y")
      rescue ArgumentError
        Date.strptime("#{date_token} #{year}", "%e %b %Y")
      rescue Date::Error
        nil
      end

      def date_in_period?(date, period)
        date.between?(period.start_on - 45, period.end_on + 45)
      end
  end
end
