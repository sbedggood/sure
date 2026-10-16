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
        normalized = TextNormalizer.normalize(text)
        classification = DocumentClassifier.classify(normalized, filename: filename)

        if classification.is_a?(DocumentClassifier::Skipped)
          raise SkippedDocument, classification.reason
        end

        result = case classification
        when :credit_card
          CreditCardParser.new(normalized).parse
        when :home_loan
          BalancedTableParser.new(normalized, statement_type: :home_loan).parse
        else
          BalancedTableParser.new(normalized, statement_type: :transaction_account).parse
        end

        result = apply_period_from_header(normalized, result)
        validate_balances(result)
      end

      def detect_type(text, filename = nil)
        classification = DocumentClassifier.classify(TextNormalizer.normalize(text), filename: filename)
        return :skipped if classification.is_a?(DocumentClassifier::Skipped)

        classification
      end

      private

        def apply_period_from_header(text, result)
          period = PeriodParser.parse(text)
          return result unless period

          result.with(
            period_start_on: result.period_start_on || period.start_on,
            period_end_on: result.period_end_on || period.end_on
          )
        end

        def validate_balances(result)
          errors = []
          txs = result.transactions

          if result.statement_type.in?([ :transaction_account, :home_loan ]) &&
              (result.opening_balance.nil? || result.closing_balance.nil?)
            errors << "Missing opening or closing balance"
          end

          if txs.empty? && !errors.include?("Missing opening or closing balance")
            errors << "No transactions parsed"
          end

          if result.statement_type.in?([ :transaction_account, :home_loan ]) && txs.any? &&
              result.opening_balance.present?
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
