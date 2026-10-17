# frozen_string_literal: true

module Tax
  class PropertyCellSearchRanker
    LOW_PRIORITY_NAME_PATTERN = /super|parking|paystay|spaceship|woolworths|chemist/i

    def initialize(payee_profile:, query:)
      @payee_profile = payee_profile
      @query = normalize(query)
    end

    def rank(entries)
      entries.sort_by { |entry| [ -score(entry), -entry.date.to_time.to_i ] }
    end

    def score(entry)
      points = @payee_profile.history_score_for(entry)
      points += text_match_score(entry)
      points += outflow_score(entry)
      points += bill_size_score(entry)
      points -= 40 if low_priority_name?(entry.name)
      points
    end

    private

      def text_match_score(entry)
        return 0 if @query.blank?

        merchant = normalize(entry.transaction.merchant&.name)
        name = normalize(entry.name)
        notes = normalize(entry.notes)

        score = 0
        score += 60 if merchant.present? && merchant.include?(@query)
        score += 40 if name.start_with?(@query)
        score += 25 if name.include?(@query)
        score += 15 if notes.include?(@query)
        score
      end

      def outflow_score(entry)
        entry.amount.positive? ? 10 : 0
      end

      def bill_size_score(entry)
        amount = entry.amount.abs
        return 0 if amount < 15 || amount > 500

        5
      end

      def low_priority_name?(name)
        name.to_s.match?(LOW_PRIORITY_NAME_PATTERN)
      end

      def normalize(value)
        value.to_s.downcase.squish
      end
  end
end
