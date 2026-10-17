# frozen_string_literal: true

class MerchantLogo < ApplicationComponent
  REMOVE_ON_ERROR = "this.remove()".freeze

  SIZES = {
    xs: { container: "w-5 h-5", icon: "sm", rounded: true },
    sm: { container: "w-8 h-8", icon: "md", rounded: true },
    lg: { container: "w-9 h-9", icon: "lg", rounded: true }
  }.freeze

  def initialize(merchant:, size: :lg, class_name: nil)
    @merchant = merchant
    @size = size.to_sym
    @class_name = class_name
  end

  attr_reader :merchant, :size, :class_name

  def container_class
    class_names(
      "relative block overflow-hidden shrink-0",
      size_config[:container],
      class_name
    )
  end

  def image_class
    class_names("absolute inset-0 w-full h-full object-cover bg-container", rounded_class)
  end

  def rounded_class
    size_config[:rounded] ? "rounded-full" : "rounded-lg"
  end

  def remote_url
    return helpers.url_for(merchant.logo.variant(:display)) if merchant.logo.attached?
    merchant.remote_logo_url
  end

  def size_config
    SIZES.fetch(size)
  end
end
