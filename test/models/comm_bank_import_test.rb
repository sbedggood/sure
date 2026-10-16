# frozen_string_literal: true

require "test_helper"

class CommBankImportTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
  end

  test "default column mappings are applied after create" do
    import = @family.imports.create!(type: "CommBankImport", account: @account)

    CommBankImport.default_column_mappings.each do |attribute, value|
      assert_equal value, import.public_send(attribute)
    end
  end

  test "normalize_csv_content injects header for headerless NetBank export" do
    raw = file_fixture("imports/commbank_netbank.csv").read
    normalized = CommBankImport.normalize_csv_content(raw)

    assert normalized.start_with?("Date,Amount,Description,Balance\n")
    assert_includes normalized, "15/05/2024,-45.99"
  end

  test "normalize_csv_content leaves files that already have a header unchanged" do
    raw = <<~CSV
      Date,Amount,Description,Balance
      15/05/2024,-10.00,Test,100.00
    CSV

    assert_equal raw.strip, CommBankImport.normalize_csv_content(raw).strip
  end

  test "generated rows parse headerless NetBank CSV with correct signage" do
    import = @family.imports.create!(
      type: "CommBankImport",
      account: @account,
      raw_file_str: file_fixture("imports/commbank_netbank.csv").read,
      col_sep: ","
    )

    import.generate_rows_from_csv

    assert_equal 3, import.rows.count

    debit = import.rows.find_by(name: "WOOLWORTHS 1234 SYDNEY")
    assert_equal "-45.99", debit.amount
    assert_in_delta 45.99, debit.signed_amount

    credit = import.rows.find_by(name: "SALARY ACME PTY LTD")
    assert_equal "2500.00", credit.amount
    assert_in_delta(-2500.0, credit.signed_amount)
  end

  test "re-importing the same NetBank CSV does not duplicate transactions" do
    import = @family.imports.create!(
      type: "CommBankImport",
      account: @account,
      raw_file_str: file_fixture("imports/commbank_netbank.csv").read,
      col_sep: ","
    )
    import.generate_rows_from_csv
    import.sync_mappings

    assert_difference -> { @account.entries.count }, 3 do
      import.publish
    end

    repeat = @family.imports.create!(
      type: "CommBankImport",
      account: @account,
      raw_file_str: file_fixture("imports/commbank_netbank.csv").read,
      col_sep: ","
    )
    repeat.generate_rows_from_csv
    repeat.sync_mappings

    assert_no_difference -> { @account.entries.count } do
      repeat.publish
    end
  end
end
