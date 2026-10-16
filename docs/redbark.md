# Redbark bank sync (Australia)

Redbark connects Australian banks (including CommBank) to Sure via the Consumer Data Right (CDR). Sure uses Redbark’s REST API with a per-family API key.

## What you need

1. A [Redbark](https://app.redbark.com) account with your CBA accounts connected through Redbark’s consent flow.
2. A Redbark **API key** (Settings → API Keys). API access requires a Developer or Professional plan.
3. In Sure: **Settings → Providers → Redbark** — paste the API key, save, then link each Redbark account to a Sure account (transaction, savings, credit card, home loan, and so on).

## Sync behaviour

- First sync: about 90 days of transactions per linked account (or your chosen start date).
- Later syncs: incremental with a 7-day lookback for late-posting items.
- Balances update on every sync. Transactions dedupe on Redbark transaction id.
- Optional: `REDBARK_INCLUDE_PENDING=true` to import pending transactions.

## CommBank without API sync

Export CSV from NetBank and use **Import → Import CommBank NetBank CSV**. See [CommBank CSV fallback](hosting/redbark.md#commbank-csv-fallback-netbank-export) in the full hosting guide.

## Full guide

Step-by-step setup and troubleshooting: [docs/hosting/redbark.md](hosting/redbark.md).
