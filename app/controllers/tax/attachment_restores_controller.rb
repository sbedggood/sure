# frozen_string_literal: true

module Tax
  class AttachmentRestoresController < ApplicationController
    def create
      entry = Current.accessible_entries.find(params[:entry_id])
      attachment = entry.transaction.attachments.find(params[:attachment_id])
      DocumentLinker.new(family: Current.family).restore_standalone!(attachment: attachment, entry: entry)

      respond_to do |format|
        format.html { redirect_to entry_path(entry), notice: t("tax.documents.restored_standalone") }
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
