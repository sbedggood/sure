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

  test "apply imports entries and stores statement in vault" do
    pdf_src = file_fixture("imports/sample_bank_statement.pdf")
    FileUtils.cp(pdf_src, @dir.join("everyday.pdf"))

    text = file_fixture("commbank_statements/everyday_jul_2024.txt").read
    parse_result = CommBankStatement::Parser.parse_text(text, filename: "everyday.pdf")
    mapping = CommBankStatement::Mapping.new({
      "rules" => [ { "pattern" => "**/*.pdf", "account_id" => @account.id } ]
    })

    assert_difference -> { @account.entries.where(source: "commbank_statement").count }, 3 do
      assert_difference "AccountStatement.count", 1 do
        CommBankStatement::Parser.stub(:parse_file, parse_result) do
          CommBankStatement::BackfillRunner.new(
            family: @family,
            root: @dir,
            mapping: mapping,
            apply: true,
            stdout: StringIO.new
          ).run
        end
      end
    end

    entry = @account.entries.find_by(source: "commbank_statement")
    assert entry.external_id.start_with?("commbank_pdf_")
    assert entry.data_enrichments.exists?(attribute_name: "notes", source: "commbank_statement")

    statement = AccountStatement.order(:created_at).last
    assert_equal @account, statement.account
    assert_equal parse_result.period_end_on, statement.period_end_on
    assert statement.original_file.attached?
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
