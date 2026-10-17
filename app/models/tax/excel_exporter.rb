# frozen_string_literal: true

require "caxlsx"

module Tax
  class ExcelExporter
    def initialize(family:, start_year:)
      @family = family
      @summary = Summary.new(family: family, start_year: start_year)
      @fy = @summary.financial_year
      @settings = @summary.settings
    end

    def package
      package = Axlsx::Package.new
      workbook = package.workbook
      bold = workbook.styles.add_style(b: true)

      add_property_sheet(workbook, bold)
      add_summary_sheet(workbook, bold)
      add_expenses_sheet(workbook, bold)
      add_calendar_sheet(workbook, bold)

      package
    end

    def filename
      "#{@fy.label}_tax_export.xlsx"
    end

    private

      def add_property_sheet(workbook, bold)
        property = @summary.as_json[:property]
        months = property[:months].map { |iso| Date.iso8601(iso).strftime("%b %y") }

        workbook.add_worksheet(name: "Property #{@fy.label}") do |sheet|
          sheet.add_row([ "Line" ] + months + [ "Total" ], style: bold)
          property[:expense_rows].each do |row|
            values = months.each_with_index.map do |_label, idx|
              month_key = property[:months][idx]
              row[:months][month_key]
            end
            sheet.add_row([ row[:label] ] + values + [ row[:total] ])
          end

          sheet.add_row([ "Total" ] + Array.new(months.length, nil) + [ property[:cost_total] ], style: bold)
          sheet.add_row([])
          sheet.add_row([ "% allocation", property[:property_allocation_percent] ])
          sheet.add_row([ "Allocated costs", property[:allocated_costs] ])
          sheet.add_row([ "Rent", property[:rental_income][:total] ])
          sheet.add_row([ "Difference", property[:difference] ])
          sheet.add_row([ "Expected return", property[:expected_return] ])
        end
      end

      def add_summary_sheet(workbook, bold)
        deductions = @summary.as_json[:deductions]

        workbook.add_worksheet(name: @fy.label) do |sheet|
          sheet.add_row([ "ATO line", "Description", "Amount", "%", "Claim" ], style: bold)
          sheet.add_row([
            "D1",
            "Car",
            deductions[:car][:km_total],
            deductions[:car][:rate_per_km],
            deductions[:car][:claim]
          ])
          sheet.add_row([
            "D5",
            "Home office",
            deductions[:home_office][:wfh_hours_total],
            deductions[:home_office][:hourly_rate],
            deductions[:home_office][:claim]
          ])

          deductions[:tag_lines].each do |line|
            sheet.add_row([ "Other", line[:tag], line[:amount], line[:business_use_percent], line[:claim] ])
          end

          sheet.add_row([
            "D9",
            "Donations",
            deductions[:donations][:amount],
            deductions[:donations][:business_use_percent],
            deductions[:donations][:claim]
          ])
          sheet.add_row([
            "D10",
            "Agent fees",
            deductions[:agent_fees][:amount],
            deductions[:agent_fees][:business_use_percent],
            deductions[:agent_fees][:claim]
          ])
          sheet.add_row([])
          sheet.add_row([ "Grand total", nil, nil, nil, deductions[:grand_total] ], style: bold)
        end
      end

      def add_expenses_sheet(workbook, bold)
        workbook.add_worksheet(name: "Expenses #{@fy.label}") do |sheet|
          sheet.add_row(%w[Date Merchant Description Amount % Claim], style: bold)
          @summary.as_json[:deductions][:tag_lines].each do |line|
            line[:transactions].each do |txn|
              claim = txn[:amount] * line[:business_use_percent] / 100.0
              sheet.add_row([
                txn[:date],
                txn[:account_name],
                txn[:name],
                txn[:amount],
                line[:business_use_percent],
                claim
              ])
            end
          end
        end
      end

      def add_calendar_sheet(workbook, bold)
        entries = @family.tax_weekly_calendar_entries.for_year(@fy.start_year)
        totals = @summary.as_json[:calendar_totals]

        workbook.add_worksheet(name: "#{@fy.label} Calendar") do |sheet|
          sheet.add_row(%w[Week\ Commencing WFH\ hours km note], style: bold)
          entries.each do |entry|
            sheet.add_row([ entry.week_commencing, entry.wfh_hours, entry.km_driven, entry.note ])
          end
          sheet.add_row([])
          sheet.add_row([ "Totals", totals[:wfh_hours_total], totals[:km_total], nil ], style: bold)
        end
      end
  end
end
