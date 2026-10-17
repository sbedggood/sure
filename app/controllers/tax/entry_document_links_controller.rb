# frozen_string_literal: true

module Tax
  class EntryDocumentLinksController < ApplicationController
    def create
      entry = Current.accessible_entries.find(params[:entry_id])
      document = Current.family.tax_documents.find(params[:tax_document_id])
      document.update!(entry: entry)

      respond_to do |format|
        format.html { redirect_to entry_path(entry), notice: t("tax.documents.linked") }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "transaction_attachments_#{entry.transaction.id}",
            partial: "transactions/attachments",
            locals: attachment_locals_for(entry)
          )
        end
      end
    end

    private

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
