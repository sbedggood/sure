# frozen_string_literal: true

module MerchantsHelper
  def merchant_logo(merchant, size: :lg, class_name: nil)
    render MerchantLogo.new(merchant: merchant, size: size, class_name: class_name)
  end
end
