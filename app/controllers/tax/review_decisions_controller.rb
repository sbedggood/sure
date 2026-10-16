# frozen_string_literal: true

module Tax
  class ReviewDecisionsController < ApplicationController
    include Tax::StartYearFromParams

    def decline
      apply_decision(remove_for_review: true, add_declined: true)
    end

    def accept
      tag = Current.family.tags.find_by(id: params[:tag_id])
      unless tag&.name&.start_with?("Tax:") && !TagCatalog.declined?(tag.name) && !TagCatalog.for_review?(tag.name)
        return redirect_to tax_dashboard_path(start_year: tax_start_year_from_params, section: "deductions"),
          alert: t("tax.deductions.accept_missing_tag")
      end

      apply_decision(remove_for_review: true, add_tag: tag)
    end

    private

      def apply_decision(remove_for_review:, add_declined: false, add_tag: nil)
        entry = Current.accessible_entries.find(params[:entry_id])
        transaction = entry.transaction
        ids = transaction.tag_ids
        review = Current.family.tags.find_by(name: TagCatalog::FOR_REVIEW_TAG)
        declined = Current.family.tags.find_or_create_by!(name: TagCatalog::DECLINED_TAG) do |t|
          t.color = "#6b7280"
        end

        ids -= [ review.id ] if remove_for_review && review
        ids << declined.id if add_declined
        ids << add_tag.id if add_tag
        transaction.update!(tag_ids: ids.uniq)

        redirect_to tax_dashboard_path(start_year: tax_start_year_from_params, section: "deductions"),
          notice: t("tax.deductions.review_updated")
      end
  end
end
