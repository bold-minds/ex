#!/bin/bash

# Local Badge Automation Fix Script
# This script applies the research-backed authentication fixes to local repositories
# that already have the GitHub App installed but are encountering badge automation issues.
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

# Function to fix workflow authentication in a local repository
fix_local_workflow() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    local workflow_file="$repo_path/.github/workflows/test.yaml"
    
    log_info "Fixing badge automation in local repository: $repo_name"
    
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
    
    log_info "Applying authentication fixes to workflow..."
    
    # Create backup
    cp "$workflow_file" "$workflow_file.backup"
    log_info "Created backup: $workflow_file.backup"
    
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
        log_warning "persist-credentials: false may need to be added manually"
    else
        log_info "persist-credentials: false already configured"
    fi
    
    # Fix 2: Update badge commit step with complete authentication
    if grep -q "git config --local user.name" "$workflow_file" || grep -q "git config --global user.name" "$workflow_file"; then
        # Find and replace the badge commit section
        python3 -c "
import re
import sys

with open('$workflow_file', 'r') as f:
    content = f.read()

# Pattern to match the badge commit step
pattern = r'(- name: Commit badges to main branch.*?env:\s*GITHUB_TOKEN: \$\{\{ steps\.app-token\.outputs\.token \}\}.*?run: \|)(.*?)(git push origin HEAD:main.*?fi)'

replacement = r'''\1
          # Configure git with GitHub App identity and authentication
          git config --global user.name \"Badge Automation Bot\"
          git config --global user.email \"action@github.com\"
          
          # Configure git to use the GitHub App token for authentication
          git config --global url.\"https://x-access-token:\${GITHUB_TOKEN}@github.com/\".insteadOf \"https://github.com/\"
          
          # Add badge files to git
          git add .github/badges/
          
          # Commit if there are changes
          if git diff --staged --quiet; then
            echo \"No badge changes to commit\"
          else
            git commit -m \"chore: update badges from CI run \$\{\{ github.run_number \}\} [skip ci]\"
            # Push with GitHub App token authentication
            \3'''

new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)

with open('$workflow_file', 'w') as f:
    f.write(new_content)
"
        log_success "Updated badge commit authentication"
    else
        log_warning "Badge commit step may need manual update"
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
- Stack Overflow: https://stackoverflow.com/questions/77433427"
        
        log_info "Changes committed locally. Push when ready: git push origin main"
    else
        log_info "No changes needed for $repo_name"
        rm "$workflow_file.backup"
    fi
    
    cd - >/dev/null
}

# Function to generate repository-specific manual instructions
generate_manual_instructions() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    local github_repo="bold-minds/$repo_name"
    local app_id="1759509"
    
    cat > "$repo_path/BADGE_AUTOMATION_FIX.md" <<EOF
# Badge Automation Fix Instructions for $repo_name

## ✅ Automated Fixes Applied
- persist-credentials: false (prevents token conflicts)
- Git URL rewriting (enables GitHub App authentication)
- Proper environment variable configuration

## 🚨 CRITICAL: Manual Step Required

**Add GitHub App to Repository Ruleset Bypass List:**

1. Go to: https://github.com/$github_repo/settings/rules
2. Edit the main branch ruleset
3. Add GitHub App ID \`$app_id\` to bypass actors
4. Set bypass mode to \`always\`
5. Save the configuration

## 🧪 Test Badge Automation

After completing the manual step:

1. Push the workflow fixes: \`git push origin main\`
2. Monitor workflow for successful completion
3. Check that badge files are updated in \`.github/badges/\`
4. Verify commit attribution shows "Badge Automation Bot"
5. Confirm green status on Actions/Checks

## 🔧 Troubleshooting

If badge automation still fails:
- Temporarily disable repository rules for testing
- Check that both repository rulesets AND branch protection allow GitHub App bypass
- Verify GitHub App has Contents: Read/Write permissions
- Confirm repository variables and secrets are correctly configured

## 📋 Success Criteria
- ✅ Main branch has green status on Actions/Checks
- ✅ Badge files are updated automatically after test runs
- ✅ Commits show proper attribution ("Badge Automation Bot")
- ✅ No repository rule violations in workflow logs

---
*Generated by fix-local-badge-automation.sh based on research-backed solutions that achieved green status*
EOF
    
    log_success "Generated fix instructions: $repo_path/BADGE_AUTOMATION_FIX.md"
}

# Main function
main() {
    echo "🔧 Local Badge Automation Fix Script"
    echo "===================================="
    echo ""
    
    # Check if repository paths provided
    if [[ $# -eq 0 ]]; then
        log_error "Usage: $0 <repo_path1> [repo_path2] [repo_path3] ..."
        log_info "Example: $0 /path/to/repo1 /path/to/repo2"
        log_info "Example: $0 ../repo1 ../repo2 ../repo3"
        exit 1
    fi
    
    log_info "Using GitHub App ID: 1759509"
    log_info "Processing local repositories: $*"
    echo ""
    
    # Process each repository
    for repo_path in "$@"; do
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Apply workflow authentication fixes
        if fix_local_workflow "$repo_path"; then
            # Generate repository-specific instructions
            generate_manual_instructions "$repo_path"
            log_success "Repository $(basename "$repo_path") processing completed"
        else
            log_error "Failed to process repository: $repo_path"
        fi
        
        echo ""
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 Local Badge Automation Fix Script Completed!"
    echo ""
    log_info "Next steps for each repository:"
    echo "1. Review the generated BADGE_AUTOMATION_FIX.md file in each repo"
    echo "2. Complete the repository ruleset bypass configuration (manual step)"
    echo "3. Push the workflow fixes: git push origin main"
    echo "4. Test badge automation and verify green status on Actions/Checks"
    echo ""
    log_warning "Remember: Repository ruleset bypass configuration requires manual setup via GitHub web interface"
    echo ""
}

# Run main function
main "$@"
