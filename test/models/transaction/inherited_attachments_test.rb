# frozen_string_literal: true

require "test_helper"

class Transaction::InheritedAttachmentsTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @parent_entry = create_transaction(
      account: accounts(:depository),
      amount: 100,
      name: "Office supplies"
    )
    @parent = @parent_entry.entryable
    @parent.attachments.attach(
      io: StringIO.new("parent receipt"),
      filename: "parent-receipt.pdf",
      content_type: "application/pdf"
    )
    @children = @parent_entry.split!([
      { name: "Deductible portion", amount: 60, category_id: nil },
      { name: "Personal portion", amount: 40, category_id: nil }
    ])
    @child = @children.first.entryable
  end

  test "split child inherits parent attachments for display" do
    assert_empty @child.attachments
    assert_equal [ "parent-receipt.pdf" ], @child.inherited_attachments.map { |a| a.filename.to_s }
    assert_equal 1, @child.display_attachments.size
    assert @child.display_attachments.first.from_parent
    assert_equal @parent, @child.display_attachments.first.owner_transaction
  end

  test "display_attachments includes child and parent files" do
    @child.attachments.attach(
      io: StringIO.new("child receipt"),
      filename: "child-receipt.pdf",
      content_type: "application/pdf"
    )

    filenames = @child.display_attachments.map { |item| item.attachment.filename.to_s }
    assert_equal %w[child-receipt.pdf parent-receipt.pdf], filenames
    assert_equal [ false, true ], @child.display_attachments.map(&:from_parent)
  end

  test "non-split transaction has no inherited attachments" do
    plain = create_transaction(account: accounts(:depository), amount: 25).entryable

    assert_nil plain.split_parent_transaction
    assert_empty plain.inherited_attachments
    refute plain.display_attachments.any?(&:from_parent)
  end
end
