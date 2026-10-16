# frozen_string_literal: true

# Import a Commonwealth Bank NetBank CSV export into one account.
#
#   bin/rails comm_bank:import_csv \
#     FILE=/taxes/path/to/export.csv \
#     ACCOUNT_ID=<uuid> \
#     FAMILY_EMAIL=you@example.com \
#     BEFORE=2026-07-20
#
# BEFORE is optional: rows on or after that date are skipped (useful before Redbark overlap).
#
namespace :comm_bank do
  desc "Import NetBank CSV. Env: FILE, ACCOUNT_ID, FAMILY_EMAIL, BEFORE=YYYY-MM-DD"
  task import_csv: :environment do
    file = ENV.fetch("FILE", nil)
    account_id = ENV.fetch("ACCOUNT_ID", nil)
    family_email = ENV.fetch("FAMILY_EMAIL", nil)
    before_raw = ENV["BEFORE"].presence

    abort "FILE and ACCOUNT_ID are required" if file.blank? || account_id.blank?
    abort "FAMILY_EMAIL is required" if family_email.blank?
    abort "FILE not found: #{file}" unless File.file?(file)

    user = User.find_by(email: family_email)
    abort "No user for #{family_email}" unless user

    family = user.family
    account = family.accounts.find_by(id: account_id)
    abort "Account not found in family" unless account

    before_date = before_raw ? Date.parse(before_raw) : nil

    import = family.imports.create!(
      type: "CommBankImport",
      account: account,
      raw_file_str: File.read(file),
      col_sep: ",",
      status: :importing
    )
    import.generate_rows_from_csv

    if before_date
      removed = import.purge_rows_on_or_after!(before_date)
      puts "Skipped #{removed} CSV rows on or after #{before_date}"
    end

    Current.defer_account_syncs = true
    import.import!
    account.sync_later
    import.update!(status: :complete, error: nil)
    puts "Imported #{import.rows.count} rows from #{file}"
  rescue => e
    import&.update(status: :failed, error: e.message) if import&.persisted?
    raise
  ensure
    Current.defer_account_syncs = false
  end
end
