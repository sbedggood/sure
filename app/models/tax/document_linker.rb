# frozen_string_literal: true

module Tax
  class DocumentLinker
    STANDALONE_ORIGIN_METADATA_KEY = "tax_standalone_origin"

    def initialize(family:)
      @family = family
    end

    def link_to_entry!(tax_document:, entry:)
      raise ActiveRecord::RecordNotFound unless tax_document.family_id == @family.id

      transaction = entry.transaction
      blob = tax_document.file.blob

      ApplicationRecord.transaction do
        tax_document.file.detach
        transaction.attachments.attach(blob)
        attachment = ActiveStorage::Attachment.where(record: transaction, name: "attachments").order(:created_at).last
        mark_standalone_origin!(attachment)
        DocumentType.ensure_tags_for!(family: @family, transaction: transaction, document_type: tax_document.document_type)
        tax_document.destroy!
        attachment
      end
    end

    def restore_standalone!(attachment:, entry:)
      transaction = entry.transaction
      raise ActiveRecord::RecordNotFound unless transaction.attachments.include?(attachment)
      raise ArgumentError, "attachment was not linked from a standalone tax document" unless standalone_origin?(attachment)

      blob = attachment.blob
      tag_names = transaction.tags.map(&:name)
      document_type = DocumentType.infer_from_tag_names(tag_names)

      ApplicationRecord.transaction do
        attachment.destroy
        remove_payslip_tag!(transaction)
        doc = @family.tax_documents.new(
          document_type: document_type,
          start_year: FinancialYear.current_start_year(on: entry.date),
          document_date: entry.date
        )
        doc.file.attach(blob)
        doc.save!
        doc
      end
    end

    def self.standalone_origin?(attachment)
      attachment.blob.metadata[STANDALONE_ORIGIN_METADATA_KEY] == true
    end

    private

      def mark_standalone_origin!(attachment)
        blob = attachment.blob
        blob.metadata = blob.metadata.merge(STANDALONE_ORIGIN_METADATA_KEY => true)
        blob.save!
      end

      def standalone_origin?(attachment)
        self.class.standalone_origin?(attachment)
      end

      def remove_payslip_tag!(transaction)
        payslip_tag = @family.tags.find_by(name: DocumentType::PAYSLIP_TAG)
        return unless payslip_tag

        transaction.update!(tag_ids: transaction.tag_ids - [ payslip_tag.id ])
      end
  end
end
