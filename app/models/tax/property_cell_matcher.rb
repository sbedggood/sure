# frozen_string_literal: true

module Tax
  class PropertyCellMatcher
    Candidate = Data.define(:entry, :signals, :score)

    def initialize(linked_entries:, month:, reference_entries: nil, payee_profile: nil)
      @month = month
      entries = (reference_entries || linked_entries).uniq
      @payee_profile = payee_profile || PropertyCellPayeeProfile.from_entries(entries)
    end

    def rank(candidates)
      candidates.map do |entry|
        signals = build_signals(entry)
        score = score_for(signals)
        Candidate.new(entry: entry, signals: signals, score: score)
      end.sort_by { |c| [ -c.score, c.entry.date ] }
    end

    def suggestion_candidates(candidates)
      return [] if @payee_profile.empty?

      rank(candidates).select { |candidate| @payee_profile.matches_entry?(candidate.entry) }
    end

    private

      def build_signals(entry)
        {
          payee: @payee_profile.matches_entry?(entry),
          history: @payee_profile.history_score_for(entry),
          date: entry.date.between?(@month.beginning_of_month, @month.end_of_month)
        }
      end

      def score_for(signals)
        score = signals[:history]
        score += 1 if signals[:date]
        score
      end
  end
end
