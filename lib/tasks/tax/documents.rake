# frozen_string_literal: true

namespace :tax do
  namespace :documents do
    desc "Move linked TaxDocument files onto transaction attachments (DRY_RUN=1 to preview)"
    task migrate_linked_to_attachments: :environment do
      dry_run = ENV["DRY_RUN"].present?
      scope = TaxDocument.where.not(entry_id: nil).includes(:file_attachment, :family, entry: { entryable: :tags })
      total = scope.count
      payslip_count = scope.where(document_type: "payslip").count
      other_count = total - payslip_count

      puts "Linked tax documents: #{total} (#{payslip_count} payslip, #{other_count} other)"
      if dry_run
        puts "DRY_RUN=1 — no changes written."
        next
      end

      migrated = 0
      errors = 0

      scope.find_each do |document|
        entry = document.entry
        unless entry&.transaction && document.file.attached?
          errors += 1
          puts "SKIP #{document.id}: missing entry or file"
          next
        end

        Tax::DocumentLinker.new(family: document.family).link_to_entry!(tax_document: document, entry: entry)
        migrated += 1
      rescue StandardError => e
        errors += 1
        puts "ERROR #{document.id}: #{e.message}"
      end

      puts "Migrated: #{migrated}, errors: #{errors}"
    end
  end
end
