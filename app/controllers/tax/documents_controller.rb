# frozen_string_literal: true

module Tax
  class DocumentsController < ApplicationController
    include Tax::StartYearFromParams

    before_action :set_document, only: %i[show destroy]
    before_action :set_breadcrumbs

    def index
      @document_catalog = Tax::DocumentCatalog.new(family: Current.family)
      @fy_filter = params[:doc_fy].presence
      @rows = if @fy_filter.present?
        @document_catalog.rows_for_fy(@fy_filter)
      else
        @document_catalog.all_rows
      end
      @fy_options = financial_year_options
    end

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

      def set_breadcrumbs
        @breadcrumbs = [
          [ I18n.t("breadcrumbs.home"), root_path ],
          [ I18n.t("breadcrumbs.documents"), nil ]
        ]
      end

      def set_document
        @document = Current.family.tax_documents.find(params[:id])
      end

      def document_params
        params.permit(:document_type, :document_date, :note)
      end

      def financial_year_options
        current = Tax::FinancialYear.current_start_year
        (current - 5..current).map do |year|
          fy = Tax::FinancialYear.new(year)
          [ fy.label, year ]
        end.reverse
      end
  end
end
