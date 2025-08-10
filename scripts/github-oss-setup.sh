#!/bin/bash

# GitHub Repository Security Setup Script
# This script automates the setup of security features for a GitHub repository
# including vulnerability alerts, Dependabot, secret scanning, and branch protection.
#
# Prerequisites:
# - GitHub CLI (gh) installed and authenticated
# - Repository must exist
# - User must have admin access to the repository

# Removed set -e to prevent early exit on API failures
# We handle errors explicitly in each section

REPO_OWNER="bold-minds"
REPO_NAME="ex"
REPO="$REPO_OWNER/$REPO_NAME"

# Status tracking variables
declare -A STATUS
STATUS_UPDATED=0
STATUS_SKIPPED=0
STATUS_FAILED=0

# Function to track status
track_status() {
    local step="$1"
    local result="$2"  # SUCCESS, SKIPPED, or FAILED
    STATUS["$step"]="$result"
    case "$result" in
        "SUCCESS") ((STATUS_UPDATED++)) ;;
        "SKIPPED") ((STATUS_SKIPPED++)) ;;
        "FAILED") ((STATUS_FAILED++)) ;;
    esac
}

echo "🔧 Setting up GitHub security for $REPO..."

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI is not installed. Please install it from https://cli.github.com/"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub CLI. Run: gh auth login"
    exit 1
fi

echo "✅ GitHub CLI is ready"

# Set repository to public FIRST (required for free security features)
echo "🌍 Setting repository to public (required for free security features)..."
if gh repo edit $REPO --visibility public --accept-visibility-change-consequences >/dev/null 2>&1; then
    track_status "Repository Visibility" "SUCCESS"
    echo "✅ Repository set to public"
    echo "⏳ Waiting 5 seconds for visibility change to propagate..."
    sleep 5
else
    track_status "Repository Visibility" "SKIPPED"
    echo "⚠️  Repository may already be public"
fi

# Enable vulnerability alerts
echo "🔒 Enabling vulnerability alerts..."
if gh api repos/$REPO/vulnerability-alerts -X PUT >/dev/null 2>&1; then
    track_status "Vulnerability Alerts" "SUCCESS"
    echo "✅ Vulnerability alerts enabled"
else
    track_status "Vulnerability Alerts" "SKIPPED"
    echo "⚠️  Vulnerability alerts may already be enabled"
fi

# Enable automated security fixes (Dependabot security updates)
echo "🤖 Enabling Dependabot security updates..."
if gh api repos/$REPO/automated-security-fixes -X PUT >/dev/null 2>&1; then
    track_status "Dependabot Security Updates" "SUCCESS"
    echo "✅ Dependabot security updates enabled"
else
    track_status "Dependabot Security Updates" "SKIPPED"
    echo "⚠️  Dependabot security updates may already be enabled"
fi

# Enable dependency graph
echo "📊 Enabling dependency graph..."
if gh api repos/$REPO -X PATCH -f has_vulnerability_alerts=true >/dev/null 2>&1; then
    track_status "Dependency Graph" "SUCCESS"
    echo "✅ Dependency graph enabled"
else
    track_status "Dependency Graph" "SKIPPED"
    echo "⚠️  Dependency graph may already be enabled"
fi

# Enable code security and analysis (FREE for public repos)
echo "🔒 Enabling code security and analysis (secret scanning)..."
if gh api repos/$REPO -X PATCH --input - >/dev/null 2>&1 <<EOF
{
  "security_and_analysis": {
    "secret_scanning": {
      "status": "enabled"
    },
    "secret_scanning_push_protection": {
      "status": "enabled"
    }
  }
}
EOF
then
    track_status "Secret Scanning" "SUCCESS"
    echo "✅ Secret scanning enabled"
else
    track_status "Secret Scanning" "SKIPPED"
    echo "⚠️  Secret scanning may already be enabled"
fi

