# Stint — common tasks. Run `make help` for a list.
.PHONY: help app run install uninstall test test-unit test-ui open logs package clean

APP := build/Stint.app

help: ## Show this help
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-10s %s\n", $$1, $$2}'

app: ## Build build/Stint.app
	@Scripts/build-app.sh

run: app ## Build and launch the app
	@pkill -x Stint || true
	@open $(APP)

install: app ## Build and copy the app to /Applications
	@pkill -x Stint || true
	@rm -rf /Applications/Stint.app
	@cp -R $(APP) /Applications/
	@echo "Installed to /Applications/Stint.app"

uninstall: ## Remove the app (your history and settings are kept)
	@pkill -x Stint || true
	@rm -rf /Applications/Stint.app
	@echo "Removed /Applications/Stint.app"

test: ## Run every test (unit and UI)
	@swift test

test-unit: ## Run the fast tests only (no windows; a few seconds)
	@swift test --skip UITests

test-ui: ## Run the UI tests only (they open real windows)
	@swift test --filter UITests

open: ## Open the package in Xcode
	@open -a Xcode Package.swift

logs: ## Stream the running app's log messages
	@log stream --style compact --predicate 'process == "Stint"'

package: ## Build a release .zip and .dmg into dist/
	@Scripts/package.sh

clean: ## Remove build products
	@rm -rf .build build dist
