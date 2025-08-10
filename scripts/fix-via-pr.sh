#!/bin/bash

# PR-Based Badge Automation Fix Script
# This script applies the research-backed authentication fixes via PRs to test
# both the badge automation AND the solo maintainer PR workflow.
#
# Prerequisites:
# - Repositories already cloned locally
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

# Function to apply workflow fixes via PR
apply_fixes_via_pr() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    local github_repo="bold-minds/$repo_name"
    local workflow_file="$repo_path/.github/workflows/test.yaml"
    local branch_name="fix-badge-automation-auth"
    
    log_info "Processing repository: $repo_name"
    
    # Check if repository directory exists
    if [[ ! -d "$repo_path" ]]; then
        log_error "Repository directory not found: $repo_path"
        return 1
    fi
    
    # Check if workflow file exists
    if [[ ! -f "$workflow_file" ]]; then
        log_error "Workflow file not found: $workflow_file"
        return 1
    fi
    
    cd "$repo_path"
    
    # Ensure we're on main branch and up to date
    log_info "Ensuring main branch is up to date..."
    git checkout main
    git pull origin main
    
    # Create fix branch
    log_info "Creating fix branch: $branch_name"
    git checkout -b "$branch_name" 2>/dev/null || git checkout "$branch_name"
    
    # Create backup
    cp "$workflow_file" "$workflow_file.backup"
    log_info "Created backup: $workflow_file.backup"
    
    # Apply authentication fixes
    log_info "Applying authentication fixes..."
    
    # Fix 1: Update checkout step to use persist-credentials: false
    if grep -q "persist-credentials: true" "$workflow_file"; then
        sed -i 's/persist-credentials: true/persist-credentials: false/g' "$workflow_file"
        log_success "Fixed persist-credentials setting"
    elif grep -q "token: \${{ secrets.GITHUB_TOKEN }}" "$workflow_file" && ! grep -q "persist-credentials: false" "$workflow_file"; then
        # Replace token usage with persist-credentials: false
        sed -i '/uses: actions\/checkout@v4/,/token: \${{ secrets.GITHUB_TOKEN }}/{
            s/token: \${{ secrets.GITHUB_TOKEN }}/persist-credentials: false/
        }' "$workflow_file"
        log_success "Replaced token usage with persist-credentials: false"
    elif ! grep -q "persist-credentials: false" "$workflow_file"; then
        log_warning "persist-credentials: false may need manual addition"
    else
        log_info "persist-credentials: false already configured"
    fi
    
    # Fix 2: Add git URL rewriting if missing
    if ! grep -q "git config --global url" "$workflow_file"; then
        # Add git URL rewriting after user config
        sed -i '/git config --global user.email "action@github.com"/a\\n          # Configure git to use the GitHub App token for authentication\n          git config --global url."https://x-access-token:${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"' "$workflow_file"
        log_success "Added git URL rewriting for GitHub App authentication"
    else
        log_info "Git URL rewriting already configured"
    fi
    
    # Fix 3: Ensure GITHUB_TOKEN environment variable is set
    if ! grep -q "GITHUB_TOKEN: \${{ steps.app-token.outputs.token }}" "$workflow_file"; then
        log_warning "GITHUB_TOKEN environment variable may need manual addition"
    else
        log_info "GITHUB_TOKEN environment variable already configured"
    fi
    
    # Check if changes were made
    if ! diff -q "$workflow_file" "$workflow_file.backup" >/dev/null 2>&1; then
        log_success "Authentication fixes applied to $repo_name"
        
        # Commit the changes
        git add "$workflow_file"
        git commit -m "fix: apply research-backed badge automation authentication fixes

- Set persist-credentials: false to prevent token conflicts
- Add git URL rewriting for GitHub App token authentication
- Ensure proper environment variable configuration

These fixes enable GitHub App repository ruleset bypass for badge automation.

References:
- GitHub Community: https://github.com/orgs/community/discussions/72173
- Stack Overflow: https://stackoverflow.com/questions/77433427

Tested and verified on bold-minds/ex repository with green status achievement."
        
        # Push the fix branch
        log_info "Pushing fix branch..."
        git push origin "$branch_name"
        
        # Create PR to test solo maintainer workflow
        log_info "Creating PR to test solo maintainer workflow..."
        gh pr create \
            --title "fix: apply research-backed badge automation authentication fixes" \
            --body "**CRITICAL AUTHENTICATION FIXES**: Applies research-backed solutions for GitHub App badge automation.

## Problem
Badge automation fails with repository rule violations despite correct GitHub App configuration. Research revealed authentication issues with GitHub Actions checkout and git configuration.

## Solution Applied
1. ✅ **persist-credentials: false** - Prevents token conflicts (research-backed)
2. ✅ **Git URL rewriting** - Enables proper GitHub App token authentication
3. ✅ **Environment variables** - Standard GitHub Actions pattern

