# Actual Budget (Self-Hosted with Automation)

This repository contains a self-hosted instance of [Actual Budget](https://actualbudget.com/), configured for deployment on Heroku with automated data syncing and transaction importing.

## Features

*   **Self-Hosted Actual Server**: Runs the latest `actualbudget/actual-server`.
*   **Data Persistence**: Syncs data to Cloudflare R2, ensuring data is preserved across Heroku restarts.
*   **Automated Bank Sync**:
    *   Fetches transactions from via Enable Banking API
    *   Imports transactions directly into Actual Budget
*   **Scheduled Tasks**: Uses `supercronic` to run jobs on the same container as Actual.

## Prerequisites

You need the following environment variables set in your `.env` file (for local dev) or Heroku config:

### Actual Budget
*   `ACTUAL_BUDGET_SERVER`: Your Actual Budget server
*   `ACTUAL_BUDGET_PASSWORD`: Your Actual Budget server password
*   `ACTUAL_IMPORT_CONFIG`: A JSON string defining the mapping between IBANs, Sync IDs, and Account Names
    Example: `[{"iban":"PT50...","syncId":"...","accountName":"Checking"}]`

### Cloudflare R2 (Data Storage)
*   `CLOUDFLARE_ACCOUNT_ID`: Your Cloudflare Account ID
*   `CLOUDFLARE_R2_KEY_ID`: R2 Access Key ID
*   `CLOUDFLARE_R2_SECRET_KEY`: R2 Secret Access Key

### Enable Banking (Transaction Fetching)
*   `ENABLE_BANKING_PRIVATE_KEY_BASE64`: Your Enable Banking private key (Base64 encoded)
*   `ENABLE_BANKING_ASPSP`: A JSON string defining the ASPSPs to retrieve transactions for.
    Example: `[{"name":"Bank Name","country":"US", "consent_validity_seconds":5184000}]`

### Optional
* `IS_LOCAL`: Set to `TRUE` and run `scripts/enable_banking/fetch_transactions.py` when needing to update Enable Banking's session
*   `NODE_TLS_REJECT_UNAUTHORIZED`: Set to `0` if you encounter SSL certificate errors (e.g., with self-signed certificates or certain proxy configurations). **Use with caution in production**


## Project

*   `scripts/`: Automation scripts
    *   `actual_api/`: Node.js scripts for interacting with Actual Budget API
    *   `enable_banking/`: Python scripts for fetching bank data
    *   `data_sync.sh`: Syncs local data to R2
    *   `setup_sync.sh`: Restores data from R2 on startup
    *   `crontab`: Schedule for automated tasks
*   `Dockerfile`: Defines the runtime environment
*   `heroku.yml`: Defines heroku deployment
