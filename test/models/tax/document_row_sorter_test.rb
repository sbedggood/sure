# frozen_string_literal: true

require "test_helper"

class Tax::DocumentRowSorterTest < ActiveSupport::TestCase
  Row = Tax::DocumentCatalog::Row

  test "sorts by date descending by default" do
    older = build_row(filename: "a.pdf", entry_date: Date.new(2023, 1, 1))
    newer = build_row(filename: "b.pdf", entry_date: Date.new(2023, 6, 1))

    sorted = Tax::DocumentRowSorter.sort([ older, newer ], sort: "date", direction: "desc")

    assert_equal [ newer.id, older.id ], sorted.map(&:id)
  end

  test "sorts by merchant name ascending" do
    beta = build_row(filename: "b.pdf", entry_name: "Beta Shop")
    alpha = build_row(filename: "a.pdf", entry_name: "Alpha Shop")

    sorted = Tax::DocumentRowSorter.sort([ beta, alpha ], sort: "merchant", direction: "asc")

    assert_equal [ alpha.id, beta.id ], sorted.map(&:id)
  end

  test "sorts by amount with missing amounts last in both directions" do
    with_amount = build_row(filename: "paid.pdf", entry_amount: BigDecimal("50"))
    missing = build_row(filename: "upload.pdf", entry_amount: nil)

    asc = Tax::DocumentRowSorter.sort([ missing, with_amount ], sort: "amount", direction: "asc")
    desc = Tax::DocumentRowSorter.sort([ missing, with_amount ], sort: "amount", direction: "desc")

    assert_equal [ with_amount.id, missing.id ], asc.map(&:id)
    assert_equal [ with_amount.id, missing.id ], desc.map(&:id)
  end

  test "rejects unknown sort columns" do
    row = build_row(filename: "a.pdf", entry_date: Date.new(2023, 1, 1))

    sorted = Tax::DocumentRowSorter.sort([ row ], sort: "invalid", direction: "asc")

    assert_equal [ row.id ], sorted.map(&:id)
  end

  private

    def build_row(filename:, entry_date: nil, entry_name: nil, entry_amount: nil)
      Row.new(
        id: "row_#{filename}",
        source: :upload,
        filename: filename,
        byte_size: 100,
        fy_label: "FY23",
        start_year: 2022,
        document_type: "receipt",
        period_label: "Jan",
        tag_names: [],
        entry_id: nil,
        tax_document_id: nil,
        attachment_id: nil,
        restorable_standalone: false,
        entry_url: nil,
        preview_url: "/preview",
        download_url: "/download",
        entry_name: entry_name,
        entry_amount: entry_amount,
        account_name: nil,
        entry_date: entry_date,
        merchant_logo_url: nil
      )
    end
end
