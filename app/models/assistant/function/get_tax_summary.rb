# frozen_string_literal: true

class Assistant::Function::GetTaxSummary < Assistant::Function
  class << self
    def name
      "get_tax_summary"
    end

    def description
      <<~DESC.squish
        Returns Australian tax financial year summary JSON (property grid, deductions, calendar totals).
        ATO labels years by end year: Jul 2024–Jun 2025 is FY25. Pass start_year (Jul year, e.g. 2024)
        or fy (end year, e.g. 25 or 2025).
      DESC
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      properties: {
        start_year: {
          type: "integer",
          description: "July-start year stored in the database (e.g. 2024 for FY25)."
        },
        fy: {
          type: [ "integer", "string" ],
          description: "ATO financial year end (e.g. 25, 2025, or FY25). Alternative to start_year."
        }
      }
    )
  end

  def call(params = {})
    start_year = Tax::YearParams.resolve_from_tool_params(params)
    return error("invalid_year", "Provide start_year or fy.") unless start_year

    summary = Tax::Summary.new(family: user.family, start_year: start_year)
    { success: true, summary: summary.as_json }
  end
end
