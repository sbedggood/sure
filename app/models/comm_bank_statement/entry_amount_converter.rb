# frozen_string_literal: true

module CommBankStatement
  module EntryAmountConverter
    module_function

    # Converts bank-native signed movement to Sure entry amount.
    def to_sure_amount(bank_amount, account)
      case account.accountable_type
      when "CreditCard", "Loan", "OtherLiability"
        bank_amount
      else
        -bank_amount
      end
    end
  end
end
