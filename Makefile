ENV_FILE ?= .env

.PHONY: deploy set-config shell logs fetch-transactions import-transactions setup-scripts

login:
	@heroku login

deploy:
	@git push heroku main
	@heroku config:set $$(grep -v '^[[:space:]]*#' $(ENV_FILE) | tr '\n' ' ')

set-config:
	@test -f $(ENV_FILE)
	@heroku config:set $$(grep -v '^[[:space:]]*#' $(ENV_FILE) | tr '\n' ' ')

run-shell:
	@heroku run bash

show-logs:
	@heroku logs --tail

fetch-transactions:
	@set -a && . ./$(ENV_FILE) && set +a && python3 scripts/fetch_transactions.py

setup-scripts:
	@cd scripts && npm install

import-transactions:
	@set -a && . ./$(ENV_FILE) && set +a && node scripts/debug_actual.js
# 	@set -a && . ./$(ENV_FILE) && set +a && node scripts/import_transactions.js
