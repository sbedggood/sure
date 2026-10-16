# frozen_string_literal: true

class Assistant::Function::ListTaxDocuments < Assistant::Function
  class << self
    def name
      "list_tax_documents"
    end

    def description
      "Lists tax document metadata for a financial year (not file bytes)."
    end
  end

  def params_schema
    build_schema(
      required: [ "start_year" ],
      properties: {
        start_year: { type: "integer" }
      }
    )
  end

  def call(params = {})
    start_year = params["start_year"].to_i
    docs = user.family.tax_documents.for_year(start_year)
    {
      success: true,
      documents: docs.map { |doc|
        {
          id: doc.id,
          document_type: doc.document_type,
          document_date: doc.document_date&.iso8601,
          note: doc.note,
          filename: doc.file.attached? ? doc.file.filename.to_s : nil
        }
      }
    }
  end
end
