# 🚀 Validation Script

This directory contains scripts for validating the codebase in both local development and CI/CD environments.

## 📋 validate.sh

The main validation script that runs a comprehensive pipeline to ensure code quality, correctness, and readiness for deployment.

### 🎯 Usage

```bash
# Local development mode (default)
./scripts/validate.sh

# CI/CD mode (stricter validation)
./scripts/validate.sh ci

# With custom coverage threshold
COVERAGE_THRESHOLD=85 ./scripts/validate.sh ci

# With custom test timeout
TEST_TIMEOUT=15m ./scripts/validate.sh
```

### 🔧 Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `COVERAGE_THRESHOLD` | `80` | Minimum test coverage percentage required |
| `TEST_TIMEOUT` | `10m` | Maximum time allowed for test execution |
| `INTEGRATION_TAG` | `integration` | Build tag for integration tests |
| `SKIP_INTEGRATION` | `false` | Flag to disable integration tests |

### 🏃‍♂️ Validation Steps

The script runs the following validation steps in order:

1. **🔍 Environment Check** - Verifies Go version (1.19+), git, and repository status
2. **🔍 Comprehensive Linting** - Runs `golangci-lint` with security scan, TODO detection, style checks, formatting, and static analysis (replaces separate fmt/vet steps)
3. **🏗️ Build Validation** - Validates clean builds and dependency management
4. **🧪 Unit Tests** - Runs all unit tests with race detection and timeout
5. **🔗 Integration Tests** - Executes integration test suite (can be skipped with `SKIP_INTEGRATION=true`)
6. **📊 Coverage Check** - Validates test coverage meets threshold using `go test -coverprofile`
7. **📚 Documentation** - Checks for missing README files in subdirectories
8. **🧹 Final Validation** - Ensures clean git status (CI mode only)
9. **🏷️ Badge Generation** - Generates JSON badge files for GitHub Actions (golangci-lint, coverage, go-version, last-updated, dependabot)

### 🎨 Features

- **🌈 Colorful Output** - Beautiful, emoji-rich terminal output with step-by-step progress
- **⚡ Fast Feedback** - Fails fast on first error for quick iteration
- **🔄 Mode Awareness** - Different behavior for local vs CI environments
- **📊 Detailed Reporting** - Comprehensive summary with timing, statistics, and step counts
- **🐧 Linux Compatible** - Fully compatible with Linux, macOS, and CI environments
- **🛠️ Tool Installation** - Auto-installs missing tools (golangci-lint) in CI mode
- **🏷️ Badge Generation** - Creates JSON badge files for GitHub Actions integration
- **⏭️ Flexible Execution** - Skip integration tests with `SKIP_INTEGRATION=true`
- **🎯 Streamlined Pipeline** - Consolidated linting eliminates redundant steps

### 🚨 Exit Codes

- `0` - All validations passed ✅
- `1` - One or more validations failed ❌

### 📋 Prerequisites

**Required:**
- Go 1.19+ 
- Git
- Linux/macOS/WSL environment

**Optional (auto-installed in CI):**
- `golangci-lint` - For comprehensive linting (includes security scanning, formatting, static analysis)
- `bc` - For coverage calculations
- `gh` (GitHub CLI) - For dynamic Dependabot badge status

### 🔧 CI/CD Integration

#### GitHub Actions Example
```yaml
- name: Run Validation Pipeline
  run: ./scripts/validate.sh ci
  env:
    COVERAGE_THRESHOLD: 85
    SKIP_INTEGRATION: true  # Skip integration tests in CI if needed
```

#### GitLab CI Example
```yaml
validate:
  script:
    - ./scripts/validate.sh ci
  variables:
    COVERAGE_THRESHOLD: "85"
    SKIP_INTEGRATION: "false"
```

### 🎯 Local Development

For local development, the script is more forgiving:
- Missing tools show warnings instead of failures
- Documentation issues are non-blocking
- Integration tests can be skipped with `SKIP_INTEGRATION=true`
- Badge generation continues even if GitHub CLI is missing

### 🚀 Quick Start

```bash
# Make sure you're in the project root
cd /path/to/your-go-project

# Run the validation (local mode)
./scripts/validate.sh

# Run in CI mode with custom settings
COVERAGE_THRESHOLD=85 SKIP_INTEGRATION=true ./scripts/validate.sh ci

# If everything passes, you'll see:
# 🎉 ALL VALIDATIONS PASSED! 🎉
# ✨ Your code is ready to ship! ✨
```

## 🤝 Contributing

When adding new validation steps:
1. Create a new function following the naming pattern `validate_*` or `run_*`
2. Add proper error handling and informative output
3. Include emojis for visual consistency 🎨
4. Test in both local and CI modes
5. Update this README with the new step
6. Consider if the step should be skippable with an environment variable

## 🐛 Troubleshooting

**Common Issues:**

- **Go version too old**: Upgrade to Go 1.19+
- **golangci-lint not found**: Install from https://golangci-lint.run/usage/install/ or let CI auto-install
- **Coverage below threshold**: Write more tests or lower `COVERAGE_THRESHOLD`
- **Integration tests failing**: Check test setup, database connections, or set `SKIP_INTEGRATION=true`
- **Git status dirty**: Commit or stash your changes before running in CI mode
- **Badge generation warnings**: Install GitHub CLI (`gh`) for dynamic Dependabot status
- **Linting failures**: Check `.golangci.yml` configuration and fix reported issues
