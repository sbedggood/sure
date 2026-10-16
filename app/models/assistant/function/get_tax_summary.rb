# frozen_string_literal: true

class Assistant::Function::GetTaxSummary < Assistant::Function
  class << self
    def name
      "get_tax_summary"
    end

    def description
      "Returns Australian tax FY summary JSON (property grid, deductions, calendar totals) for the user's family."
    end
  end

  def params_schema
    build_schema(
      required: [ "start_year" ],
      properties: {
        start_year: {
          type: "integer",
          description: "Financial year start (e.g. 2024 for FY24 beginning 1 Jul 2024)."
        }
      }
    )
  end

  def call(params = {})
    start_year = params["start_year"].to_i
    summary = Tax::Summary.new(family: user.family, start_year: start_year)
    { success: true, summary: summary.as_json }
  end
end
