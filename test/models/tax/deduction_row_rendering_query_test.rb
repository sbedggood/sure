# frozen_string_literal: true

require "test_helper"

class Tax::DeductionRowRenderingQueryTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @other_account = accounts(:credit_card)
    @phone = @family.tags.create!(name: "Tax: Phone", color: "#4da568")
    @start_year = 2023
  end

  test "deduction row rendering does not N+1 split children, transfers, or attachments" do
    4.times do |i|
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
      parent_entry.split!([
        { name: "Business #{i}a", amount: 60, category_id: nil },
        { name: "Business #{i}b", amount: 40, category_id: nil }
      ]).each { |child| child.entryable.tags << @phone }
    end

    4.times do |i|
      transfer = create_transfer(
        from_account: @account,
        to_account: @other_account,
        amount: 75 + i,
        date: Date.new(2023, 9, 1) + i,
        currency: "AUD"
      )
      transfer.outflow_transaction.tags << @phone
    end

    presenter = Tax::DeductionsPresenter.new(family: @family, start_year: @start_year)
    entries = presenter.groups.flat_map(&:entries)
    entry_ids = entries.map(&:id)

    assert_operator entries.size, :>=, 12
    assert entries.any?(&:split_child?)
    assert entries.any? { |entry| entry.entryable.transfer_as_outflow.present? || entry.entryable.transfer_as_inflow.present? }

    split_parent_entry_ids = Entry.where(parent_entry_id: entry_ids).distinct.pluck(:parent_entry_id).to_set
    accessible_account_ids = @family.accounts.merge(Account.accessible_by(users(:family_admin))).pluck(:id)

    renderer = ApplicationController.renderer.new(
      "http_host" => "www.example.com",
      "https" => false
    )

    queries = capture_sql_queries do
      entries.each do |entry|
        renderer.render(
          partial: "transactions/transaction",
          locals: {
            entry: entry,
            view_ctx: "tax_deductions",
            tax_deductions_start_year: @start_year
          },
          assigns: {
            split_parent_entry_ids: split_parent_entry_ids,
            accessible_account_ids: accessible_account_ids
          }
        )

        renderer.render(
          partial: "tax/dashboard/deduction_attachments",
          locals: { entry: entry }
        )
      end
    end

    assert_empty queries.grep(/FROM "entries"/)
    assert_empty queries.grep(/FROM "transactions"/)
    assert_empty queries.grep(/FROM "transfers"/)
    assert_empty queries.grep(/FROM "active_storage_attachments"/)
    assert_empty queries.grep(/FROM "active_storage_blobs"/)
    assert_operator queries.size, :<=, 5, "expected at most a handful of queries, got #{queries.size}:\n#{queries.join("\n")}"
  end
end
