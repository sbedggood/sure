# frozen_string_literal: true

module Tax
  module ReviewTurboStreams
    extend ActiveSupport::Concern
    include ActionView::RecordIdentifier

    private

      def deductions_presenter_for_review(start_year)
        sort, direction = Tax::SortParams.parse(
          sort: params[:sort],
          direction: params[:direction],
          allowed: EntrySorter::COLUMNS
        )
        Tax::DeductionsPresenter.new(
          family: Current.family,
          start_year: start_year.to_i,
          sort: sort,
          direction: direction
        )
      end

      def review_decision_streams(entries:, start_year:)
        deductions = deductions_presenter_for_review(start_year)
        financial_year = Tax::FinancialYear.new(start_year.to_i)
        sort, direction = Tax::SortParams.parse(
          sort: params[:sort],
          direction: params[:direction],
          allowed: EntrySorter::COLUMNS
        )

        streams = Array(entries).map do |entry|
          turbo_stream.remove(dom_id(entry, :tax_review_row))
        end

        streams << turbo_stream.replace(
          "tax-deductions-pending-review",
          partial: "tax/dashboard/pending_review_totals",
          locals: { deductions: deductions }
        )
        streams << turbo_stream.replace(
          "tax-summary-pending-review",
          partial: "tax/dashboard/summary_pending_review",
          locals: { deductions: deductions }
        )

        group = deductions.for_review_group
        if group&.entries&.any?
          streams << turbo_stream.replace(
            "tax-for-review-meta",
            partial: "tax/dashboard/for_review_meta",
            locals: { group: group }
          )
        else
          streams << turbo_stream.replace(
            "tax-for-review-panel",
            partial: "tax/dashboard/for_review_panel",
            locals: {
              financial_year: financial_year,
              settings: settings,
              deductions: deductions,
              sort: sort,
              direction: direction
            }
          )
        end

        streams
      end
  end
end
