# frozen_string_literal: true

require "pdf/reader"
require "open3"

module CommBankStatement
  module PdfText
    module_function

    def extract(path)
      layout = extract_with_pdftotext(path)
      return TextNormalizer.normalize(layout) if layout.present?

      reader = PDF::Reader.new(path)
      raw = reader.pages.map(&:text).join("\n\f\n")
      TextNormalizer.normalize(raw)
    rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError => e
      raise Parser::ParseError, "Could not read PDF: #{e.message}"
    end

    def extract_with_pdftotext(path)
      return nil unless pdftotext_available?

      stdout, status = Open3.capture2("pdftotext", "-layout", "-nopgbrk", path.to_s, "-")
      return nil unless status.success? && stdout.present?

      stdout
    rescue Errno::ENOENT
      nil
    end

    def pdftotext_available?
      @pdftotext_available = system("which pdftotext > /dev/null 2>&1") if @pdftotext_available.nil?
      @pdftotext_available
    end
  end
end
