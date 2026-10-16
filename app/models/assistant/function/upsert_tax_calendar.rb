# frozen_string_literal: true

class Assistant::Function::UpsertTaxCalendar < Assistant::Function
  class << self
    def name
      "upsert_tax_calendar"
    end

    def description
      <<~DESC.squish
        Bulk upsert weekly tax calendar rows (WFH hours, km driven, note) for an Australian financial year.
        Use start_year (July year) or fy (ATO end year, e.g. 25 for FY25).
      DESC
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: %w[entries],
      properties: {
        start_year: { type: "integer", description: "July-start year (e.g. 2024 for FY25)." },
        fy: { type: [ "integer", "string" ], description: "ATO end year (e.g. 25 or 2025)." },
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
    start_year = Tax::YearParams.resolve_from_tool_params(params)
    return error("invalid_year", "Provide start_year or fy.") unless start_year

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
    { success: true, label: fy.label, start_year: start_year, count: entries.count }
  end
end
