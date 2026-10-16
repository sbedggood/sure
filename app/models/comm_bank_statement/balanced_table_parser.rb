# frozen_string_literal: true

module CommBankStatement
  # Parses CommBank PDF tables with running balances (CR asset accounts, DR loans).
  class BalancedTableParser
    ROW_START_RE = /^\s*(\d{1,2}\s+[A-Za-z]{3}(?:\s+\d{4})?)\s+(.*)$/
    BALANCE_TAIL_RE = /\$([\d,]+\.\d{2})\s*(CR|DR)\s*$/i
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

          if ROW_START_RE.match?(stripped)
            blocks << current if current.any?
            current = [ stripped ]
          elsif current.any?
            current << stripped
          end
        end

        blocks << current if current.any?
        blocks
      end

      def parse_block(block)
        block_text = block.join(" ").squeeze(" ")
        balance_match = block_text.match(BALANCE_TAIL_RE)
        return nil unless balance_match

        balance = AmountParser.parse_balance("$#{balance_match[1]} #{balance_match[2]}")
        remainder = block_text.sub(BALANCE_TAIL_RE, "").strip

        row_match = remainder.match(ROW_START_RE)
        return nil unless row_match

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
          .gsub(/\s+-?[\d,]+\.\d{2}\s*[\$\(]\s*$/, "")
          .gsub(/\s+\$[\d,]+\.\d{2}\s*$/, "")
          .gsub(/\s+[\d,]+\.\d{2}\s*$/, "")
          .strip
      end

      def resolve_date(date_token, year:, prev_date:, period:)
        if date_token.match?(/\d{4}\z/)
          Date.strptime(date_token, "%d %b %Y")
        else
          raise ArgumentError, "missing year" unless year

          date = Date.strptime("#{date_token} #{year}", "%d %b %Y")
          if prev_date && date < prev_date && period&.end_on && date.month <= 2
            date = Date.strptime("#{date_token} #{year + 1}", "%d %b %Y")
          end
          date
        end
      rescue ArgumentError
        Date.strptime("#{date_token} #{year}", "%e %b %Y")
      end
  end
end
