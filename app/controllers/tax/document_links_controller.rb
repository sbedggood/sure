# frozen_string_literal: true

module Tax
  class DocumentLinksController < ApplicationController
    include Tax::StartYearFromParams

    def show
      @document = Current.family.tax_documents.unlinked.find(params[:tax_document_id])
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

      respond_to do |format|
        format.html do
          redirect_to entry_path(entry), notice: t("tax.documents.linked")
        end
        format.turbo_stream do
          render turbo_stream: attachment_refresh_stream(entry)
        end
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

      def attachment_refresh_stream(entry)
        turbo_stream.replace(
          "transaction_attachments_#{entry.transaction.id}",
          partial: "transactions/attachments",
          locals: attachment_locals_for(entry)
        )
      end

      def attachment_locals_for(entry)
        permission = entry.account.permission_for(Current.user)
        {
          transaction: entry.transaction,
          can_upload: permission.in?([ :owner, :full_control, :read_write ]),
          can_delete: permission.in?([ :owner, :full_control ])
        }
      end
  end
end
