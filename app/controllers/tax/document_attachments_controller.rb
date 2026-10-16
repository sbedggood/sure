# frozen_string_literal: true

module Tax
  class DocumentAttachmentsController < ApplicationController
    def destroy
      entry = Current.accessible_entries.find(params[:entry_id])
      transaction = entry.transaction
      tax_tag_ids = transaction.tags.select { |t| t.name.start_with?("Tax:") }.map(&:id)
      transaction.update!(tag_ids: transaction.tag_ids - tax_tag_ids)

      redirect_to tax_dashboard_path(
        start_year: params[:start_year].presence || Tax::FinancialYear.current_start_year,
        section: "documents_all"
      ), notice: t("tax.documents_all.unlinked")
    end
  end
end
