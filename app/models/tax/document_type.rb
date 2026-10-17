# frozen_string_literal: true

module Tax
  class DocumentType
    PAYSLIP_TAG = "Tax: Payslip"

    def self.infer_from_tag_names(tag_names)
      names = tag_names.map(&:to_s)
      return "payslip" if names.include?(PAYSLIP_TAG)
      return "statement" if names.any? { |name| name.match?(/statement/i) }

      "receipt"
    end

    def self.ensure_tags_for!(family:, transaction:, document_type:)
      tag = tag_for_document_type(family: family, document_type: document_type)
      return unless tag

      transaction.update!(tag_ids: (transaction.tag_ids + [ tag.id ]).uniq)
    end

    def self.tag_for_document_type(family:, document_type:)
      case document_type.to_s
      when "payslip"
        family.tags.find_or_create_by!(name: PAYSLIP_TAG) do |record|
          record.color = "#6471eb"
        end
      else
        nil
      end
    end
  end
end
