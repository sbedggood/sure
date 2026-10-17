# frozen_string_literal: true

class TaxDocument < ApplicationRecord
  belongs_to :family
  belongs_to :entry, optional: true

  has_one_attached :file

  DOCUMENT_TYPES = %w[payslip receipt statement other].freeze

  validates :document_type, inclusion: { in: DOCUMENT_TYPES }
  validates :start_year, presence: true, numericality: { only_integer: true }
  validates :file, presence: true, on: :create

  scope :for_year, ->(start_year) { where(start_year: start_year).order(document_date: :desc, created_at: :desc) }
  scope :unlinked, -> { where(entry_id: nil) }

  def previewable?
    return false unless file.attached?

    file.image? || file.content_type == "application/pdf"
  end

  def inline_blob_path
    Rails.application.routes.url_helpers.rails_blob_path(file, disposition: "inline", only_path: true)
  end

  def download_blob_path
    Rails.application.routes.url_helpers.rails_blob_path(file, disposition: "attachment", only_path: true)
  end
end
