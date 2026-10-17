# frozen_string_literal: true

module Tax
  class ReviewDecisionsBulkController < ApplicationController
    include Tax::StartYearFromParams
    include Tax::ReviewTurboStreams

    def create
      entry_ids = Array(params[:entry_ids]).compact_blank
      entries = Current.accessible_entries.where(id: entry_ids).to_a
      decision = ReviewDecisionsBulkController::Decision.new(
        family: Current.family,
        decision: params[:decision],
        tag_id: params[:tag_id]
      )

      ApplicationRecord.transaction do
        entries.each { |entry| decision.apply!(entry) }
      end
    rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid, ArgumentError
      return redirect_to tax_dashboard_path(review_redirect_params),
        alert: t("tax.deductions.accept_missing_tag")
    else
      respond_to do |format|
        format.html do
          redirect_to tax_dashboard_path(review_redirect_params),
            notice: t("tax.deductions.review_updated")
        end
        format.turbo_stream do
          render turbo_stream: review_decision_streams(
            entries: entries,
            start_year: tax_start_year_from_params
          )
        end
      end
    end

    class Decision
      def initialize(family:, decision:, tag_id:)
        @family = family
        @decision = decision.to_s
        @tag_id = tag_id
        @applier = ReviewDecision.new(family: family)
      end

      def apply!(entry)
        case @decision
        when "decline"
          @applier.decline!(entry: entry)
        when "accept"
          tag = @family.tags.find(@tag_id)
          unless tag&.name&.start_with?("Tax:") && !TagCatalog.declined?(tag.name) && !TagCatalog.for_review?(tag.name)
            raise ActiveRecord::RecordInvalid
          end

          @applier.accept!(entry: entry, tag: tag)
        else
          raise ArgumentError, "unknown decision"
        end
      end
    end

    private

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
