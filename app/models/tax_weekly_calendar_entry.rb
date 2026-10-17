# frozen_string_literal: true

class TaxWeeklyCalendarEntry < ApplicationRecord
  belongs_to :family

  validates :start_year, presence: true, numericality: { only_integer: true }
  validates :week_commencing, presence: true
  validates :wfh_hours, :km_driven, numericality: { greater_than_or_equal_to: 0 }
  validates :week_commencing, uniqueness: { scope: [ :family_id, :start_year ] }

  scope :for_year, ->(start_year) { where(start_year: start_year).order(:week_commencing) }
end
