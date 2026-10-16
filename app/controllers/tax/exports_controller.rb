# frozen_string_literal: true

module Tax
  class ExportsController < ApplicationController
    include Tax::StartYearFromParams

    def show
      exporter = Tax::ExcelExporter.new(family: Current.family, start_year: tax_start_year_from_params)
      send_data exporter.package.to_stream.read,
        filename: exporter.filename,
        type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        disposition: "attachment"
    end
  end
end
