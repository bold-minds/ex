# Badge Automation Troubleshooting Guide

## Overview

This guide documents the complete solution for GitHub App-based badge automation with repository ruleset bypass, based on real-world troubleshooting and research-backed fixes.

## ✅ **Verified Working Solution**

The following configuration achieves **green status on Actions/Checks** with complete badge automation:

### 1. **GitHub App Configuration**
- **App ID**: Must be stored as repository variable `BADGE_BOT_APP_ID`
- **Private Key**: Must be stored as repository secret `BADGE_BOT_PRIVATE_KEY`
- **Permissions**: Contents: Read/Write, Metadata: Read, Pull requests: Read

### 2. **Repository Ruleset Bypass** (CRITICAL)
- GitHub App must be added to repository ruleset bypass list
- **Bypass mode**: `always`
- **Location**: https://github.com/REPO_OWNER/REPO_NAME/settings/rules
- **Action**: Edit main branch ruleset → Add GitHub App ID to bypass actors

### 3. **Workflow Authentication** (CRITICAL)
```yaml
- name: Checkout
  uses: actions/checkout@v4
  with:
    persist-credentials: false  # CRITICAL: Prevents token conflicts

- name: Commit Badge Updates
  env:
    GITHUB_TOKEN: ${{ steps.app-token.outputs.token }}
  run: |
    # Configure git with GitHub App identity and authentication
    git config --global user.name "Badge Automation Bot"
    git config --global user.email "action@github.com"
    
    # CRITICAL: Configure git to use the GitHub App token for authentication
    git config --global url."https://x-access-token:${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"
    
    # Standard badge commit logic
    git add .github/badges/
    if git diff --staged --quiet; then
      echo "No badge changes to commit"
    else
      git commit -m "chore: update badges from CI run ${{ github.run_number }} [skip ci]"
      git push origin HEAD:main
    fi
```

## 🔍 **Common Issues and Solutions**

### Issue 1: `GH013: Repository rule violations found`
**Cause**: GitHub App not in repository ruleset bypass list
**Solution**: Add GitHub App ID to ruleset bypass with `bypass_mode: always`

### Issue 2: `fatal: could not read Username for 'https://github.com'`
**Cause**: Missing git authentication configuration
**Solution**: Configure git URL rewriting with GitHub App token

### Issue 3: `persist-credentials` Token Conflicts
**Cause**: `actions/checkout` persisting default `GITHUB_TOKEN` in git config
**Solution**: Set `persist-credentials: false` in checkout step

### Issue 4: `GH006: Protected branch update failed`
**Cause**: Branch protection rules blocking commits (separate from rulesets)
**Solution**: Ensure GitHub App bypass is configured for both rulesets AND branch protection

## 🚨 **Critical Requirements Checklist**

Before badge automation will work, verify:

- [ ] **GitHub App created** with Contents: Read/Write permissions
- [ ] **GitHub App installed** on repository/organization
- [ ] **Private key generated** and stored as repository secret
- [ ] **App ID stored** as repository variable `BADGE_BOT_APP_ID`
- [ ] **Private key stored** as repository secret `BADGE_BOT_PRIVATE_KEY`
- [ ] **Repository ruleset bypass** configured with GitHub App ID
- [ ] **Workflow uses** `persist-credentials: false` in checkout
- [ ] **Git URL rewriting** configured for GitHub App token authentication
- [ ] **Branch protection bypass** configured if using branch protection rules

## 🔧 **Testing and Validation**

### Test Badge Automation
1. **Push a change** to main branch
2. **Monitor workflow** for successful completion
3. **Check badge files** are updated in `.github/badges/`
4. **Verify commit attribution** shows "Badge Automation Bot"
5. **Confirm green status** on Actions/Checks

### Troubleshooting Steps
1. **Check workflow logs** for specific error messages
2. **Verify GitHub App token** generation is successful
3. **Confirm repository ruleset** bypass configuration
4. **Test with protection disabled** if needed for isolation
5. **Re-enable protection** once badge automation works

## 📚 **Research References**

- **GitHub Community Discussion**: https://github.com/orgs/community/discussions/72173
- **Stack Overflow**: https://stackoverflow.com/questions/77433427/why-do-bypass-settings-in-github-actions-rulesets-not-apply
- **GitHub Actions Checkout**: https://github.com/actions/checkout/issues/485

## 🎯 **Success Criteria**

Badge automation is working correctly when:
- ✅ **Main branch has green status** on Actions/Checks
- ✅ **Badge files are updated** automatically after test runs
- ✅ **Commits show proper attribution** ("Badge Automation Bot")
- ✅ **No repository rule violations** in workflow logs
- ✅ **Enterprise-grade automation** across multiple repositories

---

*This guide is based on real-world troubleshooting and research-backed solutions that achieved green status on main branch Actions/Checks.*
