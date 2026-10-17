# frozen_string_literal: true

require "test_helper"

class Tax::DocumentLinkerTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @linker = Tax::DocumentLinker.new(family: @family)
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
      document_date: Date.new(2023, 5, 15)
    )
    @document.file.attach(
      io: StringIO.new("%PDF-1.4"),
      filename: "payslip.pdf",
      content_type: "application/pdf"
    )
    @document.save!
  end

  test "link_to_entry attaches blob and removes tax document" do
    attachment = @linker.link_to_entry!(tax_document: @document, entry: @entry)

    assert_not TaxDocument.exists?(@document.id)
    assert @entry.transaction.attachments.include?(attachment)
    assert_includes @entry.transaction.tags.map(&:name), Tax::DocumentType::PAYSLIP_TAG
    assert Tax::DocumentLinker.standalone_origin?(attachment)
  end

  test "restore_standalone recreates tax document and removes attachment" do
    attachment = @linker.link_to_entry!(tax_document: @document, entry: @entry)

    doc = @linker.restore_standalone!(attachment: attachment, entry: @entry)

    assert doc.persisted?
    assert doc.file.attached?
    assert_equal "payslip.pdf", doc.file.filename.to_s
    @entry.transaction.reload
    assert_equal 0, @entry.transaction.attachments.count
    assert_not_includes @entry.transaction.tags.map(&:name), Tax::DocumentType::PAYSLIP_TAG
  end
end
