# frozen_string_literal: true

module Tax
  class DocumentCatalog
    Row = Data.define(
      :id, :source, :filename, :byte_size, :fy_label, :start_year, :document_type,
      :period_label, :tag_names, :entry_id, :tax_document_id, :view_url, :download_url
    )

    def initialize(family:)
      @family = family
    end

    def all_rows
      uploaded_rows + attachment_rows
    end

    def rows_for_fy(start_year)
      fy = FinancialYear.new(start_year)
      all_rows.select { |row| row.start_year == start_year || row_in_fy?(row, fy) }
    end

    private

      def uploaded_rows
        @family.tax_documents.includes(file_attachment: :blob).flat_map do |doc|
          next [] unless doc.file.attached?

          fy = FinancialYear.new(doc.start_year)
          [ Row.new(
            id: "tax_document_#{doc.id}",
            source: :upload,
            filename: doc.file.filename.to_s,
            byte_size: doc.file.byte_size,
            fy_label: fy.label,
            start_year: doc.start_year,
            document_type: doc.document_type,
            period_label: doc.document_date ? I18n.l(doc.document_date) : fy.label,
            tag_names: [],
            entry_id: nil,
            tax_document_id: doc.id,
            view_url: Rails.application.routes.url_helpers.tax_document_path(doc, only_path: true),
            download_url: Rails.application.routes.url_helpers.tax_document_path(doc, only_path: true)
          ) ]
        end
      end

      def attachment_rows
        tax_entries_with_attachments.flat_map do |entry|
          fy = financial_year_for_date(entry.date)
          tag_names = entry.transaction.tags.select { |t| t.name.start_with?("Tax:") }.map(&:name)
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
              view_url: Rails.application.routes.url_helpers.entry_path(entry, only_path: true),
              download_url: Rails.application.routes.url_helpers.rails_blob_path(attachment, disposition: "attachment", only_path: true)
            )
          end
        end
      end

      def tax_entries_with_attachments
        @family.entries
          .joins("INNER JOIN transactions ON transactions.id = entries.entryable_id AND entries.entryable_type = 'Transaction'")
          .joins("INNER JOIN taggings ON taggings.taggable_id = transactions.id AND taggings.taggable_type = 'Transaction'")
          .joins("INNER JOIN tags ON tags.id = taggings.tag_id")
          .joins("INNER JOIN active_storage_attachments ON active_storage_attachments.record_id = transactions.id AND active_storage_attachments.record_type = 'Transaction' AND active_storage_attachments.name = 'attachments'")
          .where("tags.name LIKE ?", "Tax:%")
          .includes(:account, entryable: [ :tags, { attachments_attachments: :blob } ])
          .distinct
      end

      def financial_year_for_date(date)
        FinancialYear.new(FinancialYear.current_start_year(on: date))
      end

      def row_in_fy?(row, fy)
        row.period_label.present? && row.start_year == fy.start_year
      end
  end
end
