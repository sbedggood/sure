# frozen_string_literal: true

require "digest"

module CommBankStatement
  class BackfillRunner
    SOURCE = "commbank_statement"
    DATE_WINDOW = 3
    FUZZY_NAME_THRESHOLD = 0.55

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

        if @apply
          ActiveRecord::Base.transaction do
            parse_result.transactions.each do |txn|
              outcome = classify_transaction(txn, account, adapter, cutoff, relative)
              case outcome
              when :overlap then skipped_overlap += 1
              when :duplicate then skipped_duplicate += 1
              when :import
                import_transaction!(adapter, account, txn, relative)
                imported += 1
              end
            end

            store_statement_vault!(path, account, parse_result)
          end
        else
          parse_result.transactions.each do |txn|
            outcome = classify_transaction(txn, account, adapter, cutoff, relative)
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

      def classify_transaction(txn, account, adapter, cutoff, relative)
        return :overlap if txn.date >= cutoff

        sure_amount = EntryAmountConverter.to_sure_amount(txn.amount, account)
        return :duplicate if duplicate?(adapter, account, txn, sure_amount, account.currency)

        :import
      end

      def import_transaction!(adapter, account, txn, relative)
        sure_amount = EntryAmountConverter.to_sure_amount(txn.amount, account)
        adapter.import_transaction(
          external_id: external_id_for(account, txn, sure_amount),
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
        if @mapping.before_date.present?
          return Date.parse(@mapping.before_date.to_s)
        end

        earliest = account.entries.where(source: "redbark").minimum(:date)
        earliest&.to_date || Date.current
      end

      def duplicate?(adapter, account, txn, sure_amount, currency)
        external_id = external_id_for(account, txn, sure_amount)
        return true if account.entries.exists?(external_id: external_id, source: SOURCE)

        base = adapter.account.entries
          .where(entryable_type: "Transaction", amount: sure_amount, currency: currency)
          .where.not(source: SOURCE)

        return true if base.where(date: txn.date).where.not(external_id: nil).exists?

        window = (txn.date - DATE_WINDOW.days)..(txn.date + DATE_WINDOW.days)
        manual = base.where(date: window, external_id: nil)
        return true if manual.where(date: txn.date).exists?

        normalized = normalize_name(txn.description)
        manual.limit(50).any? do |entry|
          fuzzy_names_match?(normalized, normalize_name(entry.name))
        end
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

      def external_id_for(account, txn, sure_amount)
        digest = Digest::SHA256.hexdigest(
          [ account.id, txn.date, sure_amount, normalize_name(txn.description) ].join("|")
        )
        "commbank_pdf_#{digest[0, 32]}"
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
