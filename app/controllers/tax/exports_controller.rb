# frozen_string_literal: true

module Tax
  class ExportsController < ApplicationController
    def show
      start_year = params.require(:start_year).to_i
      exporter = Tax::ExcelExporter.new(family: Current.family, start_year: start_year)
      send_data exporter.package.to_stream.read,
        filename: exporter.filename,
        type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        disposition: "attachment"
    end
  end
end
