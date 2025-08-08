# Bemo iOS App - Development Makefile

.PHONY: help
help: ## Show this help message
	@echo "Bemo iOS Development Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: setup
setup: ## Install development dependencies
	@echo "Installing SwiftLint via Homebrew..."
	@brew list swiftlint &>/dev/null || brew install swiftlint
	@echo "Installing pre-commit..."
	@brew list pre-commit &>/dev/null || brew install pre-commit
	@echo "Setting up git hooks..."
	@pre-commit install
	@echo "✅ Development environment setup complete!"

.PHONY: lint
lint: ## Run SwiftLint on the project
	@echo "Running SwiftLint..."
	@swiftlint --config .swiftlint.yml

.PHONY: lint-fix
lint-fix: ## Auto-fix SwiftLint violations where possible
	@echo "Auto-fixing SwiftLint violations..."
	@swiftlint --config .swiftlint.yml --fix

.PHONY: analyze
analyze: ## Run static analysis (requires Xcode)
	@echo "Running static analysis..."
	@xcodebuild -project Bemo.xcodeproj -scheme Bemo -configuration Debug analyze -quiet

.PHONY: build
build: ## Build the project
	@echo "Building Bemo..."
	@xcodebuild -project Bemo.xcodeproj -scheme Bemo -configuration Debug build -quiet

.PHONY: test
test: ## Run tests
	@echo "Running tests..."
	@xcodebuild -project Bemo.xcodeproj -scheme Bemo -destination 'platform=iOS Simulator,name=iPhone 15' test -quiet

.PHONY: clean
clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	@xcodebuild -project Bemo.xcodeproj -scheme Bemo clean -quiet
	@rm -rf ~/Library/Developer/Xcode/DerivedData/Bemo-*

.PHONY: check
check: lint analyze ## Run all checks (lint + analyze)
	@echo "✅ All checks passed!"

.PHONY: fix-warnings
fix-warnings: ## Fix common Swift warnings automatically
	@echo "Fixing unused variable warnings..."
	@find Bemo -name "*.swift" -type f -exec sed -i '' 's/let \([a-zA-Z_][a-zA-Z0-9_]*\) = .* \/\/ never used/_ = /g' {} \;
	@echo "Fixing var to let warnings..."
	@find Bemo -name "*.swift" -type f -exec sed -i '' 's/var \([a-zA-Z_][a-zA-Z0-9_]*\) = \(.*\) \/\/ never mutated/let \1 = \2/g' {} \;
	@echo "Run 'make lint-fix' to fix more issues"

.PHONY: stats
stats: ## Show project statistics
	@echo "📊 Project Statistics:"
	@echo ""
	@echo "Swift files: $$(find Bemo -name '*.swift' | wc -l | tr -d ' ')"
	@echo "Lines of code: $$(find Bemo -name '*.swift' -exec wc -l {} \; | awk '{sum += $$1} END {print sum}')"
	@echo "TODO comments: $$(grep -r "TODO:" Bemo --include="*.swift" | wc -l | tr -d ' ')"
	@echo "FIXME comments: $$(grep -r "FIXME:" Bemo --include="*.swift" | wc -l | tr -d ' ')"

.PHONY: pre-commit
pre-commit: lint build test ## Run pre-commit checks
	@echo "✅ Ready to commit!"