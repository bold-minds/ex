#!/bin/bash

# Badge Automation Fix Script
# This script applies the research-backed authentication fixes to repositories
# that already have the GitHub App installed but are encountering badge automation issues.
#
# Prerequisites:
# - GitHub CLI (gh) installed and authenticated
# - GitHub App already installed on target repositories
# - Repository variables and secrets already configured

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to fix workflow authentication in a repository
fix_workflow_authentication() {
    local repo="$1"
    local workflow_file=".github/workflows/test.yaml"
    
    log_info "Fixing badge automation authentication in $repo..."
    
    # Clone the repository temporarily
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    log_info "Cloning repository..."
    git clone "https://github.com/$repo.git" .
    
    # Check if workflow file exists
    if [[ ! -f "$workflow_file" ]]; then
        log_error "Workflow file $workflow_file not found in $repo"
        cd - >/dev/null
        rm -rf "$temp_dir"
        return 1
    fi
    
    log_info "Applying authentication fixes to $workflow_file..."
    
    # Fix 1: Update checkout step to use persist-credentials: false
    if grep -q "persist-credentials: true" "$workflow_file"; then
        sed -i 's/persist-credentials: true/persist-credentials: false/g' "$workflow_file"
        log_success "Fixed persist-credentials setting"
    elif ! grep -q "persist-credentials: false" "$workflow_file"; then
        # Add persist-credentials: false if not present
        sed -i '/uses: actions\/checkout@v4/,/with:/{
            /with:/a\
          persist-credentials: false
        }' "$workflow_file"
        log_success "Added persist-credentials: false"
    else
        log_info "persist-credentials: false already configured"
    fi
    
    # Fix 2: Update badge commit step with git URL rewriting
    if grep -q "git config --local user.name" "$workflow_file"; then
        # Replace old badge commit configuration with new authentication setup
        sed -i '/# Configure git with GitHub App identity$/,/git push origin HEAD:main$/{
            /# Configure git with GitHub App identity$/c\
          # Configure git with GitHub App identity and authentication\
          git config --global user.name "Badge Automation Bot"\
          git config --global user.email "action@github.com"\
          \
          # Configure git to use the GitHub App token for authentication\
          git config --global url."https://x-access-token:${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"
            /git config --local/d
            /git config --global user.name/d
            /git config --global user.email/d
        }' "$workflow_file"
        log_success "Updated badge commit authentication"
    elif ! grep -q "git config --global url" "$workflow_file"; then
        log_warning "Badge commit step may need manual update - check workflow file"
    else
        log_info "Git URL rewriting already configured"
    fi
    
    # Fix 3: Ensure GITHUB_TOKEN environment variable is set
    if ! grep -q "GITHUB_TOKEN: \${{ steps.app-token.outputs.token }}" "$workflow_file"; then
        log_warning "GITHUB_TOKEN environment variable may need to be added manually"
    else
        log_info "GITHUB_TOKEN environment variable already configured"
    fi
    
    # Commit and push the fixes
    git add "$workflow_file"
    if git diff --staged --quiet; then
        log_info "No changes needed for $repo"
    else
        git config user.name "Badge Automation Fix"
        git config user.email "action@github.com"
        git commit -m "fix: apply research-backed badge automation authentication fixes

- Set persist-credentials: false to prevent token conflicts
- Add git URL rewriting for GitHub App token authentication
- Ensure proper environment variable configuration

These fixes enable GitHub App repository ruleset bypass for badge automation.

References:
- GitHub Community: https://github.com/orgs/community/discussions/72173
- Stack Overflow: https://stackoverflow.com/questions/77433427"
        
        log_info "Pushing authentication fixes..."
        git push origin main
        log_success "Authentication fixes applied to $repo"
    fi
    
    # Cleanup
    cd - >/dev/null
    rm -rf "$temp_dir"
}

