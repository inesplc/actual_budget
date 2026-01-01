# Actual Budget (Self-Hosted with Automation)

This repository contains a self-hosted instance of [Actual Budget](https://actualbudget.com/), configured for deployment on Heroku (or Docker) with automated data syncing and transaction importing.

## Features

*   **Self-Hosted Actual Server**: Runs the latest `actualbudget/actual-server`.
*   **Data Persistence**: Automatically syncs data to Cloudflare R2, ensuring data is preserved across Heroku restarts.
*   **Automated Bank Sync**:
    *   Fetches transactions from Activo Bank (via Enable Banking API).
    *   Imports transactions directly into Actual Budget.
*   **Scheduled Tasks**: Uses `supercronic` to run sync and import jobs automatically.

## Prerequisites

You need the following environment variables set in your `.env` file (for local dev) or Heroku config:

### Actual Budget
*   `ACTUAL_BUDGET_PASSWORD`: Your Actual Budget server password.
*   `ACTUAL_SYNC_ID`: The ID of the budget file you want to sync with.

### Cloudflare R2 (Data Storage)
*   `CLOUDFLARE_ACCOUNT_ID`: Your Cloudflare Account ID.
*   `CLOUDFLARE_R2_KEY_ID`: R2 Access Key ID.
*   `CLOUDFLARE_R2_SECRET_KEY`: R2 Secret Access Key.

### Enable Banking (Transaction Fetching)
*   `ENABLE_BANKING_PRIVATE_KEY_BASE64`: Your Enable Banking private key (Base64 encoded).


## Deployment

### Heroku

1.  **Login to Heroku:**
    ```bash
    make login
    ```

2.  **Set Configuration (Optional)**
    Ensure your `.env` file is populated, then run:
    ```bash
    make set-config
    ```

3.  **Deploy:**
    ```bash
    make deploy
    ```

This will push the Docker image to Heroku, which starts the server, restores data from R2, and starts the cron jobs.

## Running Scripts Locally

The repository includes a `Makefile` to simplify running scripts locally.

### Setup
Install dependencies for both Python and Node.js scripts:
```bash
make setup-scripts
```

### Fetch Transactions
Fetches transactions from the bank and saves them to R2:
```bash
make fetch-transactions
```

### Import Transactions
Imports the fetched transactions from R2 into Actual Budget:
```bash
make import-transactions
```

### Other Commands
*   `make run-shell`: Open a bash shell in the running Heroku container.
*   `make show-logs`: Tail the Heroku logs.

## Project Structure

*   `app/`: Application data (synced with R2).
*   `scripts/`: Automation scripts.
    *   `actual_api/`: Node.js scripts for interacting with Actual Budget API.
    *   `enable_banking/`: Python scripts for fetching bank data.
    *   `data_sync.sh`: Syncs local data to R2.
    *   `setup_sync.sh`: Restores data from R2 on startup.
    *   `crontab`: Schedule for automated tasks.
*   `Dockerfile`: Defines the runtime environment.
