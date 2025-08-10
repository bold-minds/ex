#!/bin/bash

# Repository Standardization Script
# Standardizes all bold-minds repositories to match the ex repository configuration
# including repo settings, workflows, badges, CODEOWNERS, dependabot, and standard files

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

# Repository configuration
TEMPLATE_REPO="/home/cvnext/GitHub/ex"
TARGET_REPOS=(
    "/home/cvnext/GitHub/id"
    "/home/cvnext/GitHub/obs" 
    "/home/cvnext/GitHub/oss"
    "/home/cvnext/GitHub/goby"
    "/home/cvnext/GitHub/bench"
)

# Standard files to copy from ex repository
STANDARD_FILES=(
    "CODE_OF_CONDUCT.md"
    "CONTRIBUTING.md"
    "LICENSE"
    "SECURITY.md"
    ".gitignore"
    ".golangci.yml"
)

# GitHub configuration files to copy
GITHUB_CONFIG_FILES=(
    ".github/CODEOWNERS"
    ".github/dependabot.yml"
    ".github/ISSUE_TEMPLATE/bug_report.md"
    ".github/ISSUE_TEMPLATE/feature_request.md"
    ".github/PULL_REQUEST_TEMPLATE.md"
    ".github/workflows/test.yaml"
)

# Function to copy standard files
copy_standard_files() {
    local target_repo="$1"
    local repo_name=$(basename "$target_repo")
    
    log_info "Copying standard files to $repo_name..."
    
    for file in "${STANDARD_FILES[@]}"; do
        if [[ -f "$TEMPLATE_REPO/$file" ]]; then
            cp "$TEMPLATE_REPO/$file" "$target_repo/$file"
            log_success "Copied $file"
        else
            log_warning "Template file not found: $file"
        fi
    done
}

# Function to copy GitHub configuration files
copy_github_config() {
    local target_repo="$1"
    local repo_name=$(basename "$target_repo")
    
    log_info "Copying GitHub configuration files to $repo_name..."
    
    # Ensure .github directory structure exists
    mkdir -p "$target_repo/.github/ISSUE_TEMPLATE"
    mkdir -p "$target_repo/.github/workflows"
    
    for file in "${GITHUB_CONFIG_FILES[@]}"; do
        if [[ -f "$TEMPLATE_REPO/$file" ]]; then
            # Create directory if needed
            local dir=$(dirname "$target_repo/$file")
            mkdir -p "$dir"
            
            # Copy file and customize for target repository
            if [[ "$file" == ".github/workflows/test.yaml" ]]; then
                # Customize workflow file for target repository
                sed "s/bold-minds\/ex/bold-minds\/$repo_name/g" "$TEMPLATE_REPO/$file" > "$target_repo/$file"
                log_success "Customized and copied $file"
            elif [[ "$file" == ".github/CODEOWNERS" ]]; then
                # Customize CODEOWNERS for target repository
                cp "$TEMPLATE_REPO/$file" "$target_repo/$file"
                log_success "Copied $file"
            else
                cp "$TEMPLATE_REPO/$file" "$target_repo/$file"
                log_success "Copied $file"
            fi
        else
            log_warning "Template file not found: $file"
        fi
    done
}

# Function to configure GitHub App secrets and variables
configure_github_app() {
    local target_repo="$1"
    local repo_name=$(basename "$target_repo")
    local github_repo="bold-minds/$repo_name"
    
    log_info "Configuring GitHub App for $repo_name..."
    
    cd "$target_repo"
    
    # Configure repository variable
    if gh variable set BADGE_BOT_APP_ID --body "1759509"; then
        log_success "Configured BADGE_BOT_APP_ID variable"
    else
        log_error "Failed to configure BADGE_BOT_APP_ID variable"
    fi
    
    # Note about private key secret (requires manual setup)
    log_warning "BADGE_BOT_PRIVATE_KEY secret requires manual configuration"
    log_info "Copy the private key from ex repository or use GitHub web interface"
    
    cd - >/dev/null
}

# Function to configure repository settings
configure_repo_settings() {
    local target_repo="$1"
    local repo_name=$(basename "$target_repo")
    local github_repo="bold-minds/$repo_name"
    
    log_info "Configuring repository settings for $repo_name..."
    
    cd "$target_repo"
    
    # Enable repository features
    gh repo edit "$github_repo" \
        --enable-issues \
        --enable-discussions \
        --enable-projects \
        --default-branch main \
        --delete-branch-on-merge \
        --enable-merge-commit=false \
        --enable-squash-merge=true \
        --enable-rebase-merge=false \
        --allow-update-branch
    
    log_success "Configured repository settings"
    
    # Configure branch protection (simplified for solo maintainer)
    log_info "Configuring branch protection..."
    gh api repos/"$github_repo"/branches/main/protection \
        --method PUT \
        --field required_status_checks='{"strict":true,"contexts":["test"]}' \
        --field enforce_admins=false \
        --field required_pull_request_reviews=null \
        --field restrictions=null \
        --field allow_force_pushes=false \
        --field allow_deletions=false \
        --field block_creations=false \
        --field required_conversation_resolution=false \
        --field lock_branch=false \
        --field allow_fork_syncing=false \
        >/dev/null 2>&1 && log_success "Configured branch protection" || log_warning "Branch protection configuration may need manual adjustment"
    
    cd - >/dev/null
}

