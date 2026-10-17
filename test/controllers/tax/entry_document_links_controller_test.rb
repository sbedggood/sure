# frozen_string_literal: true

require "test_helper"

class Tax::EntryDocumentLinksControllerTest < ActionDispatch::IntegrationTest
  include EntriesTestHelper

  setup do
    sign_in users(:family_admin)
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
      document_date: Date.new(2023, 5, 15)
    )
    @document.file.attach(
      io: StringIO.new("%PDF-1.4"),
      filename: "payslip.pdf",
      content_type: "application/pdf"
    )
    @document.save!
  end

  test "create links tax document from transaction drawer" do
    post tax_entry_document_link_path(entry_id: @entry.id),
      params: { tax_document_id: @document.id },
      as: :turbo_stream

    assert_response :success
    assert_equal @entry.id, @document.reload.entry_id
    assert_match "payslip.pdf", response.body
  end
end
