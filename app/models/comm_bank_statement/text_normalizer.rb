# frozen_string_literal: true

module CommBankStatement
  module TextNormalizer
    module_function

    PAGE_MARKER_RE = /^===== PAGE \d+ =====/
    MARGIN_NOISE_RE = /\A[\d\.\sVLHSZC\*#O\-]+\z/i
    BARCODE_LINE_RE = /ZZ\d{3}|SL\.(HL|CC|DH)\.|SL\.DH\.|SL\.CC\./i
    TABLE_HEADER_RE = /Date\s+Transaction/i

    def normalize(text)
      lines = text.to_s.gsub(/\f/, "\n").lines.map(&:rstrip)
      lines = lines.reject { |line| PAGE_MARKER_RE.match?(line.strip) }
      lines = lines.reject { |line| margin_noise_line?(line) }
      lines.join("\n")
    end

    def margin_noise_line?(line)
      stripped = line.strip
      return true if stripped.empty?
      return true if barcode_line?(line)

      stripped.length <= 6 && MARGIN_NOISE_RE.match?(stripped)
    end

    def barcode_line?(line)
      line.to_s.match?(BARCODE_LINE_RE)
    end

    def transaction_table_lines(text)
      normalized = normalize(text)
      lines = normalized.lines.map(&:rstrip)
      collected = []
      in_table = false

      lines.each do |line|
        if table_header_line?(line)
          in_table = true
          next
        end

        next unless in_table

        if table_footer_line?(line)
          in_table = false
          next
        end

        collected << line unless skip_within_table_line?(line)
      end

      collected
    end

    def table_header_line?(line)
      line.match?(/Date\s+Transaction.*(?:Debit|Debits).*(?:Credit|Credits).*Balance/i) ||
        line.match?(/Date\s+Transaction\s+Debit\s+Credit\s+Balance/i)
    end

    def table_footer_line?(line)
      line.match?(/Opening balance\s+-\s+Total debits/i) ||
        line.match?(/^Important Information:/i) ||
        line.match?(/^Important Notice:/i) ||
        line.match?(/^How to pay/i)
    end

    def skip_within_table_line?(line)
      stripped = line.strip
      stripped.empty? ||
        stripped.match?(/^Statement \d+/i) ||
        stripped.match?(/^Account Number/i) ||
        stripped.match?(/^Statement period/i) ||
        stripped.match?(/^Interest rate as of/i) ||
        stripped.match?(/^0\.000% interest rate per annum/i) ||
        stripped.match?(/^to amount held in any linked Everyday Offset/i)
    end
  end
end
