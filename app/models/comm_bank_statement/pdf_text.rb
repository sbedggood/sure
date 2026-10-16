# frozen_string_literal: true

require "pdf/reader"

module CommBankStatement
  module PdfText
    module_function

    def extract(path)
      reader = PDF::Reader.new(path)
      reader.pages.map(&:text).join("\n\f\n")
    rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError => e
      raise Parser::ParseError, "Could not read PDF: #{e.message}"
    end
  end
end
