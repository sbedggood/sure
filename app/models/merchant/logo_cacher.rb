# frozen_string_literal: true

class Merchant
  class LogoCacher
    MAX_BYTES = 2.megabytes
    MAX_REDIRECTS = 3
    ALLOWED_CONTENT_TYPES = %w[image/png image/jpeg image/jpg image/svg+xml image/webp].freeze
    USER_AGENT = "Mozilla/5.0 (compatible; Sure/1.0; +https://sure.am)"

    Result = Data.define(:status, :message)

    def self.cache!(merchant, dry_run: false)
      new(merchant, dry_run: dry_run).cache!
    end

    def self.app_referer
      configured = ENV["APP_DOMAIN"].presence || "http://localhost:3000"
      configured.start_with?("http") ? configured : "https://#{configured}"
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

      def download(initial_url)
        uri = URI.parse(initial_url)
        headers = request_headers_for(initial_url)
        redirects = 0

        loop do
          response = http_get(uri, headers)

          if response.is_a?(Net::HTTPRedirection)
            redirects += 1
            return nil if redirects > MAX_REDIRECTS

            location = response["location"]
            return nil if location.blank?

            uri = URI.join(uri.to_s, location)
            return nil if unacceptable_redirect_target?(uri)

            next
          end

          return nil unless response.is_a?(Net::HTTPSuccess)

          body = response.body.to_s.b
          return nil if body.blank? || body.bytesize > MAX_BYTES

          content_type = response["Content-Type"]&.split(";")&.first&.strip&.downcase
          return nil unless content_type.in?(ALLOWED_CONTENT_TYPES)

          return [ body, content_type ]
        end
      rescue StandardError => e
        Rails.logger.info("Merchant logo download failed merchant_id=#{@merchant.id} url=#{initial_url} error=#{e.class}: #{e.message}")
        nil
      end

      def http_get(uri, headers)
        Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: 5,
          read_timeout: 15
        ) do |http|
          request = Net::HTTP::Get.new(uri.request_uri, headers)
          http.request(request)
        end
      end

      def request_headers_for(url)
        headers = {
          "User-Agent" => USER_AGENT,
          "Accept" => "image/webp,image/png,image/svg+xml,image/jpeg,*/*;q=0.8"
        }

        if url.include?("cdn.brandfetch.io")
          headers["Referer"] = "#{self.class.app_referer}/"
        end

        headers
      end

      def unacceptable_redirect_target?(uri)
        host = uri.host.to_s.downcase
        path = uri.path.to_s.downcase

        return true if host.include?("docs.")
        return true if path.start_with?("/docs")
        return true if path.end_with?(".html", ".htm")
        return true if host == "brandfetch.io" && !host.start_with?("cdn.")

        false
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
