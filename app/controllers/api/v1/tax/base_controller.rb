# frozen_string_literal: true

class Api::V1::Tax::BaseController < Api::V1::BaseController
  include Tax::StartYearFromParams

  private

    def tax_start_year
      tax_start_year_from_params
    end
end
