# frozen_string_literal: true

module Tax
  class PropertyCellsController < ApplicationController
    include Tax::StartYearFromParams

    before_action :set_grid

    def show
      @tag_name = params.require(:tag_name)
      @month = Date.iso8601(params.require(:month))
      @candidate_query = params[:q]
      @entries = @grid.entries_for_tag_month(@tag_name, @month)
      candidates = @grid.candidate_entries(tag_name: @tag_name, month: @month, query: @candidate_query)
      ranked = Tax::PropertyCellMatcher.new(linked_entries: @entries, month: @month).rank(candidates)
      @ranked_candidates = ranked.map { |c| [ c.entry, c.signals ] }
      ranked_ids = ranked.map { |c| c.entry.id }
      @other_entries = candidates.reject { |e| ranked_ids.include?(e.id) }.first(30)
      render layout: false
    end

    def link
      entry = Current.accessible_entries.find(params[:entry_id])
      tag = Current.family.tags.find_by!(name: params[:tag_name])
      transaction = entry.transaction
      transaction.update!(tag_ids: (transaction.tag_ids + [ tag.id ]).uniq)

      redirect_to tax_property_cell_path(
        tag_name: params[:tag_name],
        month: params[:month],
        start_year: tax_start_year_from_params,
        fy: params[:fy]
      ), notice: t("tax.property.linked")
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
        fy: params[:fy]
      ), notice: t("tax.property.unlinked")
    end

    private

      def set_grid
        @grid = Tax::PropertyGrid.new(family: Current.family, start_year: tax_start_year_from_params)
        @financial_year = @grid.financial_year
      end
  end
end
