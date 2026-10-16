# frozen_string_literal: true

module Tax
  class WeeklyCalendarEntriesController < ApplicationController
    def bulk_update
      start_year = params.require(:start_year).to_i
      fy = Tax::FinancialYear.new(start_year)

      rows = params.require(:entries)
      TaxWeeklyCalendarEntry.transaction do
        rows.each do |row|
          week = Date.parse(row[:week_commencing])
          next unless fy.range.cover?(week)

          entry = Current.family.tax_weekly_calendar_entries.find_or_initialize_by(
            start_year: start_year,
            week_commencing: week
          )
          entry.assign_attributes(
            wfh_hours: row[:wfh_hours].presence || 0,
            km_driven: row[:km_driven].presence || 0,
            note: row[:note]
          )
          entry.save!
        end
      end

      redirect_to tax_dashboard_path(start_year: start_year, section: "calendar"),
        notice: t("tax.calendar.saved")
    end
  end
end
