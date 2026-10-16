# frozen_string_literal: true

module Tax
  class DocumentsController < ApplicationController
    before_action :set_document, only: %i[show destroy]

    def create
      start_year = params.require(:start_year).to_i
      document = Current.family.tax_documents.new(document_params.merge(start_year: start_year))
      document.file.attach(params.require(:file))

      if document.save
        redirect_to tax_dashboard_path(start_year: start_year, section: "documents"),
          notice: t("tax.documents.created")
      else
        redirect_to tax_dashboard_path(start_year: start_year, section: "documents"),
          alert: document.errors.full_messages.to_sentence
      end
    end

    def show
      redirect_to rails_blob_path(@document.file, disposition: "attachment")
    end

    def destroy
      start_year = @document.start_year
      @document.file.purge if @document.file.attached?
      @document.destroy!
      redirect_to tax_dashboard_path(start_year: start_year, section: "documents"),
        notice: t("tax.documents.deleted")
    end

    private

      def set_document
        @document = Current.family.tax_documents.find(params[:id])
      end

      def document_params
        params.permit(:document_type, :document_date, :note)
      end
  end
end
