# frozen_string_literal: true

module Tax
  class SettingsController < ApplicationController
    def update
      start_year = params.require(:start_year).to_i
      settings = TaxFySetting.find_or_initialize_for!(family: Current.family, start_year: start_year)

      settings.update!(settings_params)
      redirect_to tax_dashboard_path(start_year: start_year, section: params[:return_section].presence || "property"),
        notice: t("tax.settings.saved")
    end

    private

      def settings_params
        permitted = params.require(:tax_fy_setting).permit(
          :property_allocation_percent,
          :marginal_tax_rate_percent,
          :wfh_hourly_rate,
          :car_rate_per_km,
          deduction_business_use_percent: {}
        )
        if permitted[:deduction_business_use_percent].present?
          permitted[:deduction_business_use_percent] = permitted[:deduction_business_use_percent].to_unsafe_h
        end
        permitted
      end
  end
end
