ENV_FILE ?= .env
LOCAL_IMAGE ?= actual-budget-local
LOCAL_PORT ?= 5006
LOCAL_DATA_DIR ?= $(PWD)/.local-data
TUNNEL_PORT ?= 8080

.PHONY: deploy set-config shell logs fetch-transactions import-transactions setup-scripts build-local run-local push-local tunnel

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

tunnel:
	@command -v cloudflared >/dev/null 2>&1 || (echo "cloudflared not installed. Install with: brew install cloudflared"; exit 1)
	@echo "Opening Cloudflare quick tunnel to http://localhost:$(TUNNEL_PORT)"
	@echo "Copy the printed https://<random>.trycloudflare.com URL into your Enable Banking app's redirect URLs."
	@cloudflared tunnel --url http://localhost:$(TUNNEL_PORT)

import-transactions:
	@set -a && . ./$(ENV_FILE) && set +a && node scripts/actual_api/import_transactions.js

build-local:
	@docker build -t $(LOCAL_IMAGE) .

run-local: build-local
	@mkdir -p $(LOCAL_DATA_DIR)
	@docker run --rm -it \
		--env-file $(ENV_FILE) \
		-e PORT=5006 \
		-p $(LOCAL_PORT):5006 \
		-v "$(LOCAL_DATA_DIR):/app/data" \
		--name $(LOCAL_IMAGE) \
		$(LOCAL_IMAGE)

push-local: build-local
	@test -d $(LOCAL_DATA_DIR) || (echo "$(LOCAL_DATA_DIR) does not exist"; exit 1)
	@docker run --rm \
		--env-file $(ENV_FILE) \
		-v "$(LOCAL_DATA_DIR):/app/data" \
		--entrypoint sh \
		$(LOCAL_IMAGE) -c '\
			printf "[default]\naccess_key = %s\nsecret_key = %s\nhost_base = %s.r2.cloudflarestorage.com\nhost_bucket = %s.r2.cloudflarestorage.com\nuse_https = True\n" \
				"$$CLOUDFLARE_R2_KEY_ID" "$$CLOUDFLARE_R2_SECRET_KEY" "$$CLOUDFLARE_ACCOUNT_ID" "$$CLOUDFLARE_ACCOUNT_ID" > $$HOME/.s3cfg && \
			s3cmd --delete-removed sync /app/data/ s3://actual-budget/data/'
