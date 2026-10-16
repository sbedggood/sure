# frozen_string_literal: true

class Assistant::Function::ListTaxDocuments < Assistant::Function
  class << self
    def name
      "list_tax_documents"
    end

    def description
      <<~DESC.squish
        Lists tax document metadata for a financial year (not file bytes).
        Use start_year (July year) or fy (ATO end year, e.g. 25 for FY25).
      DESC
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      properties: {
        start_year: { type: "integer", description: "July-start year (e.g. 2024 for FY25)." },
        fy: { type: [ "integer", "string" ], description: "ATO end year (e.g. 25 or 2025)." }
      }
    )
  end

  def call(params = {})
    start_year = Tax::YearParams.resolve_from_tool_params(params)
    return error("invalid_year", "Provide start_year or fy.") unless start_year

    docs = user.family.tax_documents.for_year(start_year)
    fy = Tax::FinancialYear.new(start_year)
    {
      success: true,
      label: fy.label,
      start_year: start_year,
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
