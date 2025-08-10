#!/bin/bash

# GitHub App Setup Script for Badge Automation
# This script creates and configures a GitHub App for automated badge commits
# across multiple repositories in an organization.
#
# Prerequisites:
# - GitHub CLI (gh) installed and authenticated with admin permissions
# - Organization admin access
# - jq installed for JSON processing

set -e

# Configuration
ORG_NAME="bold-minds"
APP_NAME="Badge Automation Bot"
APP_DESCRIPTION="Automated badge updates for CI/CD pipelines"
HOMEPAGE_URL="https://github.com/$ORG_NAME"

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if gh CLI is installed
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI is not installed. Please install it from https://cli.github.com/"
        exit 1
    fi
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install it: sudo apt-get install jq"
        exit 1
    fi
    
    # Check if authenticated
    if ! gh auth status &> /dev/null; then
        log_error "Not authenticated with GitHub CLI. Run: gh auth login"
        exit 1
    fi
    
    # Check organization access
    if ! gh api orgs/$ORG_NAME >/dev/null 2>&1; then
        log_error "Cannot access organization '$ORG_NAME'. Check your permissions."
        exit 1
    fi
    
    log_success "All prerequisites met"
}

# Create GitHub App
create_github_app() {
    log_info "Creating GitHub App '$APP_NAME'..."
    
    # Note: GitHub Apps API endpoints are different - we need to use the web interface
    # for initial app creation as the API has limitations
    
    log_warning "GitHub App creation requires manual setup due to API limitations"
    log_info "Please follow these steps:"
    log_info "1. Go to: https://github.com/organizations/$ORG_NAME/settings/apps/new"
    log_info "2. Fill in the following details:"
    log_info "   - GitHub App name: $APP_NAME"
    log_info "   - Description: $APP_DESCRIPTION"
    log_info "   - Homepage URL: $HOMEPAGE_URL"
    log_info "   - Webhook: Disable webhook (uncheck 'Active')"
    log_info "3. Set Repository permissions:"
    log_info "   - Contents: Read and write"
    log_info "   - Metadata: Read"
    log_info "   - Pull requests: Read"
    log_info "4. Click 'Create GitHub App'"
    log_info "5. Note down the App ID from the settings page"
    
    echo ""
    log_info "This script provides setup instructions only."
    log_info "Use the github-oss-setup.sh script for automated repository configuration."
    echo ""
    
    # Return a placeholder since this is instruction-only
    echo "MANUAL_SETUP_REQUIRED"
}

# Generate private key for the app
generate_private_key() {
    local app_id="$1"
    log_info "Generating private key for app ID: $app_id..."
    
    # Generate private key
    PRIVATE_KEY_RESPONSE=$(gh api apps/$app_id/installations -X POST --input - <<EOF
{
  "note": "Badge automation key - $(date)"
}
EOF
)
    
    # The actual private key generation needs to be done via the web interface
    # or using a different API endpoint. Let's provide instructions instead.
    log_warning "Private key generation requires manual step:"
    log_info "1. Go to: https://github.com/organizations/$ORG_NAME/settings/apps/$app_id"
    log_info "2. Scroll down to 'Private keys' section"
    log_info "3. Click 'Generate a private key'"
    log_info "4. Download the .pem file"
    log_info "5. Store it securely - you'll need it for repository secrets"
    
    echo "Please complete the private key generation manually, then press Enter to continue..."
    read -r
}

# Install app on repository
install_app_on_repo() {
    local app_id="$1"
    local repo_name="$2"
    
    log_info "Installing app on repository: $ORG_NAME/$repo_name..."
    
    # Get installation ID for the organization
    INSTALLATION_ID=$(gh api orgs/$ORG_NAME/installations --jq ".[0].id" 2>/dev/null || echo "")
    
    if [[ -z "$INSTALLATION_ID" ]]; then
        log_warning "App not yet installed on organization. Installing..."
        # This typically requires manual approval in the GitHub UI
        log_info "Please go to: https://github.com/organizations/$ORG_NAME/settings/installations"
        log_info "And install the '$APP_NAME' app on the organization"
        echo "Press Enter after installing the app..."
        read -r
        
        # Try to get installation ID again
        INSTALLATION_ID=$(gh api orgs/$ORG_NAME/installations --jq ".[0].id" 2>/dev/null || echo "")
    fi
    
    if [[ -n "$INSTALLATION_ID" ]]; then
        log_success "App installed with installation ID: $INSTALLATION_ID"
    else
        log_error "Could not verify app installation"
        return 1
    fi
}

