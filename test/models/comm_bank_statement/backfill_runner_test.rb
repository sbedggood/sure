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
    Current.defer_account_syncs = false
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

    assert report.balance_check_passed
    assert_equal 3, report.imported
    assert_equal 0, report.skipped_overlap
  end

  test "apply imports entries and stores statement in vault" do
    pdf_src = file_fixture("imports/sample_bank_statement.pdf")
    File.write(@dir.join("everyday.pdf"), pdf_src.read)

    text = file_fixture("commbank_statements/everyday_jul_2024.txt").read
    parse_result = CommBankStatement::Parser.parse_text(text, filename: "everyday.pdf")
    mapping = CommBankStatement::Mapping.new({
      "rules" => [ { "pattern" => "**/*.pdf", "account_id" => @account.id } ]
    })

    Account.any_instance.expects(:sync_later).once

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

    assert report.balance_check_passed
    assert_equal 0, report.imported
    assert_equal 3, report.skipped_overlap
  end

  test "imports identical charges days apart when not matching non-statement dupes" do
    text = <<~TEXT
      Statement period 1 Jul 2024 to 31 Jul 2024
      Date Transaction                                                                Debit        Credit                 Balance
      01 Jul 2024 OPENING BALANCE                                                                                      $1,000.00 CR
      05 Jul COLES SAMPLEVILLE                                                                          50.00   (                        $950.00 CR
      08 Jul COLES SAMPLEVILLE                                                                          50.00   (                        $900.00 CR
      31 Jul 2024 CLOSING BALANCE                                                                          $900.00 CR
    TEXT

    parse_result = CommBankStatement::Parser.parse_text(text, filename: "everyday.pdf")
    File.write(@dir.join("stmt.pdf"), file_fixture("imports/sample_bank_statement.pdf").read)

    mapping = CommBankStatement::Mapping.new({
      "rules" => [ { "pattern" => "**/*.pdf", "account_id" => @account.id } ]
    })

    summary = nil
    CommBankStatement::Parser.stub(:parse_file, parse_result) do
      summary = CommBankStatement::BackfillRunner.new(
        family: @family,
        root: @dir,
        mapping: mapping,
        apply: true,
        stdout: StringIO.new
      ).run
    end

    assert_equal 2, summary.reports.first.imported
    assert_equal 2, @account.entries.where(source: "commbank_statement").count
  end

  test "dedupes against redbark but not other commbank_statement rows" do
    create_transaction(
      account: @account,
      date: Date.new(2024, 7, 5),
      amount: 50,
      currency: "AUD",
      name: "COLES SAMPLEVILLE",
      source: "redbark",
      external_id: "rbk_coles"
    )

    text = <<~TEXT
      Statement period 1 Jul 2024 to 31 Jul 2024
      Date Transaction                                                                Debit        Credit                 Balance
      01 Jul 2024 OPENING BALANCE                                                                                      $1,000.00 CR
      05 Jul COLES SAMPLEVILLE                                                                          50.00   (                        $950.00 CR
      08 Jul COLES SAMPLEVILLE                                                                          50.00   (                        $900.00 CR
      31 Jul 2024 CLOSING BALANCE                                                                          $900.00 CR
    TEXT

    parse_result = CommBankStatement::Parser.parse_text(text, filename: "everyday.pdf")
    File.write(@dir.join("stmt.pdf"), file_fixture("imports/sample_bank_statement.pdf").read)
    mapping = CommBankStatement::Mapping.new({
      "before_date" => "2024-08-01",
      "rules" => [ { "pattern" => "**/*.pdf", "account_id" => @account.id } ]
    })

    summary = nil
    CommBankStatement::Parser.stub(:parse_file, parse_result) do
      summary = CommBankStatement::BackfillRunner.new(
        family: @family,
        root: @dir,
        mapping: mapping,
        apply: false,
        stdout: StringIO.new
      ).run
    end

    report = summary.reports.first
    assert_equal 1, report.imported
    assert_equal 1, report.skipped_duplicate
    assert_equal 0, report.skipped_overlap
  end

  private

    def run_backfill_with_stubbed_parse
      File.write(@dir.join("everyday.pdf"), "placeholder")
      text = file_fixture("commbank_statements/everyday_jul_2024.txt").read
      parse_result = CommBankStatement::Parser.parse_text(text, filename: "everyday.pdf")
      mapping = CommBankStatement::Mapping.new({
        "rules" => [ { "pattern" => "**/*.pdf", "account_id" => @account.id } ]
      })

      summary = nil
      CommBankStatement::Parser.stub(:parse_file, parse_result) do
        summary = CommBankStatement::BackfillRunner.new(
          family: @family,
          root: @dir,
          mapping: mapping,
          apply: false,
          stdout: StringIO.new
        ).run
      end
      summary.reports.first
    end
end
