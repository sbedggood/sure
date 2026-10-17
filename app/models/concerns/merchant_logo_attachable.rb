# frozen_string_literal: true

module MerchantLogoAttachable
  extend ActiveSupport::Concern

  included do
    has_one_attached :logo, dependent: :purge_later do |attachable|
      attachable.variant :display, resize_to_fill: [ 128, 128 ], convert: :webp, saver: { quality: 85 }, preprocessed: true
    end

    after_commit :enqueue_merchant_logo_cache, on: %i[create update]
  end

  def domain_for_logo_caching
    website_domain.presence || domain_from_brandfetch_logo_url
  end

  def website_domain
    self.class.extract_domain_from_url(website_url) if website_url.present?
  end

  def domain_from_brandfetch_logo_url
    return unless logo_url&.include?("cdn.brandfetch.io/")

    logo_url.match(%r{cdn\.brandfetch\.io/([^/?]+)})&.[](1)
  end

  def remote_logo_url
    return nil unless logo_url.present?

    Setting.transform_brand_fetch_url(logo_url)
  end

  def logo_displayable?
    logo.attached? || remote_logo_url.present?
  end

  def display_logo_path(only_path: true)
    if logo.attached?
      Rails.application.routes.url_helpers.rails_blob_path(logo.variant(:display), only_path: only_path)
    elsif remote_logo_url.present?
      remote_logo_url
    end
  end

  def fallback_logo_color
    respond_to?(:color) && color.present? ? color : nil
  end

  class_methods do
    def extract_domain_from_url(url)
      original_url = url
      normalized_url = url.start_with?("http://", "https://") ? url : "https://#{url}"
      URI.parse(normalized_url).host&.sub(/\Awww\./, "")
    rescue URI::InvalidURIError
      original_url.to_s.sub(/\Awww\./, "")
    end
  end

  private

    def enqueue_merchant_logo_cache
      return unless should_cache_logo?

      CacheMerchantLogoJob.perform_later(id)
    end

    def should_cache_logo?
      return false if logo.attached?
      return false unless logo_url.present? || website_url.present?

      previously_new_record? || saved_change_to_website_url? || saved_change_to_logo_url?
    end
end
