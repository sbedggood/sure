# frozen_string_literal: true

class TaxDocument < ApplicationRecord
  belongs_to :family

  has_one_attached :file

  DOCUMENT_TYPES = %w[payslip receipt statement other].freeze

  validates :document_type, inclusion: { in: DOCUMENT_TYPES }
  validates :start_year, presence: true, numericality: { only_integer: true }
  validates :file, presence: true, on: :create

  scope :for_year, ->(start_year) { where(start_year: start_year).order(document_date: :desc, created_at: :desc) }
end