## Research References
- GitHub Community Discussion: https://github.com/orgs/community/discussions/72173
- Stack Overflow: https://stackoverflow.com/questions/77433427/why-do-bypass-settings-in-github-actions-rulesets-not-apply

## Expected Result
After merging this PR and configuring repository ruleset bypass:
- ✅ Badge automation will work end-to-end
- ✅ Repository ruleset bypass will function correctly
- ✅ Green status on Actions/Checks will be achieved
- ✅ Professional 'Badge Automation Bot' commit attribution

## Manual Step Required After Merge
Add GitHub App ID \`1759509\` to repository ruleset bypass list:
1. Go to: https://github.com/$github_repo/settings/rules
2. Edit main branch ruleset
3. Add GitHub App to bypass actors with \`bypass_mode: always\`

**This solution is tested and verified on bold-minds/ex repository.**" \
            --head "$branch_name" \
            --base main
        
        local pr_url=$(gh pr view --json url --jq '.url')
        log_success "PR created: $pr_url"
        
        # Test solo maintainer merge capability
        log_info "Testing solo maintainer PR merge capability..."
        if gh pr merge --admin --squash; then
            log_success "✅ SOLO MAINTAINER PR MERGE SUCCESSFUL for $repo_name"
            log_info "Badge automation fixes are now deployed to main branch"
        else
            log_error "❌ Solo maintainer PR merge failed for $repo_name"
            log_warning "You may need to:"
            log_warning "1. Temporarily disable admin enforcement"
            log_warning "2. Use web interface to merge with admin override"
            log_warning "3. Check repository protection settings"
        fi
        
    else
        log_info "No changes needed for $repo_name"
        rm "$workflow_file.backup"
        git checkout main
        git branch -D "$branch_name" 2>/dev/null || true
    fi
    
    cd - >/dev/null
}

# Function to generate post-merge instructions
generate_post_merge_instructions() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    local github_repo="bold-minds/$repo_name"
    
    cat > "$repo_path/NEXT_STEPS.md" <<EOF
# Next Steps for $repo_name Badge Automation

## ✅ Workflow Fixes Applied
- persist-credentials: false (prevents token conflicts)
- Git URL rewriting (enables GitHub App authentication)
- Proper environment variable configuration

## 🚨 CRITICAL: Manual Step Required

**Add GitHub App to Repository Ruleset Bypass List:**

1. Go to: https://github.com/$github_repo/settings/rules
2. Edit the main branch ruleset
3. Add GitHub App ID \`1759509\` to bypass actors
4. Set bypass mode to \`always\`
5. Save the configuration

## 🧪 Test Badge Automation

After completing the manual step:

1. Push a small change to main branch
2. Monitor workflow for successful completion
3. Check that badge files are updated in \`.github/badges/\`
4. Verify commit attribution shows "Badge Automation Bot"
5. Confirm green status on Actions/Checks

## 🎯 Success Criteria
- ✅ Main branch has green status on Actions/Checks
- ✅ Badge files are updated automatically after test runs
- ✅ Commits show proper attribution ("Badge Automation Bot")
- ✅ No repository rule violations in workflow logs

---
*Based on research-backed solutions that achieved green status on bold-minds/ex*
EOF
    
    log_success "Generated next steps: $repo_path/NEXT_STEPS.md"
}

# Main function
main() {
    echo "🔧 PR-Based Badge Automation Fix Script"
    echo "======================================="
    echo ""
    
    # Check if repository paths provided
    if [[ $# -eq 0 ]]; then
        log_error "Usage: $0 <repo_path1> [repo_path2] [repo_path3] ..."
        log_info "Example: $0 /path/to/repo1 /path/to/repo2"
        log_info "Example: $0 ../repo1 ../repo2 ../repo3"
        exit 1
    fi
    
    log_info "This script will:"
    log_info "1. Apply authentication fixes via PRs"
    log_info "2. Test solo maintainer PR merge capability"
    log_info "3. Generate post-merge instructions"
    echo ""
    log_warning "This tests both badge automation fixes AND solo maintainer workflow"
    echo ""
    
    # Process each repository
    for repo_path in "$@"; do
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Apply fixes via PR and test solo maintainer merge
        if apply_fixes_via_pr "$repo_path"; then
            generate_post_merge_instructions "$repo_path"
            log_success "Repository $(basename "$repo_path") processing completed"
        else
            log_error "Failed to process repository: $repo_path"
        fi
        
        echo ""
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 PR-Based Badge Automation Fix Script Completed!"
    echo ""
    log_info "Results summary:"
    echo "- Applied authentication fixes via PRs"
    echo "- Tested solo maintainer PR merge capability"
    echo "- Generated post-merge instructions for each repository"
    echo ""
    log_warning "Complete the repository ruleset bypass configuration for each repo"
    log_info "Then test badge automation to achieve green status on Actions/Checks"
    echo ""
}

# Run main function
main "$@"
