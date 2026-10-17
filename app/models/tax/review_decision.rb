# frozen_string_literal: true

module Tax
  class ReviewDecision
    def initialize(family:)
      @family = family
    end

    def decline!(entry:)
      apply!(entry, remove_for_review: true, add_declined: true)
    end

    def accept!(entry:, tag:)
      apply!(entry, remove_for_review: true, add_tag: tag)
    end

    def apply!(entry, remove_for_review:, add_declined: false, add_tag: nil)
      transaction = entry.transaction
      ids = transaction.tag_ids
      review = @family.tags.find_by(name: TagCatalog::FOR_REVIEW_TAG)
      declined = @family.tags.find_or_create_by!(name: TagCatalog::DECLINED_TAG) do |tag|
        tag.color = "#6b7280"
      end

      ids -= [ review.id ] if remove_for_review && review
      ids << declined.id if add_declined
      ids << add_tag.id if add_tag
      transaction.update!(tag_ids: ids.uniq)
    end
  end
end
