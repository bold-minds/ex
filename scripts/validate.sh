#!/bin/bash
# 🚀 Validation Script
# Comprehensive validation pipeline for local development and CI/CD
# Compatible with Linux, macOS, and CI environments

set -euo pipefail  # 💥 Fail fast on any error

# 🎨 Colors and emojis for beautiful output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 📊 Global counters
TOTAL_STEPS=0
PASSED_STEPS=0
FAILED_STEPS=0
SKIPPED_STEPS=0
WARNING_COUNT=0
START_TIME=$(date +%s)

# 🔧 Configuration
MODE=${1:-"local"}  # local|ci
COVERAGE_THRESHOLD=${COVERAGE_THRESHOLD:-80}
TEST_TIMEOUT=${TEST_TIMEOUT:-10m}
INTEGRATION_TAG=${INTEGRATION_TAG:-integration}
SKIP_INTEGRATION=${SKIP_INTEGRATION:-false}  # Flag to disable integration tests

# 🎯 Helper functions
print_header() {
    echo -e "\n${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}🚀 VALIDATION PIPELINE${NC}"
    echo -e "${PURPLE}Mode: ${CYAN}$MODE${PURPLE} | Coverage Threshold: ${CYAN}${COVERAGE_THRESHOLD}%${PURPLE} | Timeout: ${CYAN}$TEST_TIMEOUT${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_step() {
    local step_name="$1"
    local icon="$2"
    echo -e "${BLUE}$icon Running: ${CYAN}$step_name${NC}"
}

print_success() {
    local step_name="$1"
    echo -e "${GREEN}✅ $step_name: PASSED${NC}"
    ((PASSED_STEPS++))
}

print_failure() {
    local step_name="$1"
    local error_msg="$2"
    echo -e "${RED}❌ $step_name: FAILED${NC}"
    echo -e "${RED}   Error: $error_msg${NC}"
    ((FAILED_STEPS++))
}

print_skipped() {
    local step_name="$1"
    local reason="$2"
    echo -e "${YELLOW}⏭️  $step_name: SKIPPED${NC}"
    echo -e "${YELLOW}   Reason: $reason${NC}"
    ((SKIPPED_STEPS++))
}

print_warning() {
    local message="$1"
    echo -e "${YELLOW}⚠️  Warning: $message${NC}"
    ((WARNING_COUNT++))
}

print_info() {
    local message="$1"
    echo -e "${CYAN}ℹ️  Info: $message${NC}"
}

# 🏃‍♂️ Main step runner
run_step() {
    local step_name="$1"
    local step_function="$2"
    local icon="$3"
    local skip_reason="${4:-}"
    
    ((TOTAL_STEPS++))
    
    # Check if step should be skipped
    if [[ -n "$skip_reason" ]]; then
        print_skipped "$step_name" "$skip_reason"
        return 0
    fi
    
    print_step "$step_name" "$icon"
    
    if $step_function; then
        print_success "$step_name"
        return 0
    else
        print_failure "$step_name" "Check output above for details"
        return 1
    fi
}

# 🔍 Environment validation
check_environment() {
    # Check Go version
    if ! command -v go &> /dev/null; then
        echo "Go is not installed or not in PATH"
        return 1
    fi
    
    local go_version=$(go version | grep -oP 'go\K[0-9]+\.[0-9]+')
    local required_version="1.19"
    
    if [[ $(echo -e "$required_version\n$go_version" | sort -V | head -n1) != "$required_version" ]]; then
        echo "Go version $go_version is below required $required_version"
        return 1
    fi
    
    print_info "Go version: $go_version ✨"
    
    # Check git
    if ! command -v git &> /dev/null; then
        echo "Git is not installed or not in PATH"
        return 1
    fi
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir &> /dev/null; then
        echo "Not in a git repository"
        return 1
    fi
    
    print_info "Environment checks passed! 🌟"
    return 0
}

