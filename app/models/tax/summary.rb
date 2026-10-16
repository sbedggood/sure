# frozen_string_literal: true

module Tax
  class Summary
    attr_reader :family, :financial_year, :settings

    def initialize(family:, start_year:)
      @family = family
      @financial_year = FinancialYear.new(start_year)
      @settings = TaxFySetting.find_or_initialize_for!(family: family, start_year: start_year)
      @settings.save! if @settings.new_record?
    end

    def as_json
      {
        start_year: financial_year.start_year,
        label: financial_year.label,
        start_on: financial_year.start_on,
        end_on: financial_year.end_on,
        settings: settings_json,
        property: property_json,
        deductions: deductions_json,
        calendar_totals: calendar_totals_json
      }
    end

    def tagged_transactions
      @tagged_transactions ||= load_tagged_transactions
    end

    private

      def settings_json
        {
          property_allocation_percent: settings.property_allocation_percent,
          marginal_tax_rate_percent: settings.marginal_tax_rate_percent,
          wfh_hourly_rate: settings.wfh_hourly_rate,
          car_rate_per_km: settings.car_rate_per_km,
          deduction_business_use_percent: settings.deduction_business_use_percent
        }
      end

      def property_json
        months = financial_year.months
        rows = TagCatalog::PROPERTY_EXPENSE_TAGS.map do |tag_name|
          monthly = months.index_with { |m| BigDecimal("0") }
          tagged_transactions[tag_name]&.each do |entry|
            month = entry.date.beginning_of_month.to_date
            monthly[month] += property_line_amount(entry) if monthly.key?(month)
          end
          total = monthly.values.sum
          {
            tag: tag_name,
            label: tag_name.sub("Tax: Property - ", ""),
            months: monthly.transform_keys { |d| d.iso8601 }.transform_values(&:to_f),
            total: total.to_f
          }
        end

        rent_by_month = months.index_with { |m| BigDecimal("0") }
        rental_tag_names.each do |tag_name|
          tagged_transactions[tag_name]&.each do |entry|
            month = entry.date.beginning_of_month.to_date
            rent_by_month[month] += property_line_amount(entry) if rent_by_month.key?(month)
          end
        end

        cost_total = rows.sum { |r| BigDecimal(r[:total].to_s) }
        rent_total = rent_by_month.values.sum
        allocation = settings.property_allocation_percent / 100
        allocated_costs = cost_total * allocation
        difference = rent_total - allocated_costs
        marginal = settings.marginal_tax_rate_percent / 100
        expected_return = difference * marginal

        {
          months: months.map(&:iso8601),
          expense_rows: rows,
          rental_income: {
            by_tag: rental_tag_names.map { |name|
              total = tagged_transactions[name]&.sum { |e| property_line_amount(e) } || BigDecimal("0")
              { tag: name, total: total.to_f }
            },
            by_month: rent_by_month.transform_keys { |d| d.iso8601 }.transform_values(&:to_f),
            total: rent_total.to_f
          },
          cost_total: cost_total.to_f,
          property_allocation_percent: settings.property_allocation_percent.to_f,
          allocated_costs: allocated_costs.to_f,
          difference: difference.to_f,
          expected_return: expected_return.to_f
        }
      end

      def deductions_json
        tag_groups = tagged_transactions.keys.select { |name| TagCatalog.deduction_tag?(name) }
        lines = tag_groups.sort.map do |tag_name|
          entries = tagged_transactions[tag_name] || []
          amount = entries.sum { |e| e.amount }
          percent = settings.business_use_percent_for(tag_name)
          claim = amount * percent / 100
          {
            tag: tag_name,
            amount: amount.to_f,
            business_use_percent: percent.to_f,
            claim: claim.to_f,
            transactions: entries.map { |e| transaction_row(e) }
          }
        end

        calendar = calendar_totals_json
        home_office_claim = calendar[:wfh_hours_total] * settings.wfh_hourly_rate
        car_claim = calendar[:km_total] * settings.car_rate_per_km

        donations = line_for_tag(TagCatalog::DONATIONS_TAG)
        agent_fees = line_for_tag(TagCatalog::AGENT_FEES_TAG)

        work_claim = lines.sum { |l| BigDecimal(l[:claim].to_s) } + home_office_claim + car_claim
        grand_total = work_claim + donations[:claim] + agent_fees[:claim]

        {
          tag_lines: lines,
          home_office: {
            wfh_hours_total: calendar[:wfh_hours_total].to_f,
            hourly_rate: settings.wfh_hourly_rate.to_f,
            claim: home_office_claim.to_f
          },
          car: {
            km_total: calendar[:km_total].to_f,
            rate_per_km: settings.car_rate_per_km.to_f,
            claim: car_claim.to_f
          },
          donations: donations,
          agent_fees: agent_fees,
          grand_total: grand_total.to_f
        }
      end

      def line_for_tag(tag_name)
        entries = tagged_transactions[tag_name] || []
        amount = entries.sum { |e| e.amount }
        percent = settings.business_use_percent_for(tag_name)
        claim = amount * percent / 100
        { tag: tag_name, amount: amount.to_f, business_use_percent: percent.to_f, claim: claim.to_f }
      end

      def calendar_totals_json
        entries = family.tax_weekly_calendar_entries.for_year(financial_year.start_year)
        {
          wfh_hours_total: entries.sum(&:wfh_hours).to_f,
          km_total: entries.sum(&:km_driven).to_f
        }
      end

      def load_tagged_transactions
        names = family.tags.where("name LIKE ?", "Tax:%").pluck(:name)
        return {} if names.empty?

        entries = family.entries
          .joins("INNER JOIN transactions ON transactions.id = entries.entryable_id AND entries.entryable_type = 'Transaction'")
          .joins("INNER JOIN taggings ON taggings.taggable_id = transactions.id AND taggings.taggable_type = 'Transaction'")
          .joins("INNER JOIN tags ON tags.id = taggings.tag_id")
          .where(date: financial_year.range)
          .where(tags: { name: names })
          .includes(:account, entryable: :tags)
          .distinct

        entries.group_by do |entry|
          entry.transaction.tags.find { |t| names.include?(t.name) }&.name
        end.compact
      end

      def rental_tag_names
        family.tags.where("name LIKE ?", "#{TagCatalog::RENTAL_INCOME_PREFIX}%").pluck(:name).sort
      end

      # Property costs and rental income may be negative (statement import) or positive (sync).
      def property_line_amount(entry)
        entry.amount.abs
      end

      def transaction_row(entry)
        {
          id: entry.id,
          date: entry.date.iso8601,
          name: entry.name,
          amount: entry.amount.to_f,
          currency: entry.currency,
          account_name: entry.account.name
        }
      end
  end
end
