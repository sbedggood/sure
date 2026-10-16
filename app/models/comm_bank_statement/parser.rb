# frozen_string_literal: true

module CommBankStatement
  class Parser
    ParseError = Class.new(StandardError)

    class << self
      def parse_file(path)
        text = PdfText.extract(path)
        parse_text(text, filename: File.basename(path))
      end

      def parse_text(text, filename: nil)
        type = detect_type(text, filename)
        result = case type
        when :credit_card
          CreditCardParser.new(text).parse
        when :home_loan
          TransactionAccountParser.new(text).parse
            .with(metadata: { home_loan: true })
        else
          TransactionAccountParser.new(text).parse
        end

        result = apply_period_from_header(text, result)
        validate_balances(result)
      end

      def detect_type(text, filename = nil)
        normalized = text.to_s
        name = filename.to_s.downcase

        return :credit_card if normalized.include?("Amount(A$)") ||
          normalized.match?(/credit\s+card/i) ||
          name.include?("credit") || name.include?("card")

        return :home_loan if normalized.match?(/home\s+loan/i) || name.include?("loan") || name.include?("mortgage")

        :transaction_account
      end

      private

        def apply_period_from_header(text, result)
          if (match = text.match(/(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})\s*(?:to|–|-)\s*(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})/i))
            begin
              return result.with(
                period_start_on: Date.strptime(match[1], "%d %b %Y"),
                period_end_on: Date.strptime(match[2], "%d %b %Y")
              )
            rescue ArgumentError
              return result
            end
          end
          result
        end

        def validate_balances(result)
          errors = []
          txs = result.transactions

          if result.statement_type == :transaction_account &&
              (result.opening_balance.nil? || result.closing_balance.nil?)
            errors << "Missing opening or closing balance"
          end

          if txs.empty?
            errors << "No transactions parsed"
          end

          if result.statement_type == :transaction_account && txs.any?
            running = result.opening_balance
            txs.each_with_index do |txn, index|
              expected = running + txn.amount
              if txn.balance.present? && (expected - txn.balance).abs > BigDecimal("0.02")
                errors << "Row #{index + 1} balance mismatch: expected #{expected}, got #{txn.balance}"
              end
              running = txn.balance
            end

            if result.closing_balance.present? && running.present? &&
                 (running - result.closing_balance).abs > BigDecimal("0.02")
              errors << "Closing balance mismatch: running #{running}, stated #{result.closing_balance}"
            end
          elsif result.statement_type == :credit_card &&
                result.opening_balance.present? && result.closing_balance.present?
            total_movement = txs.sum(&:amount)
            expected_close = result.opening_balance + total_movement
            if (expected_close - result.closing_balance).abs > BigDecimal("0.02")
              errors << "Summary mismatch: opening #{result.opening_balance} + movements #{total_movement} != closing #{result.closing_balance}"
            end
          end

          result.with(
            balance_check_passed: errors.empty?,
            balance_check_errors: errors
          )
        end
    end
  end
end
