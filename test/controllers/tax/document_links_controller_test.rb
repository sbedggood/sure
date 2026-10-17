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
      date: Date.new(2023, 8, 15),
      amount: 100,
      currency: "AUD",
      name: "Salary"
    )
    @document = @family.tax_documents.new(
      document_type: "payslip",
      start_year: 2023,
      document_date: Date.new(2023, 8, 15)
    )
    @document.file.attach(
      io: StringIO.new("%PDF-1.4"),
      filename: "payslip.pdf",
      content_type: "application/pdf"
    )
    @document.save!
  end

  test "show includes fy filter default and search results with amount" do
    get tax_document_link_path(tax_document_id: @document.id)

    assert_response :success
    assert_match "document_link_search", response.body
    assert_match "Salary", response.body
    assert_match @entry.amount_money.abs.format, response.body
    assert_match "FY", response.body
  end

  test "show filters by search query" do
    create_transaction(
      account: @account,
      date: Date.new(2023, 8, 16),
      amount: 12,
      currency: "AUD",
      name: "Unrelated purchase"
    )

    get tax_document_link_path(tax_document_id: @document.id), params: { q: "Salary", fy: "2023" }

    assert_response :success
    assert_match "Salary", response.body
    refute_match "Unrelated purchase", response.body
  end

  test "create links document as transaction attachment via turbo stream" do
    post tax_document_link_create_path(tax_document_id: @document.id),
      params: { entry_id: @entry.id },
      as: :turbo_stream

    assert_response :success
    assert_not TaxDocument.exists?(@document.id)
    assert @entry.transaction.attachments.attached?
    assert_match "transaction_attachments_#{@entry.transaction.id}", response.body
    assert_match "payslip.pdf", response.body
  end
end
