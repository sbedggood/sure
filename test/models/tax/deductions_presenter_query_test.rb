# frozen_string_literal: true

require "test_helper"

class Tax::DeductionsPresenterQueryTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @phone = @family.tags.create!(name: "Tax: Phone", color: "#4da568")
    @start_year = 2023
  end

  test "display_attachments for deduction rows does not issue per-row entry or attachment queries" do
    5.times do |i|
      parent_entry = create_transaction(
        account: @account,
        date: Date.new(2023, 8, 1) + i,
        amount: 100,
        currency: "AUD",
        name: "Split parent #{i}",
        tags: [ @phone ]
      )
      parent_entry.entryable.attachments.attach(
        io: StringIO.new("receipt #{i}"),
        filename: "parent-#{i}.pdf",
        content_type: "application/pdf"
      )
      children = parent_entry.split!([
        { name: "Business #{i}a", amount: 60, category_id: nil },
        { name: "Business #{i}b", amount: 40, category_id: nil }
      ])
      children.each { |child| child.entryable.tags << @phone }
    end

    presenter = Tax::DeductionsPresenter.new(family: @family, start_year: @start_year)
    entries = presenter.groups.flat_map(&:entries)
    split_children = entries.select(&:split_child?)

    assert_operator entries.size, :>=, 10
    assert_operator split_children.size, :>=, 10

    queries = capture_sql_queries do
      entries.each do |entry|
        transaction = entry.entryable
        transaction.display_attachments
        transaction.display_attachments?
      end
    end

    assert_empty queries.grep(/FROM "entries"/)
    assert_empty queries.grep(/FROM "transactions"/)
    assert_empty queries.grep(/FROM "active_storage_attachments"/)
    assert_empty queries.grep(/FROM "active_storage_blobs"/)
  end
end
