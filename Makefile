ENV_FILE ?= .env

.PHONY: deploy set-config shell logs

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
