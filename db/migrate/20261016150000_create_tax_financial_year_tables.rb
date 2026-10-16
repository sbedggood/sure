# frozen_string_literal: true

class CreateTaxFinancialYearTables < ActiveRecord::Migration[8.1]
  def change
    create_table :tax_fy_settings, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.integer :start_year, null: false
      t.decimal :property_allocation_percent, precision: 5, scale: 2, null: false, default: 50
      t.decimal :marginal_tax_rate_percent, precision: 5, scale: 2, null: false, default: 47
      t.decimal :wfh_hourly_rate, precision: 6, scale: 4, null: false, default: 0.67
      t.decimal :car_rate_per_km, precision: 6, scale: 4, null: false, default: 0.85
      t.jsonb :deduction_business_use_percent, null: false, default: {}
      t.timestamps
    end

    add_index :tax_fy_settings, [ :family_id, :start_year ], unique: true

    create_table :tax_weekly_calendar_entries, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.integer :start_year, null: false
      t.date :week_commencing, null: false
      t.decimal :wfh_hours, precision: 8, scale: 2, null: false, default: 0
      t.decimal :km_driven, precision: 10, scale: 2, null: false, default: 0
      t.text :note
      t.timestamps
    end

    add_index :tax_weekly_calendar_entries,
      [ :family_id, :start_year, :week_commencing ],
      unique: true,
      name: "index_tax_weekly_calendar_on_family_year_week"

    create_table :tax_documents, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.integer :start_year, null: false
      t.string :document_type, null: false
      t.date :document_date
      t.text :note
      t.timestamps
    end

    add_index :tax_documents, [ :family_id, :start_year ]
  end
end
