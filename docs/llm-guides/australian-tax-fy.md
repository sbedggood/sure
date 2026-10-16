# Australian tax (financial year) module

Personal-fork feature for AU tax prep (1 Jul–30 Jun). Uses transaction tags prefixed with `Tax:`.

## UI

- Nav: **Tax** → `/tax/dashboard?start_year=YYYY&section=calendar|property|deductions|documents`
- Excel: `/tax/export?start_year=YYYY`

## Tags

- Property expenses: `Tax: Property - Interest`, `- Insurance`, `- Body Corp`, `- Rates`, `- Water`, `- Improvements`, `- Internet`, `- Other`
- Rental income: any tag starting with `Tax: Rental Income`
- Other deductions: `Tax: ...` excluding property and rental (e.g. `Tax: Phone`, `Tax: Donations`, `Tax: Agent Fees`)

## API (OAuth or `X-Api-Key`, scopes `read` / `read_write`)

| Method | Path |
|--------|------|
| GET | `/api/v1/tax/:start_year/summary` |
| GET/PATCH | `/api/v1/tax/:start_year/settings` |
| GET | `/api/v1/tax/:start_year/weekly_calendar_entries` |
| PUT | `/api/v1/tax/:start_year/weekly_calendar_entries/bulk` |
| GET/POST | `/api/v1/tax/:start_year/documents` |
| GET/DELETE | `/api/v1/tax/:start_year/documents/:id` |
| GET | `/api/v1/tax/:start_year/export` |

Transaction tags: use existing `PATCH /api/v1/transactions/:id` with `tag_ids`.

## MCP tools

- `get_tax_summary`
- `upsert_tax_calendar`
- `list_tax_documents`

## Migrations

Run `bin/rails db:migrate` (creates `tax_fy_settings`, `tax_weekly_calendar_entries`, `tax_documents`).

Active Storage must be configured for document uploads (same as other family file features).
