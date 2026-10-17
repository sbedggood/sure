# frozen_string_literal: true

module Tax
  class DocumentLinksController < ApplicationController
    include Tax::StartYearFromParams

    def show
      @document = Current.family.tax_documents.find(params[:tax_document_id])
      @query = params[:q]
      @candidates = search_candidates
      render layout: false
    end

    def create
      document = Current.family.tax_documents.find(params[:tax_document_id])
      entry = Current.accessible_entries.find(params[:entry_id])
      document.update!(entry: entry)

      redirect_to tax_document_link_path(tax_document_id: document.id),
        notice: t("tax.documents.linked")
    end

    def destroy
      document = Current.family.tax_documents.find(params[:tax_document_id])
      document.update!(entry_id: nil)

      redirect_to tax_document_link_path(tax_document_id: document.id),
        notice: t("tax.documents.unlinked")
    end

    private

      def search_candidates
        scope = Current.family.entries
          .joins("INNER JOIN transactions ON transactions.id = entries.entryable_id AND entries.entryable_type = 'Transaction'")
          .includes(:account, entryable: :merchant)
          .order(date: :desc)
          .limit(50)

        if @query.present?
          scope = scope.where("entries.name ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%")
        end

        scope
      end
  end
end
