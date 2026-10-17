# frozen_string_literal: true

require "test_helper"

class MerchantLogoAttachableTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @family = families(:dylan_family)
    Setting.stubs(:brand_fetch_client_id).returns("test-client-id")
    Setting.stubs(:brand_fetch_logo_size).returns(40)
  end

  test "enqueues logo cache job when merchant is created with website" do
    assert_enqueued_with(job: CacheMerchantLogoJob) do
      FamilyMerchant.create!(family: @family, name: "Queued", website_url: "https://queued.example")
    end
  end

  test "enqueues logo cache job when website changes" do
    merchant = FamilyMerchant.create!(family: @family, name: "Update Me")
    clear_enqueued_jobs

    assert_enqueued_with(job: CacheMerchantLogoJob) do
      merchant.update!(website_url: "https://updated.example")
    end
  end

  test "does not set brandfetch logo_url when client id is blank" do
    Setting.stubs(:brand_fetch_client_id).returns(nil)

    merchant = FamilyMerchant.create!(family: @family, name: "No Brandfetch", website_url: "https://example.com")

    assert_nil merchant.logo_url
  end
end
