# frozen_string_literal: true

require "digest"

module CommBankStatement
  class BackfillRunner
    SOURCE = "commbank_statement"
    FUZZY_NAME_THRESHOLD = 0.55
    DEDUPE_PROVIDER_SOURCES = %w[redbark].freeze

    StatementReport = Data.define(
      :path, :account, :statement_type, :transaction_count, :imported, :skipped_overlap,
      :skipped_duplicate, :skipped_parse, :balance_check_passed, :errors
    )

    RunSummary = Data.define(
      :reports, :statement_count, :balance_failures, :imported_total, :overlap_skipped_total,
      :duplicate_skipped_total
    )

    def initialize(family:, root:, mapping:, apply: false, stdout: $stdout, only: nil, limit: nil, offset: 0)
      @family = family
      @root = Pathname.new(root)
      @mapping = mapping
      @apply = apply
      @stdout = stdout
      @only = only.presence
      @limit = limit&.to_i
      @offset = offset.to_i
      @accounts_to_sync = Set.new
    end

    def run
      reports = []
      Current.defer_account_syncs = @apply

      each_pdf_path do |path|
        relative = path.relative_path_from(@root).to_s
        account_id = @mapping.match_account_id(relative)

        if account_id == :skip
          log "SKIP #{relative} (mapping)"
          next
        end

        unless account_id
          log "UNMAPPED #{relative}"
          next
        end

        account = @family.accounts.find_by(id: account_id)
        unless account
          log "UNKNOWN ACCOUNT #{account_id} for #{relative}"
          next
        end

        report = process_path(path, relative, account)
        reports << report if report
        print_report(report) if report
        GC.start if @apply
      end

      sync_deferred_accounts! if @apply
      summary = build_summary(reports)
      print_summary(summary)
      summary
    ensure
      Current.defer_account_syncs = false
    end

    private

      def each_pdf_path
        paths = @root.glob("**/*.pdf").sort
        if @only.present?
          paths.select! { |path| File.fnmatch(@only, path.relative_path_from(@root).to_s, File::FNM_PATHNAME | File::FNM_EXTGLOB) }
        end
        paths = paths.drop(@offset) if @offset.positive?
        paths = paths.first(@limit) if @limit&.positive?

        paths.each { |path| yield path }
      end

      def process_path(path, relative, account)
        parse_result = Parser.parse_file(path.to_s)
        report = process_statement(path, relative, account, parse_result)
        @accounts_to_sync << account.id if @apply && report.imported.positive?
        report
      rescue SkippedDocument => e
        log "SKIP #{relative} (#{e.reason})"
        nil
      rescue Parser::ParseError => e
        StatementReport.new(
          path: relative, account: account, statement_type: nil, transaction_count: 0,
          imported: 0, skipped_overlap: 0, skipped_duplicate: 0, skipped_parse: 1,
          balance_check_passed: false, errors: [ e.message ]
        )
      rescue StandardError => e
        log "ERROR #{relative} | #{e.class}: #{e.message}"
        StatementReport.new(
          path: relative, account: account, statement_type: nil, transaction_count: 0,
          imported: 0, skipped_overlap: 0, skipped_duplicate: 0, skipped_parse: 1,
          balance_check_passed: false, errors: [ "#{e.class}: #{e.message}" ]
        )
      end

      def process_statement(path, relative, account, parse_result)
        imported = 0
        skipped_overlap = 0
        skipped_duplicate = 0
        errors = parse_result.balance_check_errors.dup

        unless parse_result.balance_check_passed
          return statement_report(
            path: relative, account: account, parse_result: parse_result,
            imported: 0, skipped_overlap: 0, skipped_duplicate: 0, errors: errors
          )
        end

        cutoff = cutoff_date_for(account)
        adapter = Account::ProviderImportAdapter.new(account)
        claimed_dedupe_entry_ids = Set.new
        occurrence_ordinals = occurrence_ordinals_for(parse_result.transactions, account)

        if @apply
          ActiveRecord::Base.transaction do
            parse_result.transactions.each_with_index do |txn, index|
              outcome = classify_transaction(
                txn, account, cutoff, relative,
                occurrence: occurrence_ordinals[index],
                claimed_dedupe_entry_ids: claimed_dedupe_entry_ids
              )
              case outcome
              when :overlap then skipped_overlap += 1
              when :duplicate then skipped_duplicate += 1
              when :import
                import_transaction!(adapter, account, txn, relative, occurrence: occurrence_ordinals[index])
                imported += 1
              end
            end

            store_statement_vault!(path, account, parse_result)
          end
        else
          parse_result.transactions.each_with_index do |txn, index|
            outcome = classify_transaction(
              txn, account, cutoff, relative,
              occurrence: occurrence_ordinals[index],
              claimed_dedupe_entry_ids: claimed_dedupe_entry_ids
            )
            case outcome
            when :overlap then skipped_overlap += 1
            when :duplicate then skipped_duplicate += 1
            when :import then imported += 1
            end
          end
        end

        statement_report(
          path: relative, account: account, parse_result: parse_result,
          imported: imported, skipped_overlap: skipped_overlap, skipped_duplicate: skipped_duplicate, errors: errors
        )
      rescue StandardError => e
        errors << "#{e.class}: #{e.message}"
        statement_report(
          path: relative, account: account, parse_result: parse_result,
          imported: @apply ? 0 : imported,
          skipped_overlap: skipped_overlap,
          skipped_duplicate: skipped_duplicate,
          errors: errors
        )
      end

      def classify_transaction(txn, account, cutoff, relative, occurrence:, claimed_dedupe_entry_ids:)
        sure_amount = EntryAmountConverter.to_sure_amount(txn.amount, account)

        if txn.date >= cutoff
          log_row_skip(relative, txn, sure_amount, "overlap_cutoff", cutoff: cutoff)
          return :overlap
        end

        skip_reason, matched_entry = duplicate_skip_reason(
          account, txn, sure_amount, account.currency, relative, occurrence: occurrence,
          claimed_dedupe_entry_ids: claimed_dedupe_entry_ids
        )
        if skip_reason
          log_row_skip(
            relative, txn, sure_amount, skip_reason,
            matched_entry_id: matched_entry&.id, matched_source: matched_entry&.source
          )
          return :duplicate
        end

        :import
      end

      def import_transaction!(adapter, account, txn, relative, occurrence:)
        sure_amount = EntryAmountConverter.to_sure_amount(txn.amount, account)
        adapter.import_transaction(
          external_id: external_id_for(account, txn, sure_amount, relative, occurrence: occurrence),
          amount: sure_amount,
          currency: account.currency,
          date: txn.date,
          name: txn.description.to_s.truncate(255),
          source: SOURCE,
          notes: "Imported from CommBank PDF statement backfill",
          extra: { "commbank_statement" => { "file" => relative } },
          allow_heuristic_matching: false
        )
      end

      def statement_report(path:, account:, parse_result:, imported:, skipped_overlap:, skipped_duplicate:, errors:)
        StatementReport.new(
          path: path,
          account: account,
          statement_type: parse_result.statement_type,
          transaction_count: parse_result.transactions.size,
          imported: imported,
          skipped_overlap: skipped_overlap,
          skipped_duplicate: skipped_duplicate,
          skipped_parse: 0,
          balance_check_passed: parse_result.balance_check_passed,
          errors: errors
        )
      end

      def sync_deferred_accounts!
        Account.where(id: @accounts_to_sync.to_a).find_each(&:sync_later)
      end

      def build_summary(reports)
        RunSummary.new(
          reports: reports,
          statement_count: reports.size,
          balance_failures: reports.count { |r| !r.balance_check_passed },
          imported_total: reports.sum(&:imported),
          overlap_skipped_total: reports.sum(&:skipped_overlap),
          duplicate_skipped_total: reports.sum(&:skipped_duplicate)
        )
      end

      def store_statement_vault!(path, account, parse_result)
        upload = UploadedFile.new(path)
        begin
          prepared = AccountStatement.prepare_upload!(upload)
          statement = AccountStatement.create_from_prepared_upload!(
            family: @family,
            account: account,
            prepared_upload: prepared
          )
          statement.update!(
            period_start_on: parse_result.period_start_on,
            period_end_on: parse_result.period_end_on,
            opening_balance: parse_result.opening_balance,
            closing_balance: parse_result.closing_balance,
            currency: parse_result.currency || account.currency
          )
        rescue AccountStatement::DuplicateUploadError => e
          statement = e.statement
          statement.link_to_account!(account) if statement.account_id != account.id
          statement.update!(
            period_start_on: parse_result.period_start_on,
            period_end_on: parse_result.period_end_on,
            opening_balance: parse_result.opening_balance,
            closing_balance: parse_result.closing_balance,
            currency: parse_result.currency || account.currency
          )
        ensure
          upload.close
        end
      end

      def cutoff_date_for(account)
        raw = @mapping.before_date_for(account.id)
        if raw.present?
          return Date.parse(raw.to_s)
        end

        earliest = account.entries.where(source: "redbark").minimum(:date)
        earliest&.to_date || Date.current
      end

      def duplicate_skip_reason(account, txn, sure_amount, currency, relative, occurrence:, claimed_dedupe_entry_ids:)
        external_id = external_id_for(account, txn, sure_amount, relative, occurrence: occurrence)
        if account.entries.exists?(external_id: external_id, source: SOURCE)
          return [ "idempotent_external_id", nil ]
        end

        match = claimable_dedupe_entry(
          account: account,
          date: txn.date,
          amount: sure_amount,
          currency: currency,
          description: txn.description,
          claimed_dedupe_entry_ids: claimed_dedupe_entry_ids
        )
        return [ nil, nil ] unless match

        claimed_dedupe_entry_ids << match.id
        reason = if match.source.in?(DEDUPE_PROVIDER_SOURCES)
          "redbark_match"
        else
          "manual_match"
        end
        [ reason, match ]
      end

      def occurrence_ordinals_for(transactions, account)
        tallies = Hash.new(0)
        transactions.map do |txn|
          key = occurrence_key(txn, account)
          tallies[key] += 1
          tallies[key]
        end
      end

      def occurrence_key(txn, account)
        sure_amount = EntryAmountConverter.to_sure_amount(txn.amount, account)
        [ txn.date, normalize_name(txn.description), sure_amount ]
      end

      def claimable_dedupe_entry(account:, date:, amount:, currency:, description:, claimed_dedupe_entry_ids:)
        candidates = account.entries
          .where(entryable_type: "Transaction", amount: amount, currency: currency, date: date)
          .where.not(id: claimed_dedupe_entry_ids.to_a)
          .order(:created_at)
          .to_a
          .reject { |entry| statement_backfill_entry?(entry) }

        provider = candidates.find do |entry|
          entry.source.in?(DEDUPE_PROVIDER_SOURCES) && entry.external_id.present?
        end
        return provider if provider

        normalized = normalize_name(description)
        candidates.find do |entry|
          entry.external_id.blank? && manual_entry_source?(entry) &&
            fuzzy_names_match?(normalized, normalize_name(entry.name))
        end
      end

      def statement_backfill_entry?(entry)
        return true if entry.source == SOURCE

        entry.entryable.is_a?(Transaction) && entry.transaction.extra.to_h.key?("commbank_statement")
      end

      def manual_entry_source?(entry)
        entry.source.blank?
      end

      def fuzzy_names_match?(left, right)
        return true if left == right
        return true if left.present? && right.present? && (left.include?(right) || right.include?(left))

        overlap = (token_set(left) & token_set(right)).size
        union = (token_set(left) | token_set(right)).size
        union.zero? ? false : (overlap.to_f / union) >= FUZZY_NAME_THRESHOLD
      end

      def token_set(name)
        normalize_name(name).split(/\W+/).reject { |t| t.length < 3 }
      end

      def normalize_name(name)
        RecurringTransaction::Matcher.normalize_name(name)
      end

      def external_id_for(account, txn, sure_amount, relative, occurrence:)
        digest = Digest::SHA256.hexdigest(
          [
            account.id,
            relative,
            txn.date,
            sure_amount,
            normalize_name(txn.description),
            occurrence,
            transaction_fingerprint(txn)
          ].join("|")
        )
        "commbank_pdf_#{digest[0, 32]}"
      end

      def transaction_fingerprint(txn)
        if txn.balance.present?
          "bal:#{txn.balance.to_s('F')}"
        elsif txn.raw_lines.present?
          "raw:#{Digest::SHA256.hexdigest(txn.raw_lines.map(&:strip).join("\n"))[0, 16]}"
        else
          "raw:#{Digest::SHA256.hexdigest(txn.description.to_s)[0, 16]}"
        end
      end

      def log_row_skip(relative, txn, sure_amount, reason, cutoff: nil, matched_entry_id: nil, matched_source: nil)
        parts = [
          "SKIP_ROW",
          relative,
          reason,
          "date=#{txn.date}",
          "amount=#{sure_amount}",
          "name=#{normalize_name(txn.description).truncate(80)}"
        ]
        parts << "cutoff=#{cutoff}" if cutoff
        parts << "matched_entry_id=#{matched_entry_id}" if matched_entry_id
        parts << "matched_source=#{matched_source}" if matched_source.present?
        log(parts.join(" | "))
      end

      def print_report(report)
        account_name = report.account&.name || "?"
        if report.skipped_parse.positive?
          log "#{report.path} | #{account_name} | PARSE ERROR: #{report.errors.join(", ")}"
          return
        end

        status = report.balance_check_passed ? "OK" : "BALANCE FAIL"
        log [
          report.path,
          account_name,
          report.statement_type,
          "txns=#{report.transaction_count}",
          "import=#{report.imported}",
          "overlap_skip=#{report.skipped_overlap}",
          "dedupe_skip=#{report.skipped_duplicate}",
          status,
          report.errors.join("; ")
        ].join(" | ")
      end

      def print_summary(summary)
        log "—"
        log "Mode: #{@apply ? "APPLY" : "DRY RUN"}"
        log "Statements: #{summary.statement_count}"
        log "Balance failures: #{summary.balance_failures}"
        log "Would import / imported: #{summary.imported_total}"
        log "Skipped (overlap with sync): #{summary.overlap_skipped_total}"
        log "Skipped (duplicate): #{summary.duplicate_skipped_total}"
      end

      def log(message)
        @stdout.puts(message)
      end
  end
end