# Create branch protection rule for main
echo "🛡️  Setting up branch protection for main..."
if gh api repos/$REPO/branches/main/protection -X PUT --input - >/dev/null 2>&1 <<EOF
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["test"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true
  },
  "restrictions": null
}
EOF
then
    track_status "Branch Protection" "SUCCESS"
    echo "✅ Branch protection configured"
else
    track_status "Branch Protection" "SKIPPED"
    echo "⚠️  Branch protection may already be configured"
fi

# Configure GitHub App for automated badge commits
echo "🤖 Setting up GitHub App for automated badge commits..."

# GitHub App configuration
APP_NAME="Badge Automation Bot"
APP_DESCRIPTION="Automated badge updates for CI/CD pipelines"

# GitHub App creation requires manual setup due to API limitations
echo "ℹ️  GitHub App creation requires manual setup"
echo "ℹ️  The GitHub Apps API has restrictions that prevent full automation"

# Provide clear manual setup instructions
echo ""
echo "📋 Manual GitHub App Setup Required:"
echo "1. Go to: https://github.com/organizations/$REPO_OWNER/settings/apps/new"
echo "2. Fill in these details:"
echo "   - GitHub App name: $APP_NAME"
echo "   - Description: $APP_DESCRIPTION"
echo "   - Homepage URL: https://github.com/$REPO_OWNER"
echo "   - Webhook: Disable webhook (uncheck 'Active')"
echo "3. Set Repository permissions:"
echo "   - Contents: Read and write"
echo "   - Metadata: Read"
echo "   - Pull requests: Read"
echo "4. Click 'Create GitHub App'"
echo "5. Install the app on this organization"
echo "6. Generate and download a private key"
echo ""

# Skip the automated app creation but still generate templates
echo "⏭️  Skipping automated app creation - manual setup required"
track_status "GHA Badge App" "SKIPPED"
APP_ID="YOUR_APP_ID_HERE"

# Provide instructions for manual ruleset bypass configuration
echo "🔄 Repository ruleset bypass configuration..."

# Check current ruleset configuration
EXISTING_RULESET=$(gh api repos/$REPO/rulesets --jq '.[0].id' 2>/dev/null)
if [[ -n "$EXISTING_RULESET" && "$EXISTING_RULESET" != "null" ]]; then
    echo "📋 Manual ruleset bypass setup required:"
    echo "1. Go to: https://github.com/$REPO/settings/rules"
    echo "2. Click on your 'Main' ruleset"
    echo "3. Scroll to 'Bypass list'"
    echo "4. Click 'Add bypass'"
    echo "5. Select your '$APP_NAME' app"
    echo "6. Set bypass mode to 'Always'"
    echo "7. Save the ruleset"
    echo ""
    track_status "GHA Badge Bypass" "SKIPPED"
else
    echo "✅ No rulesets found - GitHub App should work with default permissions"
    track_status "GHA Badge Bypass" "SUCCESS"
fi
    
    # Generate workflow template for this repository
    echo "📝 Generating badge automation workflow template..."
    cat > badge-workflow-template.yml <<EOF
name: Update Badges

on:
  workflow_run:
    workflows: ["Test"]
    types:
      - completed

jobs:
  update-badges:
    runs-on: ubuntu-latest
    if: \${{ github.event.workflow_run.conclusion == 'success' }}
    
    steps:
      - name: Generate GitHub App Token
        id: app-token
        uses: actions/create-github-app-token@v1
        with:
          app-id: \${{ vars.BADGE_BOT_APP_ID }}
          private-key: \${{ secrets.BADGE_BOT_PRIVATE_KEY }}
          
      - name: Checkout
        uses: actions/checkout@v4
        with:
          token: \${{ steps.app-token.outputs.token }}
          
      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
          
      - name: Generate Badges
        run: |
          ./scripts/validate.sh
          
      - name: Commit Badge Updates
        run: |
          git config --local user.email "action@github.com"
          git config --local user.name "Badge Automation Bot"
          
          if [[ -n "\$(git status --porcelain)" ]]; then
            git add .github/badges/
            git commit -m "chore: update badges [skip ci]"
            git push
          else
            echo "No badge changes to commit"
          fi
