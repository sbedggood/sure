# frozen_string_literal: true

require "test_helper"

class Tax::DocumentLinksControllerTest < ActionDispatch::IntegrationTest
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

  test "create links document and refreshes attachments via turbo stream" do
    post tax_document_link_create_path(tax_document_id: @document.id),
      params: { entry_id: @entry.id },
      as: :turbo_stream

    assert_response :success
    assert_equal @entry.id, @document.reload.entry_id
    assert_match "transaction_attachments_#{@entry.transaction.id}", response.body
    assert_match "Linked tax documents", response.body
    assert_match "payslip.pdf", response.body
  end

  test "destroy unlinks document and refreshes attachments via turbo stream" do
    @document.update!(entry: @entry)

    delete tax_document_link_destroy_path(tax_document_id: @document.id), as: :turbo_stream

    assert_response :success
    assert_nil @document.reload.entry_id
    assert_match "transaction_attachments_#{@entry.transaction.id}", response.body
    assert_no_match "Linked tax documents", response.body
  end
end
