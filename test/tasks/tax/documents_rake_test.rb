# frozen_string_literal: true

require "test_helper"
require "rake"

class Tax::DocumentsRakeTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @entry = create_transaction(
      account: @account,
      date: Date.new(2023, 5, 15),
      amount: 100,
      currency: "AUD",
      name: "Salary"
    )
    @document = @family.tax_documents.new(
      document_type: "payslip",
      start_year: 2023,
      document_date: Date.new(2023, 5, 15),
      entry: @entry
    )
    @document.file.attach(
      io: StringIO.new("%PDF-1.4"),
      filename: "payslip.pdf",
      content_type: "application/pdf"
    )
    @document.save!

    Rails.application.load_tasks
  end

  test "dry run reports linked document counts" do
    out = capture_io do
      ENV["DRY_RUN"] = "1"
      Rake::Task["tax:documents:migrate_linked_to_attachments"].reenable
      Rake::Task["tax:documents:migrate_linked_to_attachments"].invoke
    end
    ENV.delete("DRY_RUN")

    assert_match(/Linked tax documents: 1/, out.first)
    assert TaxDocument.exists?(@document.id)
  end

  test "migrate moves linked documents to attachments" do
    Rake::Task["tax:documents:migrate_linked_to_attachments"].reenable
    Rake::Task["tax:documents:migrate_linked_to_attachments"].invoke

    assert_not TaxDocument.exists?(@document.id)
    assert @entry.transaction.attachments.attached?
    assert_includes @entry.transaction.tags.map(&:name), Tax::DocumentType::PAYSLIP_TAG
  end
end
