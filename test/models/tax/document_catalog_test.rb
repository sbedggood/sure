# frozen_string_literal: true

require "test_helper"

class Tax::DocumentCatalogTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @start_year = 2023
    @tag = @family.tags.create!(name: "Tax: Phone", color: "#4da568")
    @entry = create_transaction(
      account: @account,
      date: Date.new(2023, 8, 1),
      amount: 10,
      currency: "AUD",
      name: "Receipt",
      tags: [ @tag ]
    )
    @entry.transaction.attachments.attach(
      io: StringIO.new("pdf"),
      filename: "receipt.pdf",
      content_type: "application/pdf"
    )
  end

  test "includes transaction attachments for tax tagged entries" do
    rows = Tax::DocumentCatalog.new(family: @family).all_rows

    attachment = rows.find { |r| r.source == :transaction }
    assert attachment
    assert_equal "receipt.pdf", attachment.filename
    assert_includes attachment.tag_names, "Tax: Phone"
    assert_equal @entry.id, attachment.entry_id
  end

  test "filters rows by financial year" do
    catalog = Tax::DocumentCatalog.new(family: @family)
    fy_rows = catalog.rows_for_fy(@start_year)

    assert fy_rows.any? { |r| r.source == :transaction }
  end
end
