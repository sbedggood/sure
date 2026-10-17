# frozen_string_literal: true

module Tax
  class DocumentsController < ApplicationController
    include Tax::StartYearFromParams

    before_action :set_document, only: %i[show destroy]

    def index
      @document_catalog = Tax::DocumentCatalog.new(family: Current.family)
      @fy_filter = params[:doc_fy].presence
      @doc_type = params[:doc_type].presence || "all"
      @rows = if @fy_filter.present?
        @document_catalog.rows_for_fy(@fy_filter)
      else
        @document_catalog.all_rows
      end
      @fy_options = financial_year_options
    end

    def new
      @start_year = params[:start_year].presence&.to_i || Tax::FinancialYear.current_start_year
      @return_to = params[:return_to].presence || tax_dashboard_path(start_year: @start_year, section: "documents")
    end

    def create
      start_year = params.require(:start_year).to_i
      document = Current.family.tax_documents.new(document_params.merge(start_year: start_year))
      document.file.attach(params.require(:file))

      return_to = safe_return_path(params[:return_to])

      if document.save
        redirect_to return_to, notice: t("tax.documents.created")
      else
        redirect_to return_to, alert: document.errors.full_messages.to_sentence
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

      def financial_year_options
        current = Tax::FinancialYear.current_start_year
        (current - 5..current).map do |year|
          fy = Tax::FinancialYear.new(year)
          [ fy.label, year ]
        end.reverse
      end

      def safe_return_path(path)
        return tax_dashboard_path(section: "documents") if path.blank?

        uri = URI.parse(path)
        return tax_dashboard_path(section: "documents") unless uri.host.nil? && path.start_with?("/")

        path
      rescue URI::InvalidURIError
        tax_dashboard_path(section: "documents")
      end
  end
end
