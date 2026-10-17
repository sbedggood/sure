# frozen_string_literal: true

class CacheMerchantLogoJob < ApplicationJob
  queue_as :default

  def perform(merchant_id)
    merchant = Merchant.find_by(id: merchant_id)
    return unless merchant

    Merchant::LogoCacher.cache!(merchant)
  end
end
