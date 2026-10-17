# frozen_string_literal: true

module Tax
  class DeductionBulkTagsController < ApplicationController
    include Tax::StartYearFromParams

    def create
      entry_ids = Array(params[:entry_ids]).reject(&:blank?)
      entries = Current.accessible_entries.where(id: entry_ids)

      add_tag = Current.family.tags.find_by(id: params[:add_tag_id])
      remove_tag = Current.family.tags.find_by(id: params[:remove_tag_id])
      replace_tag = Current.family.tags.find_by(id: params[:replace_tag_id])
      new_tag = Current.family.tags.find_by(id: params[:new_tag_id])

      Entry.transaction do
        entries.find_each do |entry|
          next unless entry.entryable.is_a?(Transaction)

          transaction = entry.transaction
          ids = transaction.tag_ids
          ids -= [ remove_tag.id ] if remove_tag
          if replace_tag && new_tag
            ids -= [ replace_tag.id ]
            ids << new_tag.id
          end
          ids << add_tag.id if add_tag
          transaction.update!(tag_ids: ids.uniq)
        end
      end

      redirect_to tax_dashboard_path(start_year: tax_start_year_from_params, section: "deductions"),
        notice: t("tax.deductions.bulk_updated")
    end
  end
end
