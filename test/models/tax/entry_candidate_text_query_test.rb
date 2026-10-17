# frozen_string_literal: true

require "test_helper"

class Tax::EntryCandidateTextQueryTest < ActiveSupport::TestCase
  test "matches amount prefix with formatting variants" do
    entry = Entry.new(amount: BigDecimal("13041.00"))

    assert Tax::EntryCandidateTextQuery.matches_amount_prefix?(entry, "13041")
    assert Tax::EntryCandidateTextQuery.matches_amount_prefix?(entry, "13,041")
    assert Tax::EntryCandidateTextQuery.matches_amount_prefix?(entry, "$13041.00")
    refute Tax::EntryCandidateTextQuery.matches_amount_prefix?(entry, "13042")
  end
end
