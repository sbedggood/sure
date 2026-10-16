# frozen_string_literal: true

class Api::V1::Tax::SettingsController < Api::V1::BaseController
  before_action -> { authorize_scope!(:read) }, only: :show
  before_action -> { authorize_scope!(:read_write) }, only: :update

  def show
    settings = TaxFySetting.find_or_initialize_for!(family: family, start_year: params[:start_year])
    settings.save! if settings.new_record?
    render json: settings_json(settings)
  end

  def update
    settings = TaxFySetting.find_or_initialize_for!(family: family, start_year: params[:start_year])
    settings.update!(settings_params)
    render json: settings_json(settings)
  end

  private

    def family
      current_resource_owner.family
    end

    def settings_params
      params.permit(
        :property_allocation_percent,
        :marginal_tax_rate_percent,
        :wfh_hourly_rate,
        :car_rate_per_km,
        deduction_business_use_percent: {}
      )
    end

    def settings_json(settings)
      {
        start_year: settings.start_year,
        property_allocation_percent: settings.property_allocation_percent.to_f,
        marginal_tax_rate_percent: settings.marginal_tax_rate_percent.to_f,
        wfh_hourly_rate: settings.wfh_hourly_rate.to_f,
        car_rate_per_km: settings.car_rate_per_km.to_f,
        deduction_business_use_percent: settings.deduction_business_use_percent
      }
    end
end
