# frozen_string_literal: true

class Assistant::Function::UpsertTaxCalendar < Assistant::Function
  class << self
    def name
      "upsert_tax_calendar"
    end

    def description
      "Bulk upsert weekly tax calendar rows (WFH hours, km driven, note) for an Australian financial year."
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: %w[start_year entries],
      properties: {
        start_year: { type: "integer" },
        entries: {
          type: "array",
          items: {
            type: "object",
            required: %w[week_commencing],
            properties: {
              week_commencing: { type: "string", description: "ISO date (Monday)" },
              wfh_hours: { type: "number" },
              km_driven: { type: "number" },
              note: { type: "string" }
            }
          }
        }
      }
    )
  end

  def call(params = {})
    start_year = params["start_year"].to_i
    fy = Tax::FinancialYear.new(start_year)
    family = user.family
    rows = Array(params["entries"])

    TaxWeeklyCalendarEntry.transaction do
      rows.each do |row|
        week = Date.parse(row["week_commencing"])
        next unless fy.range.cover?(week)

        entry = family.tax_weekly_calendar_entries.find_or_initialize_by(
          start_year: start_year,
          week_commencing: week
        )
        entry.assign_attributes(
          wfh_hours: row["wfh_hours"] || 0,
          km_driven: row["km_driven"] || 0,
          note: row["note"]
        )
        entry.save!
      end
    end

    entries = family.tax_weekly_calendar_entries.for_year(start_year)
    { success: true, count: entries.count }
  end
end
