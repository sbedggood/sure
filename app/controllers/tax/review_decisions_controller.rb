# frozen_string_literal: true

module Tax
  class ReviewDecisionsController < ApplicationController
    include Tax::StartYearFromParams
    include Tax::ReviewTurboStreams

    def decline
      entry = Current.accessible_entries.find(params[:entry_id])
      ReviewDecision.new(family: Current.family).decline!(entry: entry)
      respond_after_decision(entry)
    end

    def accept
      entry = Current.accessible_entries.find(params[:entry_id])
      tag = Current.family.tags.find_by(id: params[:tag_id])
      unless tag&.name&.start_with?("Tax:") && !TagCatalog.declined?(tag.name) && !TagCatalog.for_review?(tag.name)
        return redirect_to tax_dashboard_path(review_redirect_params),
          alert: t("tax.deductions.accept_missing_tag")
      end

      ReviewDecision.new(family: Current.family).accept!(entry: entry, tag: tag)
      respond_after_decision(entry)
    end

    private

      def respond_after_decision(entry)
        respond_to do |format|
          format.html do
            redirect_to tax_dashboard_path(review_redirect_params),
              notice: t("tax.deductions.review_updated")
          end
          format.turbo_stream do
            render turbo_stream: review_decision_streams(
              entries: [ entry ],
              start_year: tax_start_year_from_params
            )
          end
        end
      end

      def review_redirect_params
        {
          start_year: tax_start_year_from_params,
          section: "deductions",
          sort: params[:sort],
          direction: params[:direction]
        }.compact
      end
  end
end
