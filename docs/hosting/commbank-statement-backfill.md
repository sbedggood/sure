# CommBank PDF statement backfill

Deterministic parsers for Commonwealth Bank PDF statements (everyday/savings, credit card, and home loan transaction listings) plus a bulk task to import historical transactions into Sure **before** your Redbark sync window and store originals in the **Statement Vault**.

PDF text is extracted with **`pdftotext -layout`** (from `poppler-utils`, already in the app Docker image). This matches CommBank’s column layout far more reliably than raw `PDF::Reader` output.

This is intended for self-hosted Docker setups where tax folders live on the host (for example `~/Documents/Taxes`).

## Supported statement types

| Type | Detection | Parser status |
|------|-----------|---------------|
| Everyday / Smart Access / Complete Access | `Date / Transaction / Debit / Credit / Balance` table | Implemented; covered by text fixture tests |
| NetBank Saver / savings | Same table layout as everyday | Implemented (same parser); not validated against real PDFs in CI |
| Credit card | `Date / Transaction / Amount` (or Transaction Details) | Implemented; basic layout tests only |
| Home loan / mortgage | Filename or “home loan” in text; uses transaction table parser | Heuristic detection; layouts vary—validate with dry run |
| CFS managed funds / super | — | **Not supported** (different issuer/format); mapping `skip: true` recommended |
| Home loan repayment notices (rate/minimum payment letters) | Detected by content | **Skipped automatically** (`SKIP … home_loan_repayment_notice`) |

Always run a **dry run** first and review balance-check results per file.

## Docker: mount tax PDFs read-only

In your `compose.yml` (or override), mount Stephen’s tax tree into the `web` service:

```yaml
services:
  web:
    volumes:
      - ~/Documents/Taxes:/taxes:ro
```

Use an absolute host path. Inside the container, `ROOT` for the rake task is `/taxes`.

Copy and edit the mapping file on the host or in the repo:

```bash
cp config/commbank_statement_mapping.example.yml config/commbank_statement_mapping.yml
# Set family_email and account_id UUIDs from the Sure UI
```

## Running the backfill

Dry run (default—no database writes):

```bash
docker compose exec web bin/rails comm_bank_statement:backfill \
  ROOT=/taxes \
  MAPPING=config/commbank_statement_mapping.yml
```

Apply imports and upload PDFs to the Statement Vault:

```bash
docker compose exec web bin/rails comm_bank_statement:backfill \
  ROOT=/taxes \
  MAPPING=config/commbank_statement_mapping.yml \
  APPLY=1
```

Optional `FAMILY_EMAIL` overrides `family_email` in the YAML.

Batching (low-memory hosts):

```bash
# Only FY26 everyday PDFs
ONLY='Tax FY26/My Account Statements/**.pdf' ...

# First 10 files (sorted), then resume with OFFSET
LIMIT=10 OFFSET=0 ...
LIMIT=10 OFFSET=10 ...
```

Apply defers per-account balance sync until each account finishes its statements in the run.

### NetBank CSV gaps (PR #1 `CommBankImport`)

For July 2026 CSV exports before Redbark (`2026-07-20`):

```bash
docker compose exec web bin/rails comm_bank:import_csv \
  FILE=/taxes/path/to/export.csv \
  ACCOUNT_ID=<uuid> \
  FAMILY_EMAIL=you@example.com \
  BEFORE=2026-07-20
```

Rows on or after `BEFORE` are dropped before import; one account sync runs at the end.

### Behaviour

- Walks `ROOT/**/*.pdf` in sorted order.
- Maps each file to an account via `File.fnmatch` rules in the YAML (`**` globs supported).
- Parses the PDF, validates **opening + sum(movements) = closing** (and per-row running balance for transaction accounts).
- Imports only rows with `date < cutoff`, where cutoff is per-account `accounts.<uuid>.before_date`, global `before_date` in YAML, or the earliest `source: redbark` entry on that account.
- Dedupes against existing entries (±3 days, same amount, fuzzy description) so re-runs are safe.
- With `APPLY=1`, creates entries with `source: commbank_statement` and stores the PDF via `AccountStatement` (vault), including period and balances when parsed.

## Using your fork instead of the stable image

Official images are documented in [docker.md](./docker.md). To run **your fork** with this backfill code:

### Option A — build from a local clone

```yaml
services:
  web:
    build: .
    # image: ghcr.io/we-promise/sure:stable   # comment out when building
  worker:
    build: .
```

```bash
docker compose build web worker
docker compose up -d
```

Point `build:` at your fork’s checkout (branch `cursor/commbank-pdf-backfill-6b22` or your merged `main`).

### Option B — publish and pull a custom tag

Build and push from CI or locally, then:

```yaml
image: ghcr.io/<your-user>/sure:commbank-backfill
```

```bash
docker compose pull
docker compose up -d --no-deps web worker
```

## Adding parser fixtures

Text fixtures (fast unit tests) live under `test/fixtures/files/commbank_statements/`. Add a `.txt` file that mirrors `pdf-reader` line order from a real statement (no account numbers required), then extend `test/models/comm_bank_statement/parser_test.rb`.

For PDF integration tests, place a redacted sample under `test/fixtures/files/commbank_statements/` and parse with `CommBankStatement::Parser.parse_file` in a test.

## Troubleshooting

- **BALANCE FAIL** — layout differs from CommBank’s usual columns; open the PDF text in dry run, add a fixture, adjust parsers.
- **UNMAPPED** — add a `rules` pattern for that relative path.
- **Duplicate vault upload** — same file SHA; runner links metadata to the mapped account.
- **Overlap skips** — expected for dates already covered by Redbark; lower `before_date` only if you intend to replace that window (dedupe still applies).
