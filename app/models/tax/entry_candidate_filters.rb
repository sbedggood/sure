# frozen_string_literal: true

module Tax
  module EntryCandidateFilters
    def apply_fy_filter(scope, fy_filter)
      return scope if fy_filter.blank? || fy_filter == "all"

      fy = FinancialYear.new(fy_filter.to_i)
      scope.where(date: fy.range)
    end

    def apply_account_filter(scope, account_id)
      return scope if account_id.blank?

      scope.where(account_id: account_id)
    end
  end
end
