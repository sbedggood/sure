# frozen_string_literal: true

module Tax
  class PropertyCellPayeeProfile
    Fingerprint = Data.define(:merchant, :phrase)

    GENERIC_TOKENS = %w[
      card purchase debit credit eftpos pos payment visa mastercard amex
      withdraw transfer fee bpay ptyltd pty ltd melbourne vic nsw qld
      australia aud sa aust the and for from your
    ].freeze

    NOISE_NAME_PATTERN = /super|bpay|paystay|parking|spaceship|woolworths|chemist|grouse|almakan|linkt/i
    UTILITY_NAME_PATTERN = /energy|electricity|\bgas\b|supa/i

    attr_reader :fingerprints

    def self.from_entries(entries)
      fingerprints = entries.filter_map { |entry| fingerprint_from(entry) }.uniq
      new(fingerprints: fingerprints)
    end

    def self.fingerprint_from(entry)
      merchant = normalize_text(entry.transaction.merchant&.name)
      tokens = distinctive_tokens(normalize_text(entry.name))
      phrase = tokens.first(3).join(" ")
      phrase = nil if phrase.present? && phrase.length < 8

      return nil if merchant.blank? && phrase.blank?

      Fingerprint.new(merchant: merchant.presence, phrase: phrase.presence)
    end

    def self.normalize_text(value)
      value.to_s.downcase.squish
    end

    def self.tokenize(text)
      normalize_text(text).split(/\s+/).reject do |token|
        token.length < 4 || GENERIC_TOKENS.include?(token)
      end
    end

    def self.distinctive_tokens(text)
      tokenize(text)
    end

    def initialize(fingerprints:)
      @fingerprints = fingerprints
    end

    def empty?
      fingerprints.empty?
    end

    def matches_entry?(entry)
      return false if fingerprints.empty?
      return false if noise_candidate?(entry)

      fingerprints.any? { |fingerprint| matches_fingerprint?(entry, fingerprint) }
    end

    def history_score_for(entry)
      return 0 unless matches_entry?(entry)

      score = 0
      candidate_merchant = normalize_text(entry.transaction.merchant&.name)
      candidate_name = normalize_text(entry.name)

      fingerprints.each do |fingerprint|
        if fingerprint.merchant.present? && candidate_merchant == fingerprint.merchant
          score = [ score, 120 ].max
        elsif fingerprint.merchant.present? && candidate_name.include?(fingerprint.merchant)
          score = [ score, 100 ].max
        elsif fingerprint.phrase.present? && candidate_name.include?(fingerprint.phrase)
          score = [ score, 90 ].max
        elsif fingerprint.phrase.present? && candidate_merchant.present? && candidate_merchant.include?(fingerprint.phrase)
          score = [ score, 85 ].max
        end
      end

      score
    end

    private

      def matches_fingerprint?(entry, fingerprint)
        candidate_merchant = normalize_text(entry.transaction.merchant&.name)
        candidate_name = normalize_text(entry.name)

        if fingerprint.merchant.present?
          return true if candidate_merchant == fingerprint.merchant
          return true if compatible_merchant_match?(candidate_merchant, fingerprint.merchant, candidate_name)
          return true if candidate_name.include?(fingerprint.merchant) && compatible_name?(candidate_name, fingerprint.merchant)
        end

        if fingerprint.phrase.present?
          return true if candidate_name.include?(fingerprint.phrase)
          return true if candidate_merchant.present? && candidate_merchant.include?(fingerprint.phrase)
        end

        false
      end

      def compatible_merchant_match?(candidate_merchant, reference_merchant, candidate_name)
        return false if candidate_merchant.blank?

        return true if candidate_merchant == reference_merchant
        return false unless candidate_merchant.include?(reference_merchant) || reference_merchant.include?(candidate_merchant)

        compatible_name?(candidate_name, reference_merchant)
      end

      def compatible_name?(candidate_name, reference_merchant)
        return false if candidate_name.match?(NOISE_NAME_PATTERN)
        return false if reference_merchant.include?("telstra") && candidate_name.match?(/super|bpay/)
        return false if reference_merchant.include?("telecom") && candidate_name.match?(UTILITY_NAME_PATTERN)

        true
      end

      def noise_candidate?(entry)
        name = normalize_text(entry.name)
        return true if name.match?(NOISE_NAME_PATTERN)
        return true if utility_noise?(name)

        false
      end

      def utility_noise?(name)
        return false unless name.match?(UTILITY_NAME_PATTERN)

        fingerprints.none? do |fingerprint|
          fingerprint.phrase&.match?(UTILITY_NAME_PATTERN) ||
            fingerprint.merchant&.match?(UTILITY_NAME_PATTERN)
        end
      end

      def normalize_text(value)
        self.class.normalize_text(value)
      end
  end
end
