# frozen_string_literal: true

require "test_helper"

class CommBankStatement::BackfillRunnerIntegrationTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @account.update!(currency: "AUD")
    @dir = Rails.root.join("tmp/commbank_backfill_integration")
    FileUtils.mkdir_p(@dir)

    pdf_bytes = file_fixture("imports/sample_bank_statement.pdf").read
    File.write(@dir.join("stmt_one.pdf"), pdf_bytes)
    File.write(@dir.join("stmt_two.pdf"), pdf_bytes)

    @parse_one = parse_everyday_statement(
      period: "1 Jan 2024 to 31 Jan 2024",
      opening_date: "01 Jan 2024",
      closing_date: "31 Jan 2024",
      opening: "2,000.00",
      rows: [
        [ "01 Jan", "WOOLWORTHS 123 SYDNEY", "50.00", "1,950.00" ],
        [ "01 Jan", "WOOLWORTHS 123 SYDNEY", "50.00", "1,900.00" ],
        [ "03 Jan", "WOOLWORTHS 123 SYDNEY", "50.00", "1,850.00" ],
        [ "05 Jan", "WOOLWORTHS 123 SYDNEY", "50.00", "1,800.00" ],
        [ "10 Jan", "WOOLWORTHS 123 SYDNEY", "50.00", "1,750.00" ]
      ],
      closing: "1,750.00"
    )
    @parse_two = parse_everyday_statement(
      period: "1 Feb 2024 to 29 Feb 2024",
      opening_date: "01 Feb 2024",
      closing_date: "29 Feb 2024",
      opening: "1,750.00",
      rows: [
        [ "02 Feb", "WOOLWORTHS 123 SYDNEY", "50.00", "1,700.00" ],
        [ "02 Feb", "WOOLWORTHS 123 SYDNEY", "50.00", "1,650.00" ],
        [ "04 Feb", "WOOLWORTHS 123 SYDNEY", "50.00", "1,600.00" ],
        [ "06 Feb", "WOOLWORTHS 123 SYDNEY", "50.00", "1,550.00" ],
        [ "08 Feb", "WOOLWORTHS 123 SYDNEY", "50.00", "1,500.00" ]
      ],
      closing: "1,500.00"
    )

    @mapping = CommBankStatement::Mapping.new({
      "before_date" => "2026-01-01",
      "rules" => [ { "pattern" => "**/*.pdf", "account_id" => @account.id } ]
    })
  end

  teardown do
    FileUtils.rm_rf(@dir)
    Current.defer_account_syncs = false
  end

  test "apply imports repeated identical charges across two statements and dedupes one redbark row only" do
    create_transaction(
      account: @account,
      date: Date.new(2024, 1, 5),
      amount: 50,
      currency: "AUD",
      name: "WOOLWORTHS 123 SYDNEY",
      source: "redbark",
      external_id: "rbk_woolworths_jan5"
    )

    parse_by_path = {
      @dir.join("stmt_one.pdf").to_s => @parse_one,
      @dir.join("stmt_two.pdf").to_s => @parse_two
    }

    Account.any_instance.expects(:sync_later).once

    summary = nil
    CommBankStatement::Parser.stub(:parse_file, ->(path) { parse_by_path.fetch(path) }) do
      summary = CommBankStatement::BackfillRunner.new(
        family: @family,
        root: @dir,
        mapping: @mapping,
        apply: true,
        stdout: StringIO.new
      ).run
    end

    total_txns = @parse_one.transactions.size + @parse_two.transactions.size
    assert_equal total_txns - 1, summary.imported_total
    assert_equal 1, summary.duplicate_skipped_total
    assert_equal total_txns - 1, @account.entries.where(source: "commbank_statement").count

    rerun = nil
    CommBankStatement::Parser.stub(:parse_file, ->(path) { parse_by_path.fetch(path) }) do
      rerun = CommBankStatement::BackfillRunner.new(
        family: @family,
        root: @dir,
        mapping: @mapping,
        apply: true,
        stdout: StringIO.new
      ).run
    end

    assert_equal total_txns - 1, @account.entries.where(source: "commbank_statement").count
    assert_equal 0, rerun.imported_total
    assert_equal total_txns, rerun.duplicate_skipped_total
  end

  private

    def parse_everyday_statement(period:, opening_date:, closing_date:, opening:, rows:, closing:)
      body = <<~TEXT
        Statement period #{period}
        Date Transaction                                                                Debit        Credit                 Balance
        #{opening_date} OPENING BALANCE                                                                                      $#{opening} CR
      TEXT

      rows.each do |date, description, debit, balance|
        body << format(
          "%-8s %-60s %8s   (                        $%s CR\n",
          date, description, debit, balance
        )
      end

      body << "#{closing_date} CLOSING BALANCE                                                                          $#{closing} CR\n"

      CommBankStatement::Parser.parse_text(body, filename: "everyday.pdf")
    end
end
