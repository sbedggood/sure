# frozen_string_literal: true

module Tax
  module TagCatalog
    PREFIX = "Tax: "

    PROPERTY_EXPENSE_TAGS = [
      "Tax: Property - Interest",
      "Tax: Property - Insurance",
      "Tax: Property - Body Corp",
      "Tax: Property - Rates",
      "Tax: Property - Water",
      "Tax: Property - Improvements",
      "Tax: Property - Internet",
      "Tax: Property - Other"
    ].freeze

    RENTAL_INCOME_PREFIX = "Tax: Rental Income"
    DONATIONS_TAG = "Tax: Donations"
    AGENT_FEES_TAG = "Tax: Agent Fees"

    module_function

    def property_expense?(tag_name)
      PROPERTY_EXPENSE_TAGS.include?(tag_name)
    end

    def rental_income?(tag_name)
      tag_name.to_s.start_with?(RENTAL_INCOME_PREFIX)
    end

    def deduction_tag?(tag_name)
      tag_name.to_s.start_with?(PREFIX) &&
        !property_expense?(tag_name) &&
        !rental_income?(tag_name)
    end
  end
end
