# frozen_string_literal: true

namespace :merchants do
  desc "Cache merchant logos locally (DRY_RUN=1, LIMIT=n, DELAY_SEC=0.25)"
  task cache_logos: :environment do
    $stdout.sync = true
    dry_run = ENV["DRY_RUN"].present?
    limit = ENV["LIMIT"].presence&.to_i
    delay = ENV.fetch("DELAY_SEC", "0.25").to_f

    scope = Merchant
      .where.missing(:logo_attachment)
      .where(
        "COALESCE(website_url, '') <> '' OR COALESCE(logo_url, '') <> ''"
      )
      .order(:created_at)

    total = limit ? scope.limit(limit).count : scope.count
    counts = { cached: 0, skipped_attached: 0, skipped_no_source: 0, failed: 0, dry_run: 0 }
    processed = 0

    puts "merchants:cache_logos starting (dry_run=#{dry_run}, total=#{total})"
    $stdout.flush

    scope.find_each do |merchant|
      break if limit && processed >= limit

      processed += 1
      result = Merchant::LogoCacher.cache!(merchant, dry_run: dry_run)
      counts[result.status] = counts.fetch(result.status, 0) + 1

      puts "  [#{processed}/#{total}] #{merchant.id} #{merchant.name.inspect} -> #{result.status}"
      $stdout.flush

      sleep delay if delay.positive? && !dry_run && result.status == :cached
    end

    puts "merchants:cache_logos complete (dry_run=#{dry_run}, processed=#{processed})"
    counts.each { |status, count| puts "  #{status}: #{count}" }
    $stdout.flush
  end
end
