# frozen_string_literal: true

module CommBankStatement
  module PeriodParser
    Period = Data.define(:start_on, :end_on)

    module_function

    def parse(text)
      patterns = [
        /(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})\s*(?:to|–|-)\s*(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})/i,
        /Statement\s+Period\s+(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})\s*(?:to|-)\s*(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})/i,
        /Statement period\s+(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})\s*(?:to|-)\s*(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})/i,
        /Statement period\s+(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})\s+(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})/i
      ]

      patterns.each do |pattern|
        match = text.match(pattern)
        next unless match

        return Period.new(
          start_on: parse_date(match[1]),
          end_on: parse_date(match[2])
        )
      end

      nil
    end

    def parse_date(token)
      Date.strptime(token, "%d %b %Y")
    rescue ArgumentError
      Date.strptime(token, "%e %b %Y")
    end
  end
end
