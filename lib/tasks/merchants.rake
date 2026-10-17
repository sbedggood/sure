# frozen_string_literal: true

namespace :merchants do
  desc "Cache merchant logos locally (DRY_RUN=1, LIMIT=n, DELAY_SEC=0.25)"
  task cache_logos: :environment do
    dry_run = ENV["DRY_RUN"].present?
    limit = ENV["LIMIT"].presence&.to_i
    delay = ENV.fetch("DELAY_SEC", "0.25").to_f

    scope = Merchant
      .where.missing(:logo_attachment)
      .where(
        "COALESCE(website_url, '') <> '' OR COALESCE(logo_url, '') <> ''"
      )
      .order(:created_at)

    counts = { cached: 0, skipped_attached: 0, skipped_no_source: 0, failed: 0, dry_run: 0 }
    processed = 0

    scope.find_each do |merchant|
      break if limit && processed >= limit

      processed += 1
      result = Merchant::LogoCacher.cache!(merchant, dry_run: dry_run)
      counts[result.status] = counts.fetch(result.status, 0) + 1

      sleep delay if delay.positive? && !dry_run && result.status == :cached
    end

    puts "merchants:cache_logos complete (dry_run=#{dry_run})"
    counts.each { |status, count| puts "  #{status}: #{count}" }
  end
end
