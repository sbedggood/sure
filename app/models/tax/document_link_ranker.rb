# frozen_string_literal: true

module Tax
  class DocumentLinkRanker
    SALARY_PATTERN = /salary|payroll|wage|pay\s+run|employer/i

    def initialize(document:)
      @document = document
      @anchor_date = document.document_date || document.created_at.to_date
    end

    def rank(entries)
      entries.sort_by { |entry| [ -score(entry), entry.date, entry.name ] }
    end

    private

      def score(entry)
        if payslip_document?
          payslip_score(entry)
        else
          date_proximity_score(entry.date)
        end
      end

      def payslip_document?
        @document.document_type == "payslip"
      end

      def payslip_score(entry)
        score = date_proximity_score(entry.date)
        score += 10_000 if entry.amount.negative?
        score += 5_000 if salary_like?(entry)
        score
      end

      def salary_like?(entry)
        text = [ entry.name, entry.entryable&.merchant&.name ].compact.join(" ")
        text.match?(SALARY_PATTERN)
      end

      def date_proximity_score(date)
        return 0 unless date && @anchor_date

        days = (@anchor_date - date).to_i.abs
        1_000 - days.clamp(0, 999)
      end
  end
end
