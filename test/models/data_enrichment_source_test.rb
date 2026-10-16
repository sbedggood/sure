# frozen_string_literal: true

require "test_helper"

class DataEnrichmentSourceTest < ActiveSupport::TestCase
  test "commbank_statement is a valid enrichment source" do
    entry = entries(:transaction)

    assert_difference "DataEnrichment.count", 1 do
      entry.enrich_attribute(:notes, "from statement backfill", source: "commbank_statement")
    end

    assert_equal "commbank_statement", entry.data_enrichments.find_by(attribute_name: "notes").source
  end
end
