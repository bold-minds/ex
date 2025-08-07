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
START_TIME=$(date +%s)

# 🔧 Configuration
MODE=${1:-"local"}  # local|ci
COVERAGE_THRESHOLD=${COVERAGE_THRESHOLD:-80}
TEST_TIMEOUT=${TEST_TIMEOUT:-10m}
INTEGRATION_TAG=${INTEGRATION_TAG:-integration}

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

print_warning() {
    local message="$1"
    echo -e "${YELLOW}⚠️  Warning: $message${NC}"
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
    
    ((TOTAL_STEPS++))
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

# 🎨 Code formatting check
check_formatting() {
    local fmt_output
    fmt_output=$(go fmt ./... 2>&1)
    
    if [[ -n "$fmt_output" ]]; then
        echo "Code formatting issues found:"
        echo "$fmt_output"
        return 1
    fi
    
    print_info "Code is properly formatted! 💅"
    return 0
}

# 🔍 Comprehensive linting with golangci-lint (includes security, TODOs, style)
run_linting() {
    # Check if golangci-lint is available
    if ! command -v golangci-lint &> /dev/null; then
        print_warning "golangci-lint not found, installing..."
        if [[ "$MODE" == "ci" ]]; then
            # CI installation
            curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin v1.54.2
        else
            print_warning "Please install golangci-lint: https://golangci-lint.run/usage/install/"
            return 0  # Don't fail in local mode
        fi
    fi
    
    print_info "Running comprehensive linting (includes security scan, TODO detection, style checks)..."
    
    # Run linting with verbose output for better feedback
    if ! golangci-lint run --timeout=5m --verbose; then
        return 1
    fi
    
    print_info "Code passes all lint checks (security, TODOs, style, and more)! 🧹"
    return 0
}

# 🔧 Static analysis with go vet
run_static_analysis() {
    if ! go vet ./...; then
        return 1
    fi
    
    print_info "Static analysis passed! 🔬"
    return 0
}

# 🔒 Security scanning (handled by golangci-lint gosec linter)
# This function is now redundant since golangci-lint includes gosec
run_security_scan() {
    print_info "Security scanning is handled by golangci-lint (gosec linter) 🔒"
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
    local test_args="-race -timeout=$TEST_TIMEOUT"
    
    # Add coverage in CI mode
    if [[ "$MODE" == "ci" ]]; then
        test_args="$test_args -coverprofile=coverage.out -covermode=atomic"
    fi
    
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
        print_warning "No integration tests found in common directories (./test, ./tests, ./integration, ./e2e), skipping..."
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
    
    # Generate coverage report
    local coverage_percent
    coverage_percent=$(go tool cover -func=coverage.out | grep total | grep -oE '[0-9]+\.[0-9]+')
    
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
    echo -e "   ${BLUE}📝 Total:  $TOTAL_STEPS${NC}"
    echo -e "   ${YELLOW}⏱️  Time:   ${minutes}m ${seconds}s${NC}"
    
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# 🚀 Main execution pipeline
main() {
    print_header
    
    # Core validation steps (optimized to leverage golangci-lint)
    run_step "Environment Check" "check_environment" "🔍" || exit 1
    run_step "Code Formatting" "check_formatting" "🎨" || exit 1
    run_step "Comprehensive Linting" "run_linting" "🔍" || exit 1  # Includes security, TODOs, style
    run_step "Static Analysis" "run_static_analysis" "🔬" || exit 1
    run_step "Build Validation" "validate_build" "🏠️" || exit 1
    run_step "Unit Tests" "run_unit_tests" "🧪" || exit 1
    run_step "Integration Tests" "run_integration_tests" "🔗" || exit 1
    run_step "Coverage Check" "validate_coverage" "📊" || exit 1
    run_step "Documentation" "validate_documentation" "📚" || exit 1
    run_step "Final Validation" "final_validation" "🧹" || exit 1
    
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
