# frozen_string_literal: true

require "test_helper"

class CommBankStatement::BackfillRunnerErrorTest < ActiveSupport::TestCase
  test "continues after unexpected parse errors" do
    family = families(:dylan_family)
    account = accounts(:depository)
    dir = Rails.root.join("tmp/commbank_backfill_error_test")
    FileUtils.mkdir_p(dir)
    File.write(dir.join("bad.pdf"), "x")

    mapping = CommBankStatement::Mapping.new({
      "rules" => [ { "pattern" => "**/*.pdf", "account_id" => account.id } ]
    })

    CommBankStatement::Parser.stub(:parse_file, ->(*) { raise "boom" }) do
      summary = CommBankStatement::BackfillRunner.new(
        family: family,
        root: dir,
        mapping: mapping,
        apply: false,
        stdout: StringIO.new
      ).run

      assert_equal 1, summary.reports.size
      assert_equal 1, summary.reports.first.skipped_parse
      assert_match(/boom/, summary.reports.first.errors.first)
    end
  ensure
    FileUtils.rm_rf(dir)
  end
end
