# frozen_string_literal: true

# Bulk-import historical CommBank PDF statements (deterministic parser).
#
# Dry run (default):
#   bin/rails comm_bank_statement:backfill ROOT=/taxes MAPPING=/rails/config/commbank_statement_mapping.yml
#
# Apply imports + Statement Vault uploads:
#   bin/rails comm_bank_statement:backfill ROOT=/taxes MAPPING=/rails/config/commbank_statement_mapping.yml APPLY=1
#
namespace :comm_bank_statement do
  desc "Parse CommBank PDF statements and backfill transactions before Redbark sync. Env: ROOT, MAPPING, APPLY=1, FAMILY_EMAIL, ONLY, LIMIT, OFFSET"
  task backfill: :environment do
    root = ENV.fetch("ROOT", nil)
    mapping_path = ENV.fetch("MAPPING", nil)
    apply = %w[1 true yes].include?(ENV.fetch("APPLY", "").to_s.downcase)

    if root.blank? || mapping_path.blank?
      abort "ROOT and MAPPING are required. Example: ROOT=/taxes MAPPING=config/commbank_statement_mapping.yml"
    end

    unless File.directory?(root)
      abort "ROOT is not a directory: #{root}"
    end

    unless File.file?(mapping_path)
      abort "MAPPING file not found: #{mapping_path}"
    end

    mapping = CommBankStatement::Mapping.load(mapping_path)
    family_email = ENV["FAMILY_EMAIL"].presence || mapping.family_email
    if family_email.blank?
      abort "Set family_email in mapping YAML or pass FAMILY_EMAIL=..."
    end

    user = User.find_by(email: family_email)
    abort "No user for email #{family_email}" unless user

    family = user.family
    abort "User #{family_email} has no family" unless family

    CommBankStatement::BackfillRunner.new(
      family: family,
      root: root,
      mapping: mapping,
      apply: apply,
      only: ENV["ONLY"],
      limit: ENV["LIMIT"],
      offset: ENV.fetch("OFFSET", 0)
    ).run
  end
end