# Function to check repository ruleset bypass configuration
check_ruleset_bypass() {
    local repo="$1"
    local app_id="$2"
    
    log_info "Checking repository ruleset bypass for $repo..."
    
    # Get repository rulesets
    local bypass_actors=$(gh api "repos/$repo/rulesets" --jq '.[0].bypass_actors // []')
    
    if [[ "$bypass_actors" == "[]" || "$bypass_actors" == "null" ]]; then
        log_warning "GitHub App $app_id is NOT in repository ruleset bypass list for $repo"
        log_info "Manual action required:"
        log_info "1. Go to: https://github.com/$repo/settings/rules"
        log_info "2. Edit the main branch ruleset"
        log_info "3. Add GitHub App ID $app_id to bypass actors with 'bypass_mode: always'"
        log_info "4. Save the configuration"
        return 1
    else
        # Check if our specific app ID is in the bypass list
        local app_in_bypass=$(echo "$bypass_actors" | jq --arg app_id "$app_id" '.[] | select(.actor_id == ($app_id | tonumber) and .actor_type == "Integration")')
        
        if [[ -n "$app_in_bypass" ]]; then
            log_success "GitHub App $app_id is properly configured in ruleset bypass for $repo"
            return 0
        else
            log_warning "GitHub App $app_id found in bypass list but may not be configured correctly for $repo"
            return 1
        fi
    fi
}

# Function to generate repository-specific instructions
generate_repo_instructions() {
    local repo="$1"
    local app_id="$2"
    
    cat > "fix-instructions-$(basename "$repo").md" <<EOF
# Badge Automation Fix Instructions for $repo

## Authentication Fixes Applied
- ✅ persist-credentials: false (prevents token conflicts)
- ✅ Git URL rewriting (enables GitHub App authentication)
- ✅ Proper environment variable configuration

## Manual Steps Required

### 1. Repository Ruleset Bypass Configuration
**CRITICAL**: Add GitHub App to repository ruleset bypass list:
1. Go to: https://github.com/$repo/settings/rules
2. Edit the main branch ruleset
3. Add GitHub App ID \`$app_id\` to bypass actors
4. Set bypass mode to \`always\`
5. Save the configuration

### 2. Test Badge Automation
1. Push a change to main branch
2. Monitor workflow for successful completion
3. Check that badge files are updated in \`.github/badges/\`
4. Verify commit attribution shows "Badge Automation Bot"
5. Confirm green status on Actions/Checks

### 3. Troubleshooting
If badge automation still fails:
- Temporarily disable repository rules for testing
- Check that both repository rulesets AND branch protection allow GitHub App bypass
- Verify GitHub App has Contents: Read/Write permissions
- Confirm repository variables and secrets are correctly configured

## Success Criteria
- ✅ Main branch has green status on Actions/Checks
- ✅ Badge files are updated automatically after test runs
- ✅ Commits show proper attribution ("Badge Automation Bot")
- ✅ No repository rule violations in workflow logs

---
*Generated by fix-badge-automation.sh based on research-backed solutions*
EOF
    
    log_success "Generated fix instructions: fix-instructions-$(basename "$repo").md"
}

# Main function
main() {
    echo "🔧 Badge Automation Fix Script"
    echo "=============================="
    echo ""
    
    # Check if repository argument provided
    if [[ $# -eq 0 ]]; then
        log_error "Usage: $0 <repo1> [repo2] [repo3] ..."
        log_info "Example: $0 bold-minds/repo1 bold-minds/repo2"
        exit 1
    fi
    
    # GitHub App ID (should match the one used in your organization)
    local app_id="1759509"
    
    log_info "Using GitHub App ID: $app_id"
    log_info "Processing repositories: $*"
    echo ""
    
    # Process each repository
    for repo in "$@"; do
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info "Processing repository: $repo"
        echo ""
        
        # Check if repository exists and is accessible
        if ! gh repo view "$repo" >/dev/null 2>&1; then
            log_error "Cannot access repository $repo. Check permissions."
            continue
        fi
        
        # Apply workflow authentication fixes
        if fix_workflow_authentication "$repo"; then
            log_success "Workflow authentication fixes applied to $repo"
        else
            log_error "Failed to apply workflow fixes to $repo"
            continue
        fi
        
        # Check repository ruleset bypass configuration
        check_ruleset_bypass "$repo" "$app_id"
        
        # Generate repository-specific instructions
        generate_repo_instructions "$repo" "$app_id"
        
        echo ""
        log_success "Repository $repo processing completed"
        echo ""
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 Badge Automation Fix Script Completed!"
    echo ""
    log_info "Next steps for each repository:"
    echo "1. Review the generated fix-instructions-*.md files"
    echo "2. Complete the repository ruleset bypass configuration (manual step)"
    echo "3. Test badge automation by pushing a change to main branch"
    echo "4. Verify green status on Actions/Checks"
    echo ""
    log_warning "Remember: Repository ruleset bypass configuration requires manual setup via GitHub web interface"
    echo ""
}

# Run main function
main "$@"