# 🔍 Comprehensive linting with golangci-lint (includes security, TODOs, style)
run_linting() {
    # Add GOPATH/bin to PATH if not already there
    local gopath_bin="$(go env GOPATH)/bin"
    if [[ ":$PATH:" != *":$gopath_bin:"* ]]; then
        export PATH="$gopath_bin:$PATH"
        print_info "Added $gopath_bin to PATH"
    fi
    
    # Check if golangci-lint is available
    if ! command -v golangci-lint >/dev/null 2>&1; then
        print_warning "golangci-lint not found, installing latest version..."
        # Use the recommended installation method for latest version
        if ! go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest; then
            echo "Failed to install golangci-lint"
            echo "Try manual installation: https://golangci-lint.run/welcome/install/"
            return 1
        fi
        print_info "golangci-lint installed successfully"
    fi
    
    # Run golangci-lint
    local lint_output
    lint_output=$(golangci-lint run --timeout=$TEST_TIMEOUT ./... 2>&1)
    local lint_exit_code=$?
    
    if [[ $lint_exit_code -ne 0 ]]; then
        echo "Linting failed:"
        echo "$lint_output"
        return 1
    fi
    
    print_info "Code passes all lint checks (security, TODOs, style, and more)! 🧹"
    return 0
}

# 🏗️ Build validation
validate_build() {
    # Clean build
    print_info "Cleaning build cache..."
    go clean -cache
    
    # Build all packages
    if ! go build ./...; then
        return 1
    fi
    
    # Check for tidy modules
    print_info "Checking module dependencies..."
    
    # Save current state
    local mod_before mod_sum_before
    mod_before=$(cat go.mod 2>/dev/null || echo "")
    mod_sum_before=$(cat go.sum 2>/dev/null || echo "")
    
    go mod tidy
    
    # Check if go mod tidy made changes
    local mod_after mod_sum_after
    mod_after=$(cat go.mod 2>/dev/null || echo "")
    mod_sum_after=$(cat go.sum 2>/dev/null || echo "")
    
    if [[ "$mod_before" != "$mod_after" ]] || [[ "$mod_sum_before" != "$mod_sum_after" ]]; then
        if [[ "$MODE" == "ci" ]]; then
            echo "go.mod or go.sum has uncommitted changes after 'go mod tidy'"
            echo "Please run 'go mod tidy' and commit the changes before CI"
            return 1
        else
            print_info "go mod tidy updated dependencies (this is normal in local development)"
        fi
    fi
    
    print_info "Build successful and dependencies are tidy! 🏗️"
    return 0
}

# 🧪 Unit tests
run_unit_tests() {
    # Always generate coverage for badge generation
    local test_args="-race -timeout=$TEST_TIMEOUT -coverprofile=coverage.out -covermode=atomic"
    
    print_info "Running unit tests with race detection..."
    
    if ! go test $test_args ./...; then
        return 1
    fi
    
    print_info "All unit tests passed! 🧪"
    return 0
}

# 🔗 Integration tests
run_integration_tests() {
    print_info "Running integration tests..."
    
    # Check for integration tests in common locations
    local integration_dirs=("./test" "./tests" "./integration" "./e2e")
    local found_tests=false
    
    for test_dir in "${integration_dirs[@]}"; do
        if [[ -d "$test_dir" ]] && find "$test_dir" -name "*_test.go" -type f | grep -q .; then
            found_tests=true
            print_info "Found integration tests in $test_dir"
            
            local test_args="-timeout=$TEST_TIMEOUT -tags=$INTEGRATION_TAG"
            if ! go test $test_args "$test_dir/..."; then
                return 1
            fi
        fi
    done
    
    if [[ "$found_tests" == "false" ]]; then
        print_warning "No integration tests found (this is normal for libraries), skipping..."
        return 0
    fi
    
    print_info "Integration tests passed! 🔗"
    return 0
}

