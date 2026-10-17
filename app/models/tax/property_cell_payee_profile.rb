# frozen_string_literal: true

module Tax
  class PropertyCellPayeeProfile
    GENERIC_TOKENS = %w[
      card purchase debit credit eftpos pos payment visa mastercard amex
      withdraw transfer fee bpay ptyltd pty ltd melbourne vic nsw qld
      australia aud sa aust the and for from your
    ].freeze

    DISQUALIFYING_TOKENS = %w[
      super parking paystay spaceship woolworths chemist grouse almakan linkt
    ].freeze

    attr_reader :merchants, :name_tokens

    def self.from_entries(entries)
      merchants = []
      name_tokens = Set.new

      entries.each do |entry|
        merchant = normalize_text(entry.transaction.merchant&.name)
        merchants << merchant if merchant.present?

        tokenize(entry.name).each { |token| name_tokens << token }
        tokenize(merchant).each { |token| name_tokens << token }
      end

      new(
        merchants: merchants.uniq,
        name_tokens: name_tokens
      )
    end

    def self.normalize_text(value)
      value.to_s.downcase.squish
    end

    def self.tokenize(text)
      normalize_text(text).split(/\s+/).reject do |token|
        token.length < 4 || GENERIC_TOKENS.include?(token)
      end
    end

    def initialize(merchants:, name_tokens:)
      @merchants = merchants
      @name_tokens = name_tokens
    end

    def empty?
      merchants.empty? && name_tokens.empty?
    end

    def matches_entry?(entry)
      candidate_merchant = normalize_text(entry.transaction.merchant&.name)
      candidate_name = normalize_text(entry.name)

      return true if merchant_matches?(candidate_merchant)
      return true if merchant_matches?(candidate_name)
      return true if distinctive_name_match?(candidate_name)

      false
    end

    def history_score_for(entry)
      score = 0
      candidate_merchant = normalize_text(entry.transaction.merchant&.name)
      candidate_name = normalize_text(entry.name)

      score += 100 if merchants.include?(candidate_merchant)
      score += 80 if merchants.any? { |ref| payee_substring_match?(candidate_merchant, ref) }
      score += 70 if merchants.any? { |ref| payee_substring_match?(candidate_name, ref) }
      score += 50 if distinctive_name_match?(candidate_name)
      score
    end

    private

      def merchant_matches?(value)
        return false if value.blank?

        merchants.any? { |reference| payee_substring_match?(value, reference) }
      end

      def distinctive_name_match?(candidate_name)
        return false if candidate_name.blank?

        candidate_tokens = distinctive_tokens(candidate_name)
        return false if candidate_tokens.empty?

        overlap = candidate_tokens & name_tokens.to_a
        leftover = candidate_tokens - overlap
        return false if overlap.size < 2 && leftover.any? { |token| DISQUALIFYING_TOKENS.include?(token) }

        overlap.size >= 2 || overlap.any? { |token| token.length >= 8 }
      end

      def payee_substring_match?(left, right)
        return false if left.blank? || right.blank?

        return true if left == right

        longer, shorter = [ left, right ].sort_by(&:length).reverse
        return false if shorter.length < 5

        longer.include?(shorter)
      end

      def distinctive_tokens(text)
        self.class.tokenize(text)
      end

      def normalize_text(value)
        self.class.normalize_text(value)
      end
  end
end
