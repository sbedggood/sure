# frozen_string_literal: true

module Tax
  module DeductionsTurboRefresh
    extend ActiveSupport::Concern

    private

      def tax_deductions_refresh_stream(start_year)
        return if start_year.blank?

        financial_year = Tax::FinancialYear.new(start_year.to_i)
        settings = TaxFySetting.find_or_initialize_for!(family: Current.family, start_year: financial_year.start_year)
        sort, direction = Tax::SortParams.parse(
          sort: params[:sort],
          direction: params[:direction],
          allowed: EntrySorter::COLUMNS
        )
        deductions = Tax::DeductionsPresenter.new(
          family: Current.family,
          start_year: financial_year.start_year,
          sort: sort,
          direction: direction
        )

        turbo_stream.replace(
          "tax-deductions",
          partial: "tax/dashboard/deductions",
          locals: {
            financial_year: financial_year,
            settings: settings,
            deductions: deductions,
            sort: sort,
            direction: direction
          }
        )
      end

      def append_tax_deductions_refresh(streams, start_year)
        stream = tax_deductions_refresh_stream(start_year)
        streams << stream if stream
        streams
      end
  end
end
