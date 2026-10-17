# frozen_string_literal: true

module Tax
  class PropertyCellMatcher
    MIN_SUGGESTION_SCORE = 2

    Candidate = Data.define(:entry, :signals, :score)

    def initialize(linked_entries:, month:, reference_entries: nil)
      @month = month
      entries = (reference_entries || linked_entries).uniq
      @reference_names = entries.map { |e| normalize_text(e.name) }.reject(&:blank?)
      @reference_amounts = entries.map { |e| e.amount.abs }
      @reference_merchants = entries.filter_map do |e|
        next unless e.entryable.is_a?(Transaction)

        normalize_text(e.transaction.merchant&.name)
      end.reject(&:blank?).uniq
    end

    def rank(candidates)
      candidates.map do |entry|
        signals = build_signals(entry)
        score = score_for(signals)
        Candidate.new(entry: entry, signals: signals, score: score)
      end.sort_by { |c| [ -c.score, c.entry.date ] }
    end

    def suggestion_candidates(candidates)
      rank(candidates).select { |candidate| qualifies_for_suggestion?(candidate) }
    end

    def qualifies_for_suggestion?(candidate)
      return false if candidate.score < MIN_SUGGESTION_SCORE

      signals = candidate.signals
      signals[:merchant] || signals[:merchant_partial] || signals[:name]
    end

    private

      def build_signals(entry)
        name = normalize_text(entry.name)
        amount = entry.amount.abs
        merchant = normalize_text(entry.transaction.merchant&.name)

        {
          merchant: merchant.present? && @reference_merchants.include?(merchant),
          merchant_partial: merchant_partial_match?(merchant),
          name: name_match?(name),
          amount: @reference_amounts.any? { |ref| ref == amount },
          amount_similar: amount_similar?(amount),
          date: entry.date.between?(@month.beginning_of_month, @month.end_of_month)
        }
      end

      def score_for(signals)
        score = 0
        score += 4 if signals[:merchant]
        score += 3 if signals[:merchant_partial]
        score += 3 if signals[:name]
        score += 2 if signals[:amount]
        score += 1 if signals[:amount_similar]
        score += 1 if signals[:date]
        score
      end

      def merchant_partial_match?(merchant)
        return false if merchant.blank? || @reference_merchants.empty?

        @reference_merchants.any? do |reference|
          merchant.include?(reference) || reference.include?(merchant) || significant_token_overlap?(merchant, reference)
        end
      end

      def name_match?(name)
        return false if name.blank? || @reference_names.empty?

        @reference_names.any? do |reference|
          name.include?(reference) || reference.include?(name) || significant_token_overlap?(name, reference)
        end
      end

      def amount_similar?(amount)
        @reference_amounts.any? do |reference|
          next false if reference.zero?

          tolerance = [ reference * BigDecimal("0.05"), BigDecimal("1") ].max
          (amount - reference).abs <= tolerance
        end
      end

      def significant_token_overlap?(left, right)
        left_tokens = significant_tokens(left)
        right_tokens = significant_tokens(right)
        left_tokens.intersect?(right_tokens)
      end

      def significant_tokens(text)
        normalize_text(text).split(/\s+/).reject { |token| token.length < 4 }
      end

      def normalize_text(value)
        value.to_s.downcase.squish
      end
  end
end
