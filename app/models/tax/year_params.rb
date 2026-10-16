# frozen_string_literal: true

module Tax
  module YearParams
    module_function

    def resolve_from_tool_params(params)
      Tax::FinancialYear.resolve_start_year(
        start_year: params["start_year"],
        fy: params["fy"]
      )
    end
  end
end
