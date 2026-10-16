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
    FOR_REVIEW_TAG = "Tax: For Review"
    DONATIONS_TAG = "Tax: Donations"
    AGENT_FEES_TAG = "Tax: Agent Fees"
    PROPERTY_PREFIX = "Tax: Property - "

    module_function

    def property_expense?(tag_name)
      PROPERTY_EXPENSE_TAGS.include?(tag_name)
    end

    def property_prefixed?(tag_name)
      tag_name.to_s.start_with?(PROPERTY_PREFIX)
    end

    def rental_income?(tag_name)
      tag_name.to_s.start_with?(RENTAL_INCOME_PREFIX)
    end

    def for_review?(tag_name)
      tag_name.to_s == FOR_REVIEW_TAG
    end

    def deduction_tag?(tag_name)
      tag_name.to_s.start_with?(PREFIX) &&
        !property_prefixed?(tag_name) &&
        !rental_income?(tag_name) &&
        !for_review?(tag_name)
    end

    def deduction_group_tag?(tag_name)
      deduction_tag?(tag_name) || for_review?(tag_name)
    end
  end
end
