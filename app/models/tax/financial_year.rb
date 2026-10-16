# frozen_string_literal: true

module Tax
  class FinancialYear
    attr_reader :start_year

    def self.current_start_year(on: Date.current)
      on.month >= 7 ? on.year : on.year - 1
    end

    # ATO labels a financial year by its ending year (Jul 2024–Jun 2025 → FY25).
    def self.end_year_for_start_year(start_year)
      start_year.to_i + 1
    end

    def self.label_for(start_year)
      short = end_year_for_start_year(start_year) % 100
      "FY#{short.to_s.rjust(2, "0")}"
    end

    # Accept Jul-year `start_year`, or ATO end-year via `fy` (25, 2025, FY25).
    def self.resolve_start_year(start_year: nil, fy: nil)
      return parse_fy_to_start_year(fy) if fy.present?

      return nil if start_year.blank?

      sy = start_year.to_i
      return parse_fy_to_start_year(sy) if sy.positive? && sy < 100

      sy.positive? ? sy : nil
    end

    def self.parse_fy_to_start_year(value)
      end_year = parse_fy_end_year(value)
      return nil unless end_year

      end_year - 1
    end

    def self.parse_fy_end_year(value)
      raw = value.to_s.strip.upcase.delete_prefix("FY")
      return nil if raw.blank?

      n = raw.to_i
      return nil unless n.positive?

      n < 100 ? 2000 + n : n
    end

    def initialize(start_year)
      @start_year = start_year.to_i
    end

    def end_year
      self.class.end_year_for_start_year(start_year)
    end

    def label
      self.class.label_for(start_year)
    end

    def start_on
      Date.new(start_year, 7, 1)
    end

    def end_on
      Date.new(end_year, 6, 30)
    end

    def range
      start_on..end_on
    end

    def months
      (0..11).map { |i| (start_on + i.months).beginning_of_month.to_date }
    end

    def week_commencing_dates
      dates = []
      cursor = start_on.beginning_of_week(:monday)
      while cursor <= end_on
        dates << cursor
        cursor += 7
      end
      dates
    end

    def default_wfh_hourly_rate
      start_year >= 2024 ? BigDecimal("0.70") : BigDecimal("0.67")
    end
  end
end
