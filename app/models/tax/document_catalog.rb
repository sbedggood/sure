# frozen_string_literal: true

module Tax
  class DocumentCatalog
    Row = Data.define(
      :id, :source, :filename, :byte_size, :fy_label, :start_year, :document_type,
      :period_label, :tag_names, :entry_id, :tax_document_id, :entry_url, :preview_url, :download_url,
      :entry_name, :entry_amount, :account_name, :entry_date, :merchant_logo_url
    )

    def initialize(family:)
      @family = family
    end

    def all_rows
      uploaded_rows + attachment_rows
    end

    def rows_for_fy(start_year)
      return all_rows if start_year.blank?

      fy = FinancialYear.new(start_year.to_i)
      all_rows.select { |row| row.start_year == fy.start_year }
    end

    private

      def uploaded_rows
        @family.tax_documents.includes(file_attachment: :blob, entry: [ :account, { entryable: :merchant } ]).flat_map do |doc|
          next [] unless doc.file.attached?

          fy = FinancialYear.new(doc.start_year)
          linked = doc.entry
          [ build_upload_row(doc, fy, linked) ]
        end
      end

      def build_upload_row(doc, fy, linked)
        entry_meta = entry_metadata(linked)
        Row.new(
          id: "tax_document_#{doc.id}",
          source: :upload,
          filename: doc.file.filename.to_s,
          byte_size: doc.file.byte_size,
          fy_label: fy.label,
          start_year: doc.start_year,
          document_type: doc.document_type,
          period_label: doc.document_date ? I18n.l(doc.document_date) : fy.label,
          tag_names: linked ? linked.transaction.tags.select { |t| t.name.start_with?("Tax:") }.map(&:name) : [],
          entry_id: linked&.id,
          tax_document_id: doc.id,
          entry_url: linked ? entry_path_for(linked) : nil,
          preview_url: preview_tax_document_path_for(doc),
          download_url: download_tax_document_path_for(doc),
          **entry_meta
        )
      end

      def attachment_rows
        tax_entries_with_attachments.flat_map do |entry|
          fy = financial_year_for_date(entry.date)
          tag_names = entry.transaction.tags.select { |t| t.name.start_with?("Tax:") }.map(&:name)
          entry_meta = entry_metadata(entry)
          entry.transaction.attachments.map do |attachment|
            Row.new(
              id: "attachment_#{attachment.id}",
              source: :transaction,
              filename: attachment.filename.to_s,
              byte_size: attachment.byte_size,
              fy_label: fy.label,
              start_year: fy.start_year,
              document_type: "receipt",
              period_label: I18n.l(entry.date),
              tag_names: tag_names,
              entry_id: entry.id,
              tax_document_id: nil,
              entry_url: entry_path_for(entry),
              preview_url: attachment_preview_path_for(attachment),
              download_url: Rails.application.routes.url_helpers.rails_blob_path(attachment, disposition: "attachment", only_path: true),
              **entry_meta
            )
          end
        end
      end

      def entry_metadata(entry)
        return {
          entry_name: nil,
          entry_amount: nil,
          account_name: nil,
          entry_date: nil,
          merchant_logo_url: nil
        } unless entry

        transaction = entry.transaction
        {
          entry_name: entry.name,
          entry_amount: entry.amount,
          account_name: entry.account.name,
          entry_date: entry.date,
          merchant_logo_url: transaction.merchant&.logo_url
        }
      end

      def tax_entries_with_attachments
        @family.entries
          .joins("INNER JOIN transactions ON transactions.id = entries.entryable_id AND entries.entryable_type = 'Transaction'")
          .joins("INNER JOIN taggings ON taggings.taggable_id = transactions.id AND taggings.taggable_type = 'Transaction'")
          .joins("INNER JOIN tags ON tags.id = taggings.tag_id")
          .joins("INNER JOIN active_storage_attachments ON active_storage_attachments.record_id = transactions.id AND active_storage_attachments.record_type = 'Transaction' AND active_storage_attachments.name = 'attachments'")
          .where("tags.name LIKE ?", "Tax:%")
          .where.not(tags: { name: Tax::TagCatalog::DECLINED_TAG })
          .includes(:account, entryable: [ :tags, :merchant, { attachments_attachments: :blob } ])
          .distinct
      end

      def financial_year_for_date(date)
        FinancialYear.new(FinancialYear.current_start_year(on: date))
      end

      def entry_path_for(entry)
        Rails.application.routes.url_helpers.entry_path(entry, only_path: true)
      end

      def preview_tax_document_path_for(doc)
        Rails.application.routes.url_helpers.preview_tax_document_path(doc, only_path: true)
      end

      def download_tax_document_path_for(doc)
        Rails.application.routes.url_helpers.download_tax_document_path(doc, only_path: true)
      end

      def attachment_preview_path_for(attachment)
        Rails.application.routes.url_helpers.attachment_preview_tax_documents_path(
          attachment_id: attachment.id,
          only_path: true
        )
      end
  end
end
