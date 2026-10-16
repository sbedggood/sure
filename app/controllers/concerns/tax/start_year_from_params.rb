# frozen_string_literal: true

module Tax
  module StartYearFromParams
    extend ActiveSupport::Concern

    private

      def tax_start_year_from_params
        Tax::FinancialYear.resolve_start_year(
          start_year: params[:start_year],
          fy: params[:fy]
        ) || Tax::FinancialYear.current_start_year
      end
  end
end
