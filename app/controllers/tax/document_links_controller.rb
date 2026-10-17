# frozen_string_literal: true

module Tax
  class DocumentLinksController < ApplicationController
    include Tax::StartYearFromParams

    def show
      @document = Current.family.tax_documents.unlinked.find(params[:tax_document_id])
      @return_to = params[:return_to].presence
      @candidate_query = params[:q]
      @fy_filter = if params.key?(:fy)
        params[:fy].presence || "all"
      else
        default_fy_filter_for(@document)
      end
      @account_id = params[:account_id].presence
      @fy_options = financial_year_options
      @account_options = Current.family.accounts.visible.alphabetically
      @search_results = document_link_search.results(
        query: @candidate_query,
        fy_filter: @fy_filter,
        account_id: @account_id
      )
      render layout: false
    end

    def create
      document = Current.family.tax_documents.unlinked.find(params[:tax_document_id])
      entry = Current.accessible_entries.find(params[:entry_id])
      DocumentLinker.new(family: Current.family).link_to_entry!(tax_document: document, entry: entry)
      target = document_link_return_to

      respond_to do |format|
        format.html { redirect_to target, notice: t("tax.documents.linked") }
        format.turbo_stream { render turbo_stream: turbo_stream.action(:redirect, target) }
      end
    end

    def destroy
      document = Current.family.tax_documents.find(params[:tax_document_id])
      if document.entry_id.present?
        entry = document.entry
        document.update!(entry_id: nil)
        redirect_to tax_document_link_path(tax_document_id: document.id),
          notice: t("tax.documents.unlinked")
        return
      end

      redirect_to tax_dashboard_path(section: "documents"), alert: t("tax.documents.link_missing")
    end

    private

      def default_fy_filter_for(document)
        if document.document_date
          Tax::FinancialYear.current_start_year(on: document.document_date).to_s
        else
          document.start_year.to_s
        end
      end

      def document_link_search
        DocumentLinkSearch.new(
          family: Current.family,
          document: @document,
          entries_scope: Current.accessible_entries
        )
      end

      def financial_year_options
        current = Tax::FinancialYear.current_start_year
        (current - 5..current).map do |year|
          fy = Tax::FinancialYear.new(year)
          [ "#{fy.label} (#{fy.start_on.year}–#{fy.end_on.year})", year ]
        end.reverse
      end

      def document_link_return_to
        safe_return_path(params[:return_to].presence || request.referer)
      end

      def safe_return_path(path)
        return tax_documents_path if path.blank?

        uri = URI.parse(path)
        return tax_documents_path unless uri.host.nil? && path.start_with?("/")

        path
      rescue URI::InvalidURIError
        tax_documents_path
      end
  end
end