# 📊 Coverage validation
validate_coverage() {
    if [[ ! -f "coverage.out" ]]; then
        print_warning "No coverage file found, skipping coverage check"
        return 0
    fi
    
    print_info "Analyzing test coverage..."
    
    # Get main package coverage (from test output, not total which includes examples)
    local coverage_percent
    # Extract main package coverage from the test output (e.g., "coverage: 84.7% of statements")
    if [[ -f "coverage.out" ]]; then
        # Try to get main package coverage from go test output or coverage file
        coverage_percent=$(go test -coverprofile=temp_coverage.out ./. 2>/dev/null | grep "coverage:" | grep -oE '[0-9]+\.[0-9]+%' | sed 's/%//' | head -1)
        rm -f temp_coverage.out 2>/dev/null
        
        # If that fails, fall back to total coverage
        if [[ -z "$coverage_percent" ]]; then
            coverage_percent=$(go tool cover -func=coverage.out | grep total | grep -oE '[0-9]+\.[0-9]+')
        fi
    else
        coverage_percent="0.0"
    fi
    
    print_info "Current coverage: ${coverage_percent}%"
    
    # Check threshold
    if (( $(echo "$coverage_percent < $COVERAGE_THRESHOLD" | bc -l) )); then
        echo "Coverage ${coverage_percent}% is below threshold ${COVERAGE_THRESHOLD}%"
        return 1
    fi
    
    # Generate HTML report in CI mode
    if [[ "$MODE" == "ci" ]]; then
        go tool cover -html=coverage.out -o coverage.html
        print_info "HTML coverage report generated: coverage.html"
    fi
    
    print_info "Coverage meets threshold! 📊"
    return 0
}