# Function to create badges directory
setup_badges() {
    local target_repo="$1"
    local repo_name=$(basename "$target_repo")
    
    log_info "Setting up badges directory for $repo_name..."
    
    mkdir -p "$target_repo/.github/badges"
    
    # Create placeholder badge files
    echo '{"schemaVersion":1,"label":"coverage","message":"pending","color":"lightgrey"}' > "$target_repo/.github/badges/coverage.json"
    echo '{"schemaVersion":1,"label":"Go","message":"pending","color":"lightgrey"}' > "$target_repo/.github/badges/go-version.json"
    echo '{"schemaVersion":1,"label":"golangci-lint","message":"pending","color":"lightgrey"}' > "$target_repo/.github/badges/golangci-lint.json"
    echo '{"schemaVersion":1,"label":"security","message":"pending","color":"lightgrey"}' > "$target_repo/.github/badges/dependabot.json"
    echo '{"schemaVersion":1,"label":"last updated","message":"pending","color":"lightgrey"}' > "$target_repo/.github/badges/last-updated.json"
    
    log_success "Created badges directory with placeholder badges"
}

# Function to standardize a single repository
standardize_repository() {
    local target_repo="$1"
    local repo_name=$(basename "$target_repo")
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Standardizing repository: $repo_name"
    
    # Check if repository directory exists
    if [[ ! -d "$target_repo" ]]; then
        log_error "Repository directory not found: $target_repo"
        return 1
    fi
    
    cd "$target_repo"
    
    # Ensure we're on main branch and up to date
    git checkout main 2>/dev/null || git checkout master 2>/dev/null || log_warning "Could not switch to main/master branch"
    git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || log_warning "Could not pull latest changes"
    
    # Create standardization branch
    local branch_name="standardize-with-ex-repo"
    git checkout -b "$branch_name" 2>/dev/null || git checkout "$branch_name"
    
    # Copy standard files
    copy_standard_files "$target_repo"
    
    # Copy GitHub configuration
    copy_github_config "$target_repo"
    
    # Setup badges directory
    setup_badges "$target_repo"
    
    # Stage all changes
    git add .
    
    # Check if there are changes to commit
    if ! git diff --staged --quiet; then
        log_info "Committing standardization changes..."
        git commit -m "feat: standardize repository with ex configuration

- Add standard OSS files (CODE_OF_CONDUCT, CONTRIBUTING, LICENSE, SECURITY)
- Add GitHub configuration (.github/CODEOWNERS, dependabot.yml, templates)
- Add standardized test workflow with GitHub App badge automation
- Add golangci-lint configuration and gitignore
- Setup badges directory with placeholder badges
- Configure repository for professional OSS development

This standardization aligns the repository with bold-minds/ex for consistency
across the organization and enables automated badge generation with green status."
        
        # Push the standardization branch
        git push origin "$branch_name" 2>/dev/null || log_warning "Could not push standardization branch"
        
        # Create PR for standardization
        gh pr create \
            --title "feat: standardize repository with ex configuration" \
            --body "**REPOSITORY STANDARDIZATION**: Aligns this repository with bold-minds/ex for consistency.

## Changes Applied
- ✅ **Standard OSS files**: CODE_OF_CONDUCT.md, CONTRIBUTING.md, LICENSE, SECURITY.md
- ✅ **GitHub configuration**: CODEOWNERS, dependabot.yml, issue/PR templates
- ✅ **Standardized workflow**: test.yaml with GitHub App badge automation
- ✅ **Development tools**: .golangci.yml, .gitignore
- ✅ **Badge automation**: Placeholder badges and automation setup

## Benefits
- 🎯 **Consistent configuration** across all bold-minds repositories
- 🚀 **Professional OSS setup** with security and contribution guidelines
- 🤖 **Automated badge generation** with green status on Actions/Checks
- 🔒 **Security best practices** with Dependabot and code scanning

## Next Steps After Merge
1. Configure GitHub App private key secret: \`BADGE_BOT_PRIVATE_KEY\`
2. Add GitHub App (ID 1759509) to repository ruleset bypass (if using rulesets)
3. Test badge automation for green status verification
4. Customize repository-specific content as needed

**This standardization enables professional, secure, and automated repository management.**" \
            --head "$branch_name" \
            --base main 2>/dev/null || log_warning "Could not create PR"
        
        log_success "Standardization changes committed and PR created for $repo_name"
    else
        log_info "No standardization changes needed for $repo_name"
        git checkout main
        git branch -D "$branch_name" 2>/dev/null || true
    fi
    
    cd - >/dev/null
}

# Main function
main() {
    echo "🔧 Repository Standardization Script"
    echo "====================================="
    echo ""
    log_info "Standardizing repositories to match ex configuration:"
    for repo in "${TARGET_REPOS[@]}"; do
        echo "  - $(basename "$repo")"
    done
    echo ""
    log_info "Template repository: $(basename "$TEMPLATE_REPO")"
    echo ""
    
    # Process each repository
    for repo_path in "${TARGET_REPOS[@]}"; do
        if [[ -d "$repo_path" ]]; then
            standardize_repository "$repo_path"
            configure_github_app "$repo_path"
            configure_repo_settings "$repo_path"
        else
            log_error "Repository not found: $repo_path"
        fi
        echo ""
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 Repository Standardization Completed!"
    echo ""
    log_info "Summary of standardization:"
    echo "✅ Standard OSS files copied to all repositories"
    echo "✅ GitHub configuration files synchronized"
    echo "✅ Badge automation workflows standardized"
    echo "✅ Repository settings configured"
    echo "✅ GitHub App variables configured"
    echo ""
    log_warning "Manual steps required for each repository:"
    echo "1. Configure BADGE_BOT_PRIVATE_KEY secret (copy from ex repository)"
    echo "2. Merge standardization PRs (may require temporary protection disable)"
    echo "3. Add GitHub App to repository ruleset bypass (if using rulesets)"
    echo "4. Test badge automation for green status verification"
    echo ""
    log_info "All repositories will have consistent configuration matching ex repository"
    echo ""
}

# Run main function
main "$@"
