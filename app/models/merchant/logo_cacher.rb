# frozen_string_literal: true

class Merchant
  class LogoCacher
    MAX_BYTES = 2.megabytes
    ALLOWED_CONTENT_TYPES = %w[image/png image/jpeg image/jpg image/gif image/webp image/svg+xml].freeze

    Result = Data.define(:status, :message)

    def self.cache!(merchant, dry_run: false)
      new(merchant, dry_run: dry_run).cache!
    end

    def initialize(merchant, dry_run: false)
      @merchant = merchant
      @dry_run = dry_run
    end

    def cache!
      return Result.new(status: :skipped_attached, message: "logo already attached") if @merchant.logo.attached?
      return Result.new(status: :skipped_no_source, message: "no logo source") if source_urls.empty?

      source_urls.each do |url|
        downloaded = download(url)
        next unless downloaded

        body, content_type = downloaded
        return Result.new(status: :dry_run, message: url) if @dry_run

        attach_logo!(body, content_type)
        return Result.new(status: :cached, message: url)
      end

      Result.new(status: :failed, message: "download failed for all sources")
    end

    def source_urls
      urls = []
      if @merchant.logo_url.present?
        urls << Setting.transform_brand_fetch_url(@merchant.logo_url)
      end

      domain = @merchant.domain_for_logo_caching
      urls << "https://logos.ntropy.com/#{domain}" if domain.present?

      urls.compact.uniq
    end

    private

      def download(url)
        uri = URI.parse(url)
        response = Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: 5,
          read_timeout: 15
        ) { |http| http.get(uri.request_uri) }

        return nil unless response.is_a?(Net::HTTPSuccess)

        body = response.body.to_s.b
        return nil if body.blank? || body.bytesize > MAX_BYTES

        content_type = response["Content-Type"]&.split(";")&.first&.strip&.downcase
        return nil unless content_type.in?(ALLOWED_CONTENT_TYPES)

        [ body, content_type ]
      rescue StandardError => e
        Rails.logger.info("Merchant logo download failed merchant_id=#{@merchant.id} url=#{url} error=#{e.class}: #{e.message}")
        nil
      end

      def attach_logo!(body, content_type)
        extension = Rack::Mime::MIME_TYPES.invert[content_type] || ".png"
        filename = "logo#{extension}"

        @merchant.logo.attach(
          io: StringIO.new(body),
          filename: filename,
          content_type: content_type
        )
      end
  end
end