# Add app to repository ruleset bypass
add_to_ruleset_bypass() {
    local app_id="$1"
    local repo_name="$2"
    
    log_info "Adding app to repository ruleset bypass for $repo_name..."
    
    # Get existing ruleset
    RULESET_ID=$(gh api repos/$ORG_NAME/$repo_name/rulesets --jq '.[0].id' 2>/dev/null || echo "")
    
    if [[ -z "$RULESET_ID" ]]; then
        log_warning "No rulesets found for $repo_name"
        return 0
    fi
    
    # Get current ruleset configuration
    CURRENT_RULESET=$(gh api repos/$ORG_NAME/$repo_name/rulesets/$RULESET_ID 2>/dev/null)
    
    # Add the app to bypass actors
    UPDATED_RULESET=$(echo "$CURRENT_RULESET" | jq --arg app_id "$app_id" '
        .bypass_actors += [{
            "actor_type": "Integration",
            "actor_id": ($app_id | tonumber),
            "bypass_mode": "always"
        }] | 
        .bypass_actors |= unique_by(.actor_id)
    ')
    
    # Update the ruleset
    if echo "$UPDATED_RULESET" | gh api repos/$ORG_NAME/$repo_name/rulesets/$RULESET_ID -X PUT --input - >/dev/null 2>&1; then
        log_success "Added app to ruleset bypass for $repo_name"
    else
        log_error "Failed to add app to ruleset bypass for $repo_name"
        log_info "Manual step required: Go to repository settings and add the app to bypass list"
    fi
}

# Generate workflow template
generate_workflow_template() {
    local app_id="$1"
    
    log_info "Generating workflow template..."
    
    cat > workflow-template.yml <<EOF
name: Update Badges with GitHub App

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
          persist-credentials: false
          
      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
          
      - name: Generate Badges
        run: |
          # Run your badge generation script
          ./scripts/validate.sh
          
      - name: Commit Badge Updates
        env:
          GITHUB_TOKEN: \${{ steps.app-token.outputs.token }}
        run: |
          # Configure git with GitHub App identity and authentication
          git config --global user.name "Badge Automation Bot"
          git config --global user.email "action@github.com"
          
          # Configure git to use the GitHub App token for authentication
          git config --global url."https://x-access-token:\${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"
          
          # Add badge files to git
          git add .github/badges/
          
          # Commit if there are changes
          if git diff --staged --quiet; then
            echo "No badge changes to commit"
          else
            git commit -m "chore: update badges from CI run \${{ github.run_number }} [skip ci]"
            # Push with GitHub App token authentication
            git push origin HEAD:main
          fi
EOF
    
    log_success "Workflow template created: workflow-template.yml"
}

# Generate setup instructions
generate_setup_instructions() {
    local app_id="$1"
    
    cat > GITHUB_APP_SETUP.md <<EOF
# GitHub App Setup Instructions

## App Created
- **App ID**: $app_id
- **App Name**: $APP_NAME
- **Organization**: $ORG_NAME

## Next Steps for Each Repository

### 1. Store App Credentials
Add these secrets to your repository:
- \`BADGE_BOT_APP_ID\`: $app_id (as a variable)
- \`BADGE_BOT_PRIVATE_KEY\`: [Your downloaded private key] (as a secret)

### 2. Update Workflow
Copy the generated \`workflow-template.yml\` to \`.github/workflows/update-badges.yml\`

### 3. Test the Setup
Push a change and verify that badges are updated automatically.

## Repository Setup Command
For each new repository, run:
\`\`\`bash
./setup-github-app.sh --add-repo REPO_NAME
\`\`\`

## Manual Steps Completed
- ✅ GitHub App created
- ✅ Private key generated (manual)
- ⏳ App ready for installation on repositories

## Critical Requirements for Badge Automation
1. **GitHub App Bypass Configuration**:
   - Add GitHub App to repository ruleset bypass list with \`bypass_mode: always\`
   - Go to: https://github.com/REPO_OWNER/REPO_NAME/settings/rules
   - Edit the main branch ruleset and add your GitHub App ID

2. **Workflow Authentication Requirements**:
   - MUST use \`persist-credentials: false\` in checkout step
   - MUST configure git URL rewriting for GitHub App token authentication
   - See workflow template for exact configuration

3. **Repository Protection Considerations**:
   - Both repository rulesets AND branch protection rules can block badge commits
   - GitHub App must be in bypass list for BOTH protection types
   - May need to temporarily disable protection during initial testing

## Troubleshooting
- Ensure the app has \`Contents: Write\` permission
- Verify the app is in the repository ruleset bypass list with \`bypass_mode: always\`
- Check that repository secrets are correctly configured
- Confirm \`persist-credentials: false\` is set in checkout step
- Verify git URL rewriting is configured for GitHub App token authentication
- Test with repository protection temporarily disabled if needed
EOF
    
    log_success "Setup instructions created: GITHUB_APP_SETUP.md"
}

# Main execution
main() {
    echo "🚀 GitHub App Setup for Badge Automation"
    echo "========================================"
    
    # Handle command line arguments
    if [[ "$1" == "--add-repo" && -n "$2" ]]; then
        # Add existing app to a new repository
        EXISTING_APP_ID=$(gh api orgs/$ORG_NAME/apps --jq ".[] | select(.name == \"$APP_NAME\") | .id" 2>/dev/null || echo "")
        if [[ -n "$EXISTING_APP_ID" ]]; then
            install_app_on_repo "$EXISTING_APP_ID" "$2"
            add_to_ruleset_bypass "$EXISTING_APP_ID" "$2"
            log_success "Repository $2 configured for badge automation"
        else
            log_error "App '$APP_NAME' not found. Run the full setup first."
        fi
        exit 0
    fi
    
    check_prerequisites
    
    APP_ID=$(create_github_app)
    generate_private_key "$APP_ID"
    generate_workflow_template "$APP_ID"
    generate_setup_instructions "$APP_ID"
    
    echo ""
    echo "🎉 GitHub App setup completed!"
    echo ""
    log_info "Next steps:"
    echo "1. Complete the private key generation (manual step above)"
    echo "2. Add app credentials to repository secrets"
    echo "3. Deploy the workflow template"
    echo "4. Test with a repository push"
    echo ""
    log_info "For additional repositories, run:"
    echo "  ./setup-github-app.sh --add-repo REPO_NAME"
}

# Run main function
main "$@"
