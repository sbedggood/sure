# frozen_string_literal: true

module Tax
  class FinancialYear
    attr_reader :start_year

    def self.current_start_year(on: Date.current)
      on.month >= 7 ? on.year : on.year - 1
    end

    def self.label_for(start_year)
      short = (start_year % 100)
      "FY#{short.to_s.rjust(2, "0")}"
    end

    def initialize(start_year)
      @start_year = start_year.to_i
    end

    def label
      self.class.label_for(start_year)
    end

    def start_on
      Date.new(start_year, 7, 1)
    end

    def end_on
      Date.new(start_year + 1, 6, 30)
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
