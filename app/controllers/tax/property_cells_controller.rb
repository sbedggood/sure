# frozen_string_literal: true

module Tax
  class PropertyCellsController < ApplicationController
    include Tax::StartYearFromParams

    before_action :set_grid
    before_action :set_cell_context

    def show
      load_search_results
      @suggested_entries = @search.suggestions(linked_entries: @entries)
      render layout: false
    end

    def link
      link_entries([ params[:entry_id] ])
      redirect_after_link
    end

    def link_bulk
      link_entries(Array(params[:entry_ids]))
      redirect_after_link
    end

    def unlink
      entry = Current.accessible_entries.find(params[:entry_id])
      tag = Current.family.tags.find_by!(name: params[:tag_name])
      transaction = entry.transaction
      transaction.update!(tag_ids: transaction.tag_ids - [ tag.id ])

      redirect_to tax_property_cell_path(
        tag_name: params[:tag_name],
        month: params[:month],
        start_year: tax_start_year_from_params,
        fy: params[:fy],
        q: params[:q],
        account_id: params[:account_id]
      ), notice: t("tax.property.unlinked")
    end

    private

      def set_grid
        @grid = Tax::PropertyGrid.new(family: Current.family, start_year: tax_start_year_from_params)
        @financial_year = @grid.financial_year
      end

      def set_cell_context
        @tag_name = params.require(:tag_name)
        @month = Date.iso8601(params.require(:month))
        @candidate_query = params[:q]
        @fy_filter = if params.key?(:fy)
          params[:fy].presence || "all"
        else
          @financial_year.start_year.to_s
        end
        @account_id = params[:account_id].presence
        @entries = @grid.entries_for_tag_month(@tag_name, @month)
        @search = PropertyCellSearch.new(
          family: Current.family,
          tag_name: @tag_name,
          month: @month,
          start_year: @financial_year.start_year,
          linked_entry_ids: @entries.map(&:id)
        )
        @fy_options = financial_year_options
        @account_options = Current.family.accounts.visible.alphabetically
      end

      def load_search_results
        @search_results = @search.results(
          query: @candidate_query,
          fy_filter: @fy_filter,
          account_id: @account_id
        )
      end

      def link_entries(entry_ids)
        tag = Current.family.tags.find_by!(name: params[:tag_name])
        entry_ids.compact_blank.each do |entry_id|
          entry = Current.accessible_entries.find(entry_id)
          transaction = entry.transaction
          transaction.update!(tag_ids: (transaction.tag_ids + [ tag.id ]).uniq)
        end
      end

      def redirect_after_link
        redirect_to tax_property_cell_path(
          tag_name: params[:tag_name],
          month: params[:month],
          start_year: tax_start_year_from_params,
          fy: params[:fy],
          q: params[:q],
          account_id: params[:account_id]
        ), notice: t("tax.property.linked")
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