# 📚 Documentation validation
validate_documentation() {
    print_info "Checking documentation..."
    
    # Check for main README.md in project root
    if [[ ! -f "README.md" ]]; then
        print_warning "No README.md found in project root"
        if [[ "$MODE" == "ci" ]]; then
            echo "README.md is required for CI validation"
            return 1
        fi
    else
        print_info "Project README.md found ✓"
    fi
    
    # Optional: Check for README.md in common package directories (if they exist)
    local missing_readme=0
    for dir in internal/*/ pkg/*/ cmd/*/; do
        if [[ -d "$dir" && ! -f "${dir}README.md" ]]; then
            print_warning "Missing README.md in $dir (optional)"
            # Don't increment counter - this is just informational
        fi
    done
    
    print_info "Documentation validation completed! 📚"
    return 0
}


# 🧹 Final cleanup and validation
final_validation() {
    print_info "Running final validations..."
    
    # Check git status
    if [[ "$MODE" == "ci" ]]; then
        if ! git diff --exit-code; then
            echo "Working directory has uncommitted changes"
            return 1
        fi
        
        if ! git diff --cached --exit-code; then
            echo "Staging area has uncommitted changes"
            return 1
        fi
    fi
    
    print_info "Final validation completed! 🧹"
    return 0
}

# 🏷️ Generate badge JSON files for debugging and CI compatibility
generate_badges() {
    print_info "Generating badge JSON files..."
    
    # Create badges directory in .github
    mkdir -p .github/badges
    
    # Add GOPATH/bin to PATH if not already there (for golangci-lint)
    local gopath_bin="$(go env GOPATH)/bin"
    if [[ ":$PATH:" != *":$gopath_bin:"* ]]; then
        export PATH="$gopath_bin:$PATH"
    fi
    
    # Generate golangci-lint badge
    if command -v golangci-lint >/dev/null 2>&1; then
        print_info "Running golangci-lint with JSON output for badge generation..."
        
        # Run golangci-lint with JSON output (allow failure to capture issues)
        local lint_json_output
        lint_json_output=$(golangci-lint run --out-format json ./... 2>/dev/null || echo '{"Issues":null}')
        
        # Save raw output for debugging
        echo "$lint_json_output" > .github/badges/lint-results.json
        
        # Count issues (handle both null and empty array cases)
        local issues_count
        if command -v jq >/dev/null 2>&1; then
            issues_count=$(echo "$lint_json_output" | jq '.Issues | length // 0' 2>/dev/null || echo "0")
        else
            # Fallback without jq - count occurrences of issue objects
            if [[ "$lint_json_output" == *'"Issues":null'* ]] || [[ "$lint_json_output" == *'"Issues":[]'* ]]; then
                issues_count=0
            else
                # Simple count of issue entries (rough approximation)
                issues_count=$(echo "$lint_json_output" | grep -o '"Pos":' | wc -l || echo "0")
            fi
        fi
        
        # Generate golangci-lint badge JSON
        if [[ "$issues_count" -eq 0 ]]; then
            echo '{"schemaVersion":1,"label":"golangci-lint","message":"0 issues","color":"brightgreen"}' > .github/badges/golangci-lint.json
            print_info "✅ golangci-lint badge: 0 issues (green)"
        else
            echo '{"schemaVersion":1,"label":"golangci-lint","message":"'$issues_count' issues","color":"red"}' > .github/badges/golangci-lint.json
            print_info "❌ golangci-lint badge: $issues_count issues (red)"
        fi
    else
        # Fallback if golangci-lint not available
        echo '{"schemaVersion":1,"label":"golangci-lint","message":"not available","color":"lightgrey"}' > .github/badges/golangci-lint.json
        print_warning "golangci-lint not available, generated fallback badge"
    fi
    
    # Generate coverage badge (if coverage file exists)
    if [[ -f "coverage.out" ]]; then
        local coverage_percent
        # Use the same logic as coverage validation to get main package coverage
        coverage_percent=$(go test -coverprofile=temp_coverage.out ./. 2>/dev/null | grep "coverage:" | grep -oE '[0-9]+\.[0-9]+%' | sed 's/%//' | head -1)
        rm -f temp_coverage.out 2>/dev/null
        
        # If that fails, fall back to total coverage
        if [[ -z "$coverage_percent" ]]; then
            coverage_percent=$(go tool cover -func=coverage.out 2>/dev/null | grep total | awk '{print $3}' | sed 's/%//' || echo "0")
        fi
        
        # Determine color based on coverage
        local coverage_color="red"
        if (( $(echo "$coverage_percent >= 80" | bc -l 2>/dev/null || echo "0") )); then
            coverage_color="brightgreen"
        elif (( $(echo "$coverage_percent >= 60" | bc -l 2>/dev/null || echo "0") )); then
            coverage_color="yellow"
        fi
        
        echo '{"schemaVersion":1,"label":"coverage","message":"'$coverage_percent'%","color":"'$coverage_color'"}' > .github/badges/coverage.json
        print_info "📊 Coverage badge: $coverage_percent% ($coverage_color)"
    else
        echo '{"schemaVersion":1,"label":"coverage","message":"no data","color":"lightgrey"}' > .github/badges/coverage.json
        print_info "📊 Coverage badge: no data available"
    fi
    
    # Generate Go version badge
    local go_version
    go_version=$(go version | grep -oE 'go[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
    echo '{"schemaVersion":1,"label":"Go","message":"'$go_version'","color":"00ADD8"}' > .github/badges/go-version.json
    print_info "🐹 Go version badge: $go_version (Go blue)"
    
    # Generate last updated badge (shows when validation last ran)
    LAST_COMMIT_DATE=$(git log -1 --format=%cd --date=short)
    echo '{"schemaVersion":1,"label":"last updated","message":"'$LAST_COMMIT_DATE'","color":"teal"}' > .github/badges/last-updated.json
    
    # Comprehensive security badge (Dependabot + Code Scanning)
    if command -v gh >/dev/null 2>&1; then
        DEPENDABOT_ALERTS=$(gh api repos/bold-minds/id/dependabot/alerts --jq 'length' 2>/dev/null || echo "0")
        CODE_SCANNING_ALERTS=$(gh api repos/bold-minds/id/code-scanning/alerts --jq '[.[] | select(.state == "open")] | length' 2>/dev/null || echo "0")
        TOTAL_ALERTS=$((DEPENDABOT_ALERTS + CODE_SCANNING_ALERTS))
        OPEN_PRS=$(gh pr list --author "app/dependabot" --state open --json number --jq 'length' 2>/dev/null || echo "0")
        
        if [[ $TOTAL_ALERTS -gt 0 ]]; then
            if [[ $DEPENDABOT_ALERTS -gt 0 && $CODE_SCANNING_ALERTS -gt 0 ]]; then
                echo '{"schemaVersion":1,"label":"security","message":"'$TOTAL_ALERTS' alerts","color":"red"}' > .github/badges/dependabot.json
                print_info "🔴 Security badge: $TOTAL_ALERTS total alerts ($DEPENDABOT_ALERTS dependency + $CODE_SCANNING_ALERTS code scanning)"
            elif [[ $DEPENDABOT_ALERTS -gt 0 ]]; then
                echo '{"schemaVersion":1,"label":"security","message":"'$DEPENDABOT_ALERTS' dependency alerts","color":"red"}' > .github/badges/dependabot.json
                print_info "🔴 Security badge: $DEPENDABOT_ALERTS dependency alerts (red)"
            else
                echo '{"schemaVersion":1,"label":"security","message":"'$CODE_SCANNING_ALERTS' code alerts","color":"red"}' > .github/badges/dependabot.json
                print_info "🔴 Security badge: $CODE_SCANNING_ALERTS code scanning alerts (red)"
            fi
        elif [[ $OPEN_PRS -gt 0 ]]; then
            echo '{"schemaVersion":1,"label":"dependabot","message":"'$OPEN_PRS' updates","color":"blue"}' > .github/badges/dependabot.json
            print_info "🔵 Security badge: $OPEN_PRS pending updates (blue)"
        else
            echo '{"schemaVersion":1,"label":"security","message":"all clear","color":"brightgreen"}' > .github/badges/dependabot.json
            print_info "🟢 Security badge: all clear (green)"
        fi
    else
        echo '{"schemaVersion":1,"label":"security","message":"gh required","color":"yellow"}' > .github/badges/dependabot.json
        print_info "⚠️  Security badge: GitHub CLI required for dynamic status"
    fi
    
    print_info "Badge JSON files generated in ./.github/badges/ directory 🏷️"
    print_info "Files created: golangci-lint.json, coverage.json, go-version.json, last-updated.json, dependabot.json, lint-results.json"
    
    return 0
}

# 📈 Performance summary
print_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    echo -e "\n${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}📈 VALIDATION SUMMARY${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [[ $FAILED_STEPS -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL VALIDATIONS PASSED! 🎉${NC}"
        echo -e "${GREEN}✨ Your code is ready to ship! ✨${NC}"
    else
        echo -e "${RED}💥 VALIDATION FAILED! 💥${NC}"
        echo -e "${RED}❌ Please fix the issues above before proceeding${NC}"
    fi
    
    echo -e "\n${CYAN}📊 Statistics:${NC}"
    echo -e "   ${GREEN}✅ Passed: $PASSED_STEPS${NC}"
    echo -e "   ${RED}❌ Failed: $FAILED_STEPS${NC}"
    echo -e "   ${YELLOW}⏭️  Skipped: $SKIPPED_STEPS${NC}"
    echo -e "   ${YELLOW}⚠️  Warnings: $WARNING_COUNT${NC}"
    echo -e "   ${BLUE}📝 Total:  $TOTAL_STEPS${NC}"
    echo -e "   ${YELLOW}⏱️  Time:   ${minutes}m ${seconds}s${NC}"
    
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# 🚀 Main execution pipeline
main() {
    print_header
    
    # Core validation steps (streamlined - no overlap with golangci-lint)
    run_step "Environment Check" "check_environment" "🔍" || exit 1
    run_step "Comprehensive Linting" "run_linting" "🔍" || exit 1  # golangci-lint handles: formatting, static analysis, security, style
    run_step "Build Validation" "validate_build" "🏠️" || exit 1
    run_step "Unit Tests" "run_unit_tests" "🧪" || exit 1
    
    # Integration tests - can be skipped with SKIP_INTEGRATION=true
    local integration_skip_reason=""
    if [[ "$SKIP_INTEGRATION" == "true" ]]; then
        integration_skip_reason="SKIP_INTEGRATION flag set"
    fi
    run_step "Integration Tests" "run_integration_tests" "🔗" "$integration_skip_reason" || exit 1
    
    run_step "Coverage Check" "validate_coverage" "📊" || exit 1
    run_step "Documentation" "validate_documentation" "📚" || exit 1
    run_step "Final Validation" "final_validation" "🧹" || exit 1
    run_step "Badge Generation" "generate_badges" "🏷️" || exit 1
    
    print_summary
    
    # Exit with appropriate code
    if [[ $FAILED_STEPS -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# 🎬 Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
