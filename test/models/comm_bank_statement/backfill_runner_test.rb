# frozen_string_literal: true

require "test_helper"

class CommBankStatement::BackfillRunnerTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @account.update!(currency: "AUD")
    @dir = Rails.root.join("tmp/commbank_backfill_test")
    FileUtils.mkdir_p(@dir)
  end

  teardown do
    FileUtils.rm_rf(@dir)
  end

  test "dry run counts importable rows before redbark cutoff" do
    create_transaction(
      account: @account,
      date: Date.new(2024, 8, 1),
      amount: 10,
      source: "redbark",
      external_id: "rbk_1"
    )

    report = run_backfill_with_stubbed_parse

    assert report.parse_result.balance_check_passed
    assert_equal 3, report.imported
    assert_equal 0, report.skipped_overlap
  end

  test "dry run skips transactions on or after redbark cutoff" do
    create_transaction(
      account: @account,
      date: Date.new(2024, 7, 1),
      amount: 10,
      source: "redbark",
      external_id: "rbk_early"
    )

    report = run_backfill_with_stubbed_parse

    assert report.parse_result.balance_check_passed
    assert_equal 0, report.imported
    assert_equal 3, report.skipped_overlap
  end

  private

    def run_backfill_with_stubbed_parse
      File.write(@dir.join("everyday.pdf"), "placeholder")
      text = file_fixture("commbank_statements/everyday_jul_2024.txt").read
      parse_result = CommBankStatement::Parser.parse_text(text, filename: "everyday.pdf")
      mapping = CommBankStatement::Mapping.new({
        "rules" => [ { "pattern" => "**/*.pdf", "account_id" => @account.id } ]
      })

      reports = nil
      CommBankStatement::Parser.stub(:parse_file, parse_result) do
        reports = CommBankStatement::BackfillRunner.new(
          family: @family,
          root: @dir,
          mapping: mapping,
          apply: false,
          stdout: StringIO.new
        ).run
      end
      reports.first
    end
end
