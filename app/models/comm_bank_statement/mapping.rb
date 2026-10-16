# frozen_string_literal: true

module CommBankStatement
  class Mapping
    Rule = Data.define(:pattern, :account_id, :account_name, :skip)

    def self.load(path)
      data = YAML.safe_load(File.read(path), permitted_classes: [ Date ], aliases: true)
      new(data)
    end

    def initialize(data)
      @data = data || {}
      @rules = Array(@data["rules"]).map do |rule|
        Rule.new(
          pattern: rule["pattern"].to_s,
          account_id: rule["account_id"],
          account_name: rule["account_name"],
          skip: rule["skip"] == true
        )
      end
    end

    def family_email
      @data["family_email"]
    end

    def before_date
      @data["before_date"]
    end

    def match_account_id(relative_path)
      @rules.each do |rule|
        next unless File.fnmatch(rule.pattern, relative_path, File::FNM_PATHNAME | File::FNM_EXTGLOB)

        return :skip if rule.skip
        return rule.account_id if rule.account_id.present?
      end
      nil
    end
  end
end
