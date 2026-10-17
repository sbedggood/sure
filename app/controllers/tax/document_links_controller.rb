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

      respond_to do |format|
        format.html do
          redirect_to tax_document_link_path(tax_document_id: document.id),
            notice: t("tax.documents.linked")
        end
        format.turbo_stream do
          render turbo_stream: attachment_refresh_stream(entry)
        end
      end
    end

    def destroy
      document = Current.family.tax_documents.find(params[:tax_document_id])
      entry = document.entry
      document.update!(entry_id: nil)

      respond_to do |format|
        format.html do
          redirect_to tax_document_link_path(tax_document_id: document.id),
            notice: t("tax.documents.unlinked")
        end
        format.turbo_stream do
          streams = []
          streams << attachment_refresh_stream(entry) if entry
          render turbo_stream: streams
        end
      end
    end

    private

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
