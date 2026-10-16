# frozen_string_literal: true

module CommBankStatement
  StatementLine = Data.define(:date, :description, :amount, :balance, :raw_lines)
end
