# frozen_string_literal: true

require "test_helper"

class Tax::DocumentLinkSearchTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @document = @family.tax_documents.new(
      document_type: "receipt",
      start_year: 2023,
      document_date: Date.new(2023, 8, 15)
    )
    @document.file.attach(
      io: StringIO.new("%PDF-1.4"),
      filename: "receipt.pdf",
      content_type: "application/pdf"
    )
    @document.save!
  end

  test "defaults to ranking by date proximity to document date" do
    near = create_transaction(
      account: @account,
      date: Date.new(2023, 8, 14),
      amount: 50,
      currency: "AUD",
      name: "Coffee"
    )
    far = create_transaction(
      account: @account,
      date: Date.new(2023, 7, 1),
      amount: 50,
      currency: "AUD",
      name: "Groceries"
    )

    search = Tax::DocumentLinkSearch.new(family: @family, document: @document)
    results = search.results(query: nil, fy_filter: "2023", account_id: nil)

    assert_equal near.id, results.first.id
    assert_includes results.map(&:id), far.id
  end

  test "search matches notes and amount prefix" do
    with_note = create_transaction(
      account: @account,
      date: Date.new(2023, 6, 1),
      amount: 65.75,
      currency: "AUD",
      name: "Shop",
      notes: "office supplies"
    )
    create_transaction(
      account: @account,
      date: Date.new(2023, 6, 2),
      amount: 10,
      currency: "AUD",
      name: "Other"
    )

    search = Tax::DocumentLinkSearch.new(family: @family, document: @document)

    by_note = search.results(query: "supplies", fy_filter: "all", account_id: nil)
    assert_equal [ with_note.id ], by_note.map(&:id)

    by_amount = search.results(query: "65.7", fy_filter: "all", account_id: nil)
    assert_equal [ with_note.id ], by_amount.map(&:id)

    by_formatted_amount = search.results(query: "$65.75", fy_filter: "all", account_id: nil)
    assert_equal [ with_note.id ], by_formatted_amount.map(&:id)
  end

  test "payslip ranks salary inflow near document date first" do
    @document.update!(document_type: "payslip", document_date: Date.new(2023, 8, 15))

    salary = create_transaction(
      account: @account,
      date: Date.new(2023, 8, 14),
      amount: -5_000,
      currency: "AUD",
      name: "Employer Payroll"
    )
    create_transaction(
      account: @account,
      date: Date.new(2023, 8, 13),
      amount: 40,
      currency: "AUD",
      name: "Lunch"
    )

    search = Tax::DocumentLinkSearch.new(family: @family, document: @document)
    results = search.results(query: nil, fy_filter: "2023", account_id: nil)

    assert_equal salary.id, results.first.id
  end

  test "fy and account filters narrow results" do
    other_account = accounts(:credit_card)
    in_scope = create_transaction(
      account: @account,
      date: Date.new(2023, 8, 1),
      amount: 20,
      currency: "AUD",
      name: "In scope"
    )
    create_transaction(
      account: other_account,
      date: Date.new(2023, 8, 2),
      amount: 20,
      currency: "AUD",
      name: "Wrong account"
    )
    create_transaction(
      account: @account,
      date: Date.new(2022, 5, 1),
      amount: 20,
      currency: "AUD",
      name: "Wrong year"
    )

    search = Tax::DocumentLinkSearch.new(family: @family, document: @document)
    results = search.results(query: nil, fy_filter: "2023", account_id: @account.id)

    assert_equal [ in_scope.id ], results.map(&:id)
  end
end
