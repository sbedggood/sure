# frozen_string_literal: true

class Api::V1::Tax::SummariesController < Api::V1::Tax::BaseController
  before_action -> { authorize_scope!(:read) }

  def show
    summary = Tax::Summary.new(family: family, start_year: tax_start_year)
    render json: summary.as_json
  end

  private

    def family
      current_resource_owner.family
    end
end
