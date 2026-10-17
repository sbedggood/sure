# frozen_string_literal: true

class AddEntryIdToTaxDocuments < ActiveRecord::Migration[8.1]
  def change
    return if column_exists?(:tax_documents, :entry_id)

    add_reference :tax_documents, :entry, type: :uuid, foreign_key: true, null: true
  end
end
