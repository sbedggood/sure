# frozen_string_literal: true

module CommBankStatement
  class SkippedDocument < StandardError
    attr_reader :reason

    def initialize(reason)
      @reason = reason
      super("Skipped: #{reason}")
    end
  end
end
