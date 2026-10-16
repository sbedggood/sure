# frozen_string_literal: true

require "digest"

module CommBankStatement
  class BackfillRunner
    SOURCE = "commbank_statement"
    DATE_WINDOW = 3
    FUZZY_NAME_THRESHOLD = 0.55

    StatementReport = Data.define(
      :path, :account, :parse_result, :imported, :skipped_overlap, :skipped_duplicate,
      :skipped_parse, :errors
    )

    def initialize(family:, root:, mapping:, apply: false, stdout: $stdout)
      @family = family
      @root = Pathname.new(root)
      @mapping = mapping
      @apply = apply
      @stdout = stdout
    end

    def run
      reports = []
      pdf_files = @root.glob("**/*.pdf").sort

      pdf_files.each do |path|
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

        begin
          parse_result = Parser.parse_file(path.to_s)
        rescue SkippedDocument => e
          log "SKIP #{relative} (#{e.reason})"
          next
        rescue Parser::ParseError => e
          reports << StatementReport.new(path: relative, account: account, parse_result: nil,
            imported: 0, skipped_overlap: 0, skipped_duplicate: 0, skipped_parse: 1, errors: [ e.message ])
          next
        rescue StandardError => e
          log "ERROR #{relative} | #{e.class}: #{e.message}"
          reports << StatementReport.new(path: relative, account: account, parse_result: nil,
            imported: 0, skipped_overlap: 0, skipped_duplicate: 0, skipped_parse: 1,
            errors: [ "#{e.class}: #{e.message}" ])
          next
        end

        report = process_statement(path, relative, account, parse_result)
        reports << report
        print_report(report)
      end

      print_summary(reports)
      reports
    end

    private

      def process_statement(path, relative, account, parse_result)
        imported = 0
        skipped_overlap = 0
        skipped_duplicate = 0
        errors = parse_result.balance_check_errors.dup

        unless parse_result.balance_check_passed
          return StatementReport.new(
            path: relative, account: account, parse_result: parse_result,
            imported: 0, skipped_overlap: 0, skipped_duplicate: 0, skipped_parse: 0, errors: errors
          )
        end

        cutoff = cutoff_date_for(account)
        adapter = Account::ProviderImportAdapter.new(account)
        claimed = Set.new

        parse_result.transactions.each do |txn|
          if txn.date >= cutoff
            skipped_overlap += 1
            next
          end

          sure_amount = EntryAmountConverter.to_sure_amount(txn.amount, account)
          if duplicate?(adapter, txn, sure_amount, account.currency, claimed)
            skipped_duplicate += 1
            next
          end

          imported += 1
          next unless @apply

          external_id = external_id_for(account, txn, sure_amount)
          adapter.import_transaction(
            external_id: external_id,
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

        if @apply
          store_statement_vault!(path, account, parse_result)
        end

        StatementReport.new(
          path: relative, account: account, parse_result: parse_result,
          imported: imported, skipped_overlap: skipped_overlap, skipped_duplicate: skipped_duplicate,
          skipped_parse: 0, errors: errors
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

      def duplicate?(adapter, txn, sure_amount, currency, claimed)
        exact = adapter.find_duplicate_transaction(
          date: txn.date,
          amount: sure_amount,
          currency: currency,
          date_window: DATE_WINDOW,
          include_provider_entries: true,
          exclude_entry_ids: claimed
        )
        if exact
          claimed << exact.id
          return true
        end

        fuzzy = find_fuzzy_duplicate(adapter, txn, sure_amount, currency, claimed)
        if fuzzy
          claimed << fuzzy.id
          return true
        end

        false
      end

      def find_fuzzy_duplicate(adapter, txn, sure_amount, currency, claimed)
        window = (txn.date - DATE_WINDOW.days)..(txn.date + DATE_WINDOW.days)
        candidates = adapter.account.entries
          .where(entryable_type: "Transaction", amount: sure_amount, currency: currency, date: window)
          .where.not(id: claimed.to_a)
          .limit(50)

        normalized = normalize_name(txn.description)
        candidates.find do |entry|
          entry_name = normalize_name(entry.name)
          fuzzy_names_match?(normalized, entry_name)
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
        if report.parse_result.nil?
          log "#{report.path} | #{account_name} | PARSE ERROR: #{report.errors.join(", ")}"
          return
        end

        pr = report.parse_result
        status = pr.balance_check_passed ? "OK" : "BALANCE FAIL"
        log [
          report.path,
          account_name,
          pr.statement_type,
          "txns=#{pr.transactions.size}",
          "import=#{report.imported}",
          "overlap_skip=#{report.skipped_overlap}",
          "dedupe_skip=#{report.skipped_duplicate}",
          status,
          pr.balance_check_errors.join("; ")
        ].join(" | ")
      end

      def print_summary(reports)
        log "—"
        log "Mode: #{@apply ? "APPLY" : "DRY RUN"}"
        log "Statements: #{reports.size}"
        log "Balance failures: #{reports.count { |r| r.parse_result && !r.parse_result.balance_check_passed }}"
        log "Would import / imported: #{reports.sum(&:imported)}"
        log "Skipped (overlap with sync): #{reports.sum(&:skipped_overlap)}"
        log "Skipped (duplicate): #{reports.sum(&:skipped_duplicate)}"
      end

      def log(message)
        @stdout.puts(message)
      end
  end
end
