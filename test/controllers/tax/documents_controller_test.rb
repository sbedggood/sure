# frozen_string_literal: true

require "test_helper"

class Tax::DocumentsControllerTest < ActionDispatch::IntegrationTest
  include EntriesTestHelper

  setup do
    sign_in users(:family_admin)
    @family = families(:dylan_family)
    @document = @family.tax_documents.new(
      document_type: "payslip",
      start_year: 2023,
      document_date: Date.new(2023, 5, 15)
    )
    @document.file.attach(
      io: StringIO.new("%PDF-1.4 test"),
      filename: "payslip.pdf",
      content_type: "application/pdf"
    )
    @document.save!
  end

  test "preview renders document viewer frame with inline iframe" do
    get preview_tax_document_path(@document)

    assert_response :success
    assert_select "turbo-frame#document_viewer"
    assert_select "iframe[src=?]", @document.inline_blob_path
    assert_select "a[href=?]", download_tax_document_path(@document)
  end

  test "download redirects with attachment disposition" do
    get download_tax_document_path(@document)

    assert_redirected_to %r{/rails/active_storage/}
    assert_match(/disposition=attachment/, response.redirect_url)
  end

  test "preview_clear empties document viewer frame" do
    get preview_clear_tax_documents_path

    assert_response :success
    assert_select "turbo-frame#document_viewer", count: 1
    assert_select "turbo-frame#document_viewer iframe", count: 0
  end

  test "attachment_preview authorizes family transaction attachments" do
    account = accounts(:depository)
    entry = create_transaction(account: account, date: Date.new(2023, 8, 1), amount: 10, currency: "AUD", name: "Receipt")
    entry.transaction.attachments.attach(
      io: StringIO.new("%PDF-1.4"),
      filename: "receipt.pdf",
      content_type: "application/pdf"
    )
    attachment = entry.transaction.attachments.first

    get attachment_preview_tax_documents_path(attachment_id: attachment.id)

    assert_response :success
    assert_select "turbo-frame#document_viewer iframe"
  end
end
