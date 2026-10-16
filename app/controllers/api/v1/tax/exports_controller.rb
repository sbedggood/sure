# frozen_string_literal: true

class Api::V1::Tax::ExportsController < Api::V1::BaseController
  before_action -> { authorize_scope!(:read) }

  def show
    exporter = Tax::ExcelExporter.new(family: family, start_year: params[:start_year])
    send_data exporter.package.to_stream.read,
      filename: exporter.filename,
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      disposition: "attachment"
  end

  private

    def family
      current_resource_owner.family
    end
end
