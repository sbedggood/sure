# frozen_string_literal: true

require "test_helper"

class Tax::DeductionAttachmentsRenderingTest < ActionView::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @phone = @family.tags.create!(name: "Tax: Phone", color: "#4da568")
  end

  test "deduction attachment partial does not N+1 when rows are preloaded" do
    3.times do |i|
      parent_entry = create_transaction(
        account: @account,
        date: Date.new(2023, 8, 10) + i,
        amount: 50,
        currency: "AUD",
        name: "Split #{i}",
        tags: [ @phone ]
      )
      parent_entry.entryable.attachments.attach(
        io: StringIO.new("receipt"),
        filename: "receipt-#{i}.pdf",
        content_type: "application/pdf"
      )
      child = parent_entry.split!([
        { name: "Tagged split #{i}", amount: 50, category_id: nil }
      ]).first
      child.entryable.tags << @phone
    end

    presenter = Tax::DeductionsPresenter.new(family: @family, start_year: 2023)
    entries = presenter.groups.flat_map(&:entries)

    queries = capture_sql_queries do
      entries.each do |entry|
        render partial: "tax/dashboard/deduction_attachments", locals: { entry: entry }
      end
    end

    assert_empty queries.grep(/FROM "entries"/)
    assert_empty queries.grep(/FROM "transactions"/)
    assert_empty queries.grep(/FROM "active_storage_attachments"/)
  end
end