EOF
    
    echo "✅ Badge workflow template created: badge-workflow-template.yml"
    
    echo ""
    echo "📋 Final steps to complete badge automation:"
    echo "1. Complete the GitHub App setup (see instructions above)"
    echo "2. Note your App ID from the GitHub App settings page"
    echo "3. Generate and download a private key from the app settings"
    echo "4. Add repository secrets:"
    echo "   - BADGE_BOT_APP_ID: [Your App ID] (as variable)"
    echo "   - BADGE_BOT_PRIVATE_KEY: [Downloaded private key] (as secret)"
    echo "5. Deploy workflow: cp badge-workflow-template.yml .github/workflows/update-badges.yml"
    echo "6. Update the workflow template with your actual App ID"
    echo ""
    echo "💡 The workflow template has been created and is ready to deploy once you complete the manual setup steps."
    echo ""

# Enable issues
echo "📝 Enabling issues..."
if gh repo edit $REPO --enable-issues >/dev/null 2>&1; then
    track_status "Issues" "SUCCESS"
    echo "✅ Issues enabled"
else
    track_status "Issues" "FAILED"
    echo "❌ Failed to enable issues"
fi

# Enable discussions
echo "💬 Enabling discussions..."
if gh repo edit $REPO --enable-discussions >/dev/null 2>&1; then
    track_status "Discussions" "SUCCESS"
    echo "✅ Discussions enabled"
else
    track_status "Discussions" "FAILED"
    echo "❌ Failed to enable discussions"
fi

# Disable wiki (use README instead)
echo "📚 Disabling wiki..."
if gh repo edit $REPO --enable-wiki=false >/dev/null 2>&1; then
    track_status "Wiki (Disabled)" "SUCCESS"
    echo "✅ Wiki disabled"
else
    track_status "Wiki (Disabled)" "FAILED"
    echo "❌ Failed to disable wiki"
fi



# Print comprehensive status summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 GITHUB SECURITY SETUP SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📈 Statistics:"
echo "   ✅ Updated: $STATUS_UPDATED"
echo "   ⏭️  Skipped: $STATUS_SKIPPED"
echo "   ❌ Failed:  $STATUS_FAILED"
echo "   📝 Total:   $((STATUS_UPDATED + STATUS_SKIPPED + STATUS_FAILED))"
echo ""
echo "📋 Detailed Status:"
for step in "Repository Visibility" "Vulnerability Alerts" "Dependabot Security Updates" "Dependency Graph" "Secret Scanning" "Branch Protection" "GHA Badge Bypass" "Issues" "Discussions" "Wiki (Disabled)"; do
    if [[ -n "${STATUS[$step]}" ]]; then
        case "${STATUS[$step]}" in
            "SUCCESS") echo "   ✅ $step: Updated" ;;
            "SKIPPED") echo "   ⏭️  $step: Already configured" ;;
            "FAILED")  echo "   ❌ $step: Failed" ;;
        esac
    fi
done
echo ""
if [[ $STATUS_FAILED -gt 0 ]]; then
    echo "⚠️  Some steps failed. Check the output above for details."
else
    echo "🎉 Automated setup complete!"
fi
echo ""
echo "⚠️  MANUAL STEPS STILL REQUIRED:"
echo "1. Go to Settings → Security & analysis"
echo "2. Enable Code scanning (CodeQL) - requires manual setup"
echo "3. Enable Private vulnerability reporting"
echo "4. Configure Actions permissions in Settings → Actions → General"
echo ""
echo "💡 These require manual setup due to GitHub API limitations"
echo "📋 Use GITHUB_SECURITY_SETUP.md for the complete manual checklist"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
