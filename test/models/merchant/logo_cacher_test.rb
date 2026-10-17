# frozen_string_literal: true

require "test_helper"

class Merchant::LogoCacherTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    Setting.stubs(:brand_fetch_client_id).returns("test-client-id")
    Setting.stubs(:brand_fetch_logo_size).returns(40)
    @png = file_fixture("square-placeholder.png").read
  end

  test "downloads and attaches logo from brandfetch url" do
    merchant = FamilyMerchant.create!(family: @family, name: "Acme", website_url: "https://acme.com")
    brandfetch_url = Setting.transform_brand_fetch_url(merchant.logo_url)

    stub_request(:get, brandfetch_url).to_return(
      status: 200,
      body: @png,
      headers: { "Content-Type" => "image/png" }
    )

    result = Merchant::LogoCacher.cache!(merchant)

    assert_equal :cached, result.status, -> { "#{brandfetch_url} -> #{result.message}" }
    assert merchant.reload.logo.attached?
    assert_equal :skipped_attached, Merchant::LogoCacher.cache!(merchant).status
  end

  test "falls back to ntropy when brandfetch fails" do
    merchant = FamilyMerchant.create!(family: @family, name: "Acme", website_url: "https://acme.com")
    brandfetch_url = Setting.transform_brand_fetch_url(merchant.logo_url)
    ntropy_url = "https://logos.ntropy.com/acme.com"

    stub_request(:get, brandfetch_url).to_return(status: 404, body: "missing")
    stub_request(:get, ntropy_url).to_return(
      status: 200,
      body: @png,
      headers: { "Content-Type" => "image/png" }
    )

    result = Merchant::LogoCacher.cache!(merchant)

    assert_equal :cached, result.status
    assert merchant.reload.logo.attached?
  end

  test "dry run does not attach" do
    merchant = FamilyMerchant.create!(family: @family, name: "Dry", website_url: "https://dry.example")
    brandfetch_url = Setting.transform_brand_fetch_url(merchant.logo_url)
    stub_request(:get, brandfetch_url).to_return(
      status: 200,
      body: @png,
      headers: { "Content-Type" => "image/png" }
    )

    result = Merchant::LogoCacher.cache!(merchant, dry_run: true)

    assert_equal :dry_run, result.status
    refute merchant.reload.logo.attached?
  end

  test "rejects non-image responses" do
    merchant = FamilyMerchant.create!(family: @family, name: "Html", website_url: "https://html.example")
    brandfetch_url = Setting.transform_brand_fetch_url(merchant.logo_url)
    stub_request(:get, brandfetch_url).to_return(
      status: 200,
      body: "<html></html>",
      headers: { "Content-Type" => "text/html" }
    )
    stub_request(:get, "https://logos.ntropy.com/html.example").to_return(status: 404, body: "")

    result = Merchant::LogoCacher.cache!(merchant)

    assert_equal :failed, result.status
    refute merchant.reload.logo.attached?
  end
end
