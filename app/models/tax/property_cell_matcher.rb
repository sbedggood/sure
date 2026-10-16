# frozen_string_literal: true

module Tax
  class PropertyCellMatcher
    Candidate = Data.define(:entry, :signals, :score)

    def initialize(linked_entries:, month:)
      @linked_entries = linked_entries
      @month = month
      @reference_names = linked_entries.map { |e| e.name.to_s.downcase }
      @reference_amounts = linked_entries.map { |e| e.amount.abs }
      @reference_merchants = linked_entries.filter_map { |e| e.entryable.is_a?(Transaction) ? e.transaction.merchant&.name&.downcase : nil }
    end

    def rank(candidates)
      candidates.map do |entry|
        signals = build_signals(entry)
        score = signals.values.count(true) + (signals[:merchant] ? 1 : 0)
        Candidate.new(entry: entry, signals: signals, score: score)
      end.sort_by { |c| [ -c.score, c.entry.date ] }
    end

    private

      def build_signals(entry)
        name = entry.name.to_s.downcase
        amount = entry.amount.abs
        merchant = entry.transaction.merchant&.name&.downcase

        {
          merchant: merchant.present? && @reference_merchants.include?(merchant),
          name: @reference_names.any? { |ref| ref.present? && (name.include?(ref) || ref.include?(name)) },
          amount: @reference_amounts.any? { |ref| ref == amount },
          date: entry.date.between?(@month.beginning_of_month, @month.end_of_month)
        }
      end
  end
end
