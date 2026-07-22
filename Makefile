.DEFAULT_GOAL := help
SCHEME  := SoundView
PROJECT := SoundView.xcodeproj

# Resolve the first available iPhone simulator on this machine (robust across
# Xcode versions / CI runners) instead of hardcoding a device name.
PICK_SIM := xcrun simctl list devices available -j | python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; print(next(x['udid'] for k,v in d.items() if 'iOS' in k for x in v if x.get('isAvailable') and 'iPhone' in x['name']))"

.PHONY: help bootstrap generate models lint build test open release-models clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS=":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

bootstrap: models generate ## First-time setup: fetch models + generate the Xcode project
	@echo "✓ Ready. Open with: make open"

generate: ## Regenerate SoundView.xcodeproj from project.yml (XcodeGen)
	xcodegen generate

models: ## Download the Demucs Core ML models from GitHub Releases
	./tools/fetch_models.sh

lint: ## Run SwiftLint
	swiftlint lint

build: generate ## Build the app for the iOS Simulator
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) \
		-destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO

test: generate ## Run the unit + integration test suite
	@UDID=$$($(PICK_SIM)); echo "Simulator: $$UDID"; \
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) \
		-destination "id=$$UDID" -only-testing:SoundViewTests CODE_SIGNING_ALLOWED=NO

open: generate ## Open the project in Xcode
	open $(PROJECT)

release-models: ## Regenerate models locally and publish a GitHub Release (needs gh + Python)
	cd tools && python3 -m venv .venv && . .venv/bin/activate \
		&& pip install -q "torch" "coremltools>=8.0" "demucs" "soundfile" "numpy" \
		&& python convert_htdemucs.py
	cd SoundView/Resources && zip -r -q ../../htdemucs_ft_coreml.zip ./*.mlpackage
	gh release create models-v1 htdemucs_ft_coreml.zip \
		--title "Demucs Core ML models (models-v1)" \
		--notes "htdemucs_ft → Core ML. Meta Demucs weights, CC-BY-NC 4.0."

clean: ## Remove build artifacts and generated project
	rm -rf SoundView.xcodeproj DerivedData TestResults.xcresult htdemucs_ft_coreml.zip*
