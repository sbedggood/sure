# frozen_string_literal: true

class Api::V1::Tax::DocumentsController < Api::V1::Tax::BaseController
  before_action -> { authorize_scope!(:read) }, only: %i[index show]
  before_action -> { authorize_scope!(:read_write) }, only: %i[create destroy]
  before_action :set_document, only: %i[show destroy]

  def index
    documents = family.tax_documents.for_year(tax_start_year)
    render json: documents.map { |doc| document_json(doc) }
  end

  def show
    if @document.file.attached?
      redirect_to rails_blob_url(@document.file, disposition: "attachment", only_path: false)
    else
      render json: { error: "not_found", message: "File not attached" }, status: :not_found
    end
  end

  def create
    document = family.tax_documents.new(
      start_year: tax_start_year,
      document_type: params.require(:document_type),
      document_date: params[:document_date],
      note: params[:note]
    )
    document.file.attach(params.require(:file))

    if document.save
      render json: document_json(document), status: :created
    else
      render json: { error: "validation_failed", message: document.errors.full_messages.join("; ") },
        status: :unprocessable_entity
    end
  end

  def destroy
    @document.file.purge if @document.file.attached?
    @document.destroy!
    head :no_content
  end

  private

    def family
      current_resource_owner.family
    end

    def set_document
      @document = family.tax_documents.find(params[:id])
    end

    def document_json(document)
      {
        id: document.id,
        start_year: document.start_year,
        document_type: document.document_type,
        document_date: document.document_date&.iso8601,
        note: document.note,
        filename: document.file.attached? ? document.file.filename.to_s : nil,
        byte_size: document.file.attached? ? document.file.byte_size : nil,
        created_at: document.created_at.iso8601
      }
    end
end
