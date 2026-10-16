# Australian tax (financial year) module

Personal-fork feature for AU tax prep (1 Jul–30 Jun). Uses transaction tags prefixed with `Tax:`.

## Financial year naming (ATO)

Years are labelled by **end year**: Jul 2024–Jun 2025 is **FY25**.

- **`start_year`** (stored in DB, URL paths): July-start calendar year (`2024` → FY25).
- **`fy`** (optional): ATO end year — `25`, `2025`, or `FY25` → same period (`start_year` 2024).

## UI

- Nav: **Tax** → `/tax/dashboard?start_year=2024` or `?fy=25`
- Excel: `/tax/export?start_year=2024` (filename `FY25_tax_export.xlsx`)

## Tags

- Property expenses: `Tax: Property - Interest`, `- Insurance`, `- Body Corp`, `- Rates`, `- Water`, `- Improvements`, `- Internet`, `- Other`
- Rental income: any tag starting with `Tax: Rental Income`
- Other deductions: `Tax: ...` excluding property and rental (e.g. `Tax: Phone`, `Tax: Donations`, `Tax: Agent Fees`)

Property and rental totals use **absolute** entry amounts (statement vs sync sign).

## API (OAuth or `X-Api-Key`, scopes `read` / `read_write`)

Path segment is **`start_year`** (July year). Optional query `fy=` uses ATO end year instead. Values `1–99` in the path are treated as FY end shorthand (e.g. `/api/v1/tax/25/summary` → FY25).

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

## MCP (`/mcp` tools/list and tools/call)

Registered on the main assistant tool list (same as in-app assistant):

- `get_tax_summary`
- `upsert_tax_calendar`
- `list_tax_documents`

## Migrations

Run `bin/rails db:migrate` (creates `tax_fy_settings`, `tax_weekly_calendar_entries`, `tax_documents`).

Active Storage must be configured for document uploads (same as other family file features).
