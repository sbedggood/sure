# frozen_string_literal: true

# Imports transaction CSV files exported from Commonwealth Bank NetBank.
#
# NetBank's default CSV has no header row: Date, Amount, Description, Balance.
# Amounts are signed (negative = debit/outflow, positive = credit/inflow).
# Some exports include a header line; both shapes are accepted.
class CommBankImport < TransactionImport
  HEADER_ROW = "Date,Amount,Description,Balance"

  DEFAULT_COLUMN_MAPPINGS = {
    amount_type_strategy: "signed_amount",
    signage_convention: "inflows_positive",
    date_col_label: "Date",
    date_format: "%d/%m/%Y",
    name_col_label: "Description",
    amount_col_label: "Amount",
    number_format: "1,234.56"
  }.freeze

  after_create :set_mappings

  def self.default_column_mappings
    DEFAULT_COLUMN_MAPPINGS
  end

  def csv_template
    template = <<~CSV
      #{HEADER_ROW}
      15/05/2024,-45.99,WOOLWORTHS 1234 SYDNEY,1234.56
      16/05/2024,2500.00,SALARY ACME PTY LTD,3734.56
      17/05/2024,-4.50,COFFEE ROASTERS MELBOURNE,3730.06
    CSV

    CSV.parse(template, headers: true)
  end

  # NetBank exports are often headerless; inject the expected header so the
  # generic CSV machinery can map columns by label.
  def parsed_csv
    return @parsed_csv if defined?(@parsed_csv)

    @parsed_csv = self.class.parse_csv_str(normalized_csv_content, col_sep: col_sep)
  end

  def self.normalize_csv_content(content)
    stripped = content.to_s.delete_prefix("\uFEFF").strip
    return stripped if stripped.blank?

    first_line = stripped.lines.first.to_s.strip
    return stripped if header_line?(first_line)

    "#{HEADER_ROW}\n#{stripped}"
  end

  def self.header_line?(line)
    normalized = line.downcase.gsub(/\s+/, "")
    normalized.start_with?("date,amount") || normalized == "date,amount,description,balance"
  end

  # Drop import rows on or after +date+ (e.g. Redbark sync start). Returns rows removed.
  def purge_rows_on_or_after!(date)
    removed = 0
    rows.find_each do |row|
      next if row.date.blank?

      row_date = Date.strptime(row.date, date_format)
      next if row_date < date

      row.destroy!
      removed += 1
    end
    removed
  end

  private

    def set_mappings
      assign_attributes(self.class.default_column_mappings)
      save!
    end

    def normalized_csv_content
      content = raw_file_str || ""
      if rows_to_skip.to_i.positive?
        content = content.lines.drop(rows_to_skip).join
      end

      self.class.normalize_csv_content(content)
    end
end
