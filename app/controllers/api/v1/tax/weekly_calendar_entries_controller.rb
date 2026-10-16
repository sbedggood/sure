# frozen_string_literal: true

class Api::V1::Tax::WeeklyCalendarEntriesController < Api::V1::Tax::BaseController
  before_action -> { authorize_scope!(:read) }, only: :index
  before_action -> { authorize_scope!(:read_write) }, only: :bulk_update

  def index
    entries = family.tax_weekly_calendar_entries.for_year(tax_start_year)
    render json: entries.map { |e| entry_json(e) }
  end

  def bulk_update
    start_year = tax_start_year
    fy = Tax::FinancialYear.new(start_year)
    rows = params.require(:entries)

    TaxWeeklyCalendarEntry.transaction do
      rows.each do |row|
        week = Date.parse(row[:week_commencing] || row["week_commencing"])
        next unless fy.range.cover?(week)

        entry = family.tax_weekly_calendar_entries.find_or_initialize_by(
          start_year: start_year,
          week_commencing: week
        )
        entry.assign_attributes(
          wfh_hours: row[:wfh_hours] || row["wfh_hours"] || 0,
          km_driven: row[:km_driven] || row["km_driven"] || 0,
          note: row[:note] || row["note"]
        )
        entry.save!
      end
    end

    render json: { success: true, entries: family.tax_weekly_calendar_entries.for_year(start_year).map { |e| entry_json(e) } }
  end

  private

    def family
      current_resource_owner.family
    end

    def entry_json(entry)
      {
        id: entry.id,
        start_year: entry.start_year,
        week_commencing: entry.week_commencing.iso8601,
        wfh_hours: entry.wfh_hours.to_f,
        km_driven: entry.km_driven.to_f,
        note: entry.note,
        updated_at: entry.updated_at.iso8601
      }
    end
end
