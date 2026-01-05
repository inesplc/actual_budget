ENV_FILE ?= .env

.PHONY: deploy set-config shell logs fetch-transactions import-transactions setup-scripts

login:
	@heroku login

deploy:
	@git push heroku main
	@grep -v '^[[:space:]]*#' $(ENV_FILE) | xargs heroku config:set

set-config:
	@test -f $(ENV_FILE)
	@grep -v '^[[:space:]]*#' $(ENV_FILE) | xargs heroku config:set

run-shell:
	@heroku run bash

show-logs:
	@heroku logs --tail

setup-scripts:
	@cd scripts/actual_api && npm install
	@cd scripts/enable_banking && uv sync

fetch-transactions:
	@set -a && . ./$(ENV_FILE) && set +a && cd scripts/enable_banking && uv run fetch_transactions.py

import-transactions:
	@set -a && . ./$(ENV_FILE) && set +a && node scripts/actual_api/import_transactions.js
