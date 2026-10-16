# frozen_string_literal: true

class TaxFySetting < ApplicationRecord
  belongs_to :family

  validates :start_year, presence: true, numericality: { only_integer: true }
  validates :property_allocation_percent, :marginal_tax_rate_percent,
    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :wfh_hourly_rate, :car_rate_per_km, numericality: { greater_than_or_equal_to: 0 }
  validates :start_year, uniqueness: { scope: :family_id }

  def self.find_or_initialize_for!(family:, start_year:)
    fy = Tax::FinancialYear.new(start_year)
    record = family.tax_fy_settings.find_or_initialize_by(start_year: start_year)
    if record.new_record?
      record.wfh_hourly_rate = fy.default_wfh_hourly_rate
      record.car_rate_per_km = BigDecimal("0.85")
    end
    record
  end

  def business_use_percent_for(tag_name)
    key = tag_name.to_s
    stored = deduction_business_use_percent[key]
    return BigDecimal(stored.to_s) if stored.present?

    BigDecimal("100")
  end
end
