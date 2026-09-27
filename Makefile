SHELL := /bin/zsh

DESIGN_PORT ?= 4173
IOS_DESTINATION ?= platform=iOS Simulator,OS=latest,name=iPhone 17 Pro

.PHONY: preview-design generate check test test-backend test-ios

preview-design:
	@echo "Ascend Fit design preview: http://127.0.0.1:$(DESIGN_PORT)/Design/Handoff/ClaudeDesign/AscendFit%20-%20standalone.html"
	python3 -m http.server $(DESIGN_PORT) --bind 127.0.0.1 --directory .

generate:
	cp Backend/schema/workout-plan-v1.schema.json AscendFit/Resources/workout-plan-v1.schema.json
	cp Backend/examples/CHATGPT-WORKOUT-PROMPT.md AscendFit/Resources/CHATGPT-WORKOUT-PROMPT.txt
	xcodegen generate

check:
	npm --prefix Backend run check

test: test-backend test-ios

test-backend:
	npm --prefix Backend test

test-ios: generate
	xcodebuild test \
		-project AscendFit.xcodeproj \
		-scheme AscendFit \
		-destination '$(IOS_DESTINATION)' \
		-derivedDataPath .build/DerivedData \
		CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-
