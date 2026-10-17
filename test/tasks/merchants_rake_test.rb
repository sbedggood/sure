# frozen_string_literal: true

require "test_helper"

RakeTaskTestHelper.load_task("merchants:cache_logos", "merchants")

class MerchantsRakeTest < ActiveSupport::TestCase
  setup do
    RakeTaskTestHelper.prepare("merchants:cache_logos")
    @family = families(:dylan_family)
    Setting.stubs(:brand_fetch_client_id).returns("test-client-id")
    Setting.stubs(:brand_fetch_logo_size).returns(40)
    @png = file_fixture("square-placeholder.png").read
  end

  test "cache_logos task reports counts" do
    merchant = FamilyMerchant.create!(family: @family, name: "Rake Acme", website_url: "https://rake-acme.com")
    stub_request(:get, Setting.transform_brand_fetch_url(merchant.logo_url)).to_return(
      status: 200,
      body: @png,
      headers: { "Content-Type" => "image/png" }
    )

    output = capture_io do
      Rake::Task["merchants:cache_logos"].invoke
    end.join

    assert_includes output, "cached: 1"
    assert merchant.reload.logo.attached?
  end
end
