# frozen_string_literal: true

module Tax
  module McpTools
    NAMES = %w[
      get_tax_summary
      upsert_tax_calendar
      list_tax_documents
    ].freeze

    module_function

    def registered?(assistant_function_classes)
      NAMES.all? { |name| assistant_function_classes.any? { |klass| klass.name == name } }
    end
  end
end
