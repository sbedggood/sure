# frozen_string_literal: true

module Tax
  class DashboardController < ApplicationController
    include Tax::StartYearFromParams

    before_action :set_financial_year
    before_action :set_settings
    before_action :set_breadcrumbs

    def show
      @section = params[:section].presence || "calendar"
      @summary = Tax::Summary.new(family: Current.family, start_year: @financial_year.start_year)
      @weeks = build_calendar_weeks
      @fy_options = financial_year_options
      @deductions = Tax::DeductionsPresenter.new(family: Current.family, start_year: @financial_year.start_year)
      @property_grid = Tax::PropertyGrid.new(family: Current.family, start_year: @financial_year.start_year)
      @document_catalog = Tax::DocumentCatalog.new(family: Current.family)
      @doc_scope = params[:doc_scope].presence || "fy"
      @doc_type = params[:doc_type].presence || "all"
      @documents = @doc_scope == "all" ? @document_catalog.all_rows : @document_catalog.rows_for_fy(@financial_year.start_year)
      @section = "calendar" unless valid_section?(@section)
    end

    private

      def set_breadcrumbs
        @breadcrumbs = [
          [ I18n.t("breadcrumbs.home"), root_path ],
          [ I18n.t("breadcrumbs.tax"), nil ]
        ]
      end

      def set_financial_year
        @financial_year = Tax::FinancialYear.new(tax_start_year_from_params)
      end

      def set_settings
        @settings = TaxFySetting.find_or_initialize_for!(family: Current.family, start_year: @financial_year.start_year)
        @settings.save! if @settings.new_record?
      end

      def build_calendar_weeks
        entries = Current.family.tax_weekly_calendar_entries
          .for_year(@financial_year.start_year)
          .index_by(&:week_commencing)

        @financial_year.week_commencing_dates.map do |week|
          entries[week] || TaxWeeklyCalendarEntry.new(
            family: Current.family,
            start_year: @financial_year.start_year,
            week_commencing: week
          )
        end
      end

      def valid_section?(section)
        %w[calendar property deductions documents].include?(section)
      end

      def financial_year_options
        current = Tax::FinancialYear.current_start_year
        (current - 5..current).map do |year|
          fy = Tax::FinancialYear.new(year)
          [ "#{fy.label} (#{fy.start_on.year}–#{fy.end_on.year})", year ]
        end.reverse
      end
  end
end
