# Picflow Releases & Updates

Complete guide for managing Picflow releases and automatic updates using Sparkle 2, GitHub Releases, and Amazon S3.

---

## Table of Contents

1. [Overview](#overview)
2. [How Updates Work](#how-updates-work)
3. [One-Time Setup](#one-time-setup)
4. [Release Process](#release-process)
5. [Troubleshooting](#troubleshooting)
6. [Advanced Topics](#advanced-topics)

---

## Overview

Picflow uses **Sparkle 2** (industry standard) for automatic updates, distributed via **GitHub Releases** and **Amazon S3**.

### Why This Setup?

✅ **Sparkle 2** - Industry standard, free, secure, feature-complete  
✅ **GitHub Releases** - Version control integrated, free hosting  
✅ **S3 + CloudFront** - Fast global CDN, reliable delivery  
✅ **Automated** - GitHub Actions sync releases to S3 automatically  
✅ **Dual URLs** - Versioned for Sparkle, static for marketing  

### Update Flow

```
User's Mac                    Picflow CDN
     │                              │
     ├─1. Check for updates ───────>│ appcast.xml
     │                              │
     │<─2. New version available ───┤
     │                              │
     ├─3. Download DMG ─────────────>│ Picflow-0.2.0.dmg
     │                              │
     ├─4. Verify signatures          │
     ├─5. Install & relaunch         │
```

**Release time:** ~7-12 minutes per version  
**Setup time:** ~30 minutes (one-time)  
**Cost:** Free (GitHub) + minimal S3/CloudFront costs

---

## How Updates Work

### Dual URL Strategy

**1. Versioned URLs** (for Sparkle 2 auto-updates)
```
https://picflow.com/download/macos/Picflow-0.1.0.dmg
https://picflow.com/download/macos/Picflow-0.2.0.dmg
https://picflow.com/download/macos/Picflow-0.3.0.dmg
```
- Each has a unique EdDSA signature
- Used by Sparkle 2 for verified updates
- Must remain permanent and unchanged
- Signature verification fails if file changes

**2. Static URL** (for marketing/emails)
```
https://picflow.com/download/macos/Picflow.dmg (always latest)
```
- Overwritten with each release
- Always points to the newest version
- Used in emails, website, documentation
- No signature verification needed

### Technical Details

#### 1. Sparkle Framework
- **Version:** Sparkle 2.x
- **Integration:** Swift Package Manager
- **Signing:** EdDSA (modern, secure)
- **Check frequency:** Daily (configurable)

#### 2. Update Feed (appcast.xml)
Sparkle 2 format XML file listing available versions:
```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Picflow Updates</title>
        <link>https://picflow.com/download/macos/appcast.xml</link>
        <item>
            <title>Version 0.2.0</title>
            <sparkle:version>0.2.0</sparkle:version>
            <sparkle:shortVersionString>0.2.0</sparkle:shortVersionString>
            <pubDate>Wed, 29 Oct 2025 14:00:00 +0000</pubDate>
            <enclosure 
                url="https://picflow.com/download/macos/Picflow-0.2.0.dmg"
                sparkle:edSignature="EDDSA_SIGNATURE_HERE"
                length="3953599"
                type="application/octet-stream"
            />
        </item>
    </channel>
</rss>
```

#### 3. Version Comparison
Sparkle compares `CFBundleShortVersionString` in app's Info.plist with latest version in appcast.xml using semantic versioning (MAJOR.MINOR.PATCH).

#### 4. Security (Triple Layer)
- **Apple Code Signing** - Verified by macOS Gatekeeper
- **Apple Notarization** - Malware scan by Apple
- **Sparkle EdDSA Signature** - Prevents tampering with updates

---

## One-Time Setup

### Step 1: Install Tools (5 minutes)

```bash
# Install required tools via Homebrew
brew install create-dmg gh

# Optional: Prettier Xcode output
gem install xcpretty

# Python cryptography library for EdDSA signing
pip3 install cryptography
```

**Verify:**
```bash
which create-dmg && which gh && python3 -c "import cryptography; print('✓')"
# Should show paths and checkmark ✓
```

---

### Step 2: Generate Sparkle Keys (5 minutes)

#### 2.1: Generate EdDSA Key Pair
```bash
# Create directory for keys
mkdir -p ~/.sparkle

# Generate Ed25519 private key
openssl genpkey -algorithm Ed25519 -out ~/.sparkle/private_key

# Extract public key
openssl pkey -in ~/.sparkle/private_key -pubout -outform DER | tail -c 32 | base64
```

**Copy the public key** - you'll need it next.

#### 2.2: Add Public Key to Info.plist

Open `Picflow/Info.plist` and add:
```xml
<key>SUPublicEDKey</key>
<string>PASTE_YOUR_PUBLIC_KEY_HERE</string>
<key>SUFeedURL</key>
<string>https://picflow.com/download/macos/appcast.xml</string>
<key>SUEnableAutomaticChecks</key>
<true/>
<key>SUScheduledCheckInterval</key>
<integer>86400</integer><!-- Check daily -->
```

---

### Step 3: Configure GitHub Repository (5 minutes)

#### 3.1: Authenticate gh CLI
```bash
gh auth login
# Follow prompts to authenticate
```

#### 3.2: Update Release Script

Edit `scripts/release.sh`:

**Lines 17-22:**
```bash
DEVELOPER_ID="Developer ID Application: YOUR NAME (YOUR_TEAM_ID)"
NOTARIZATION_PROFILE="notarytool"
SPARKLE_KEY_PATH="$HOME/.sparkle/private_key"
GITHUB_REPO="your-username/picflow-macos"
APPCAST_URL="https://picflow.com/download/macos/appcast.xml"
```

**Find your Developer ID:**
```bash
security find-identity -v -p codesigning
# Look for: "Developer ID Application: Your Name (XXXXXXXXXX)"
```

---

### Step 4: Configure Apple Notarization (5 minutes)

#### 4.1: Get App-Specific Password
1. Go to https://appleid.apple.com
2. Sign in
3. **Security** → **App-Specific Passwords**
4. Click **+** to generate
5. Label: `Picflow Notarization`
6. **Copy the password** (format: xxxx-xxxx-xxxx-xxxx)

#### 4.2: Store in Keychain
```bash
xcrun notarytool store-credentials notarytool \
  --apple-id "your-email@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

**Verify:**
```bash
xcrun notarytool history --keychain-profile notarytool
# Should list recent notarizations (or empty) ✓
```

---

### Step 5: Configure GitHub Action for S3 Sync (5 minutes)

The GitHub Action (`.github/workflows/sync-release-to-s3.yml`) automatically syncs releases to S3.

#### 5.1: Add GitHub Secrets

Go to your GitHub repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these three secrets:
- `AWS_ACCESS_KEY_ID` - Your AWS access key
- `AWS_SECRET_ACCESS_KEY` - Your AWS secret key  
- `AWS_DEFAULT_REGION` - Your S3 region (e.g., `us-east-1`)

#### 5.2: Configure Production Environment

Go to **Settings** → **Environments** → **New environment** → Name: `production`

This allows the workflow to access the secrets.

---

### Step 6: Enable Hardened Runtime (Already Done)

Hardened Runtime is required for notarization. This is already enabled in the Xcode project:

```xml
<!-- In Picflow macOS.xcodeproj/project.pbxproj -->
ENABLE_HARDENED_RUNTIME = YES;
```

**Verify in Xcode:**
- Select target → **Signing & Capabilities**
- **Hardened Runtime** should be enabled ✓

---

### Step 7: Test First Release (10 minutes)

#### 7.1: Update Version in Xcode
1. Open `Picflow macOS.xcodeproj`
2. Select target **Picflow**
3. **General** tab
4. Set **Version** to `0.1.0`
5. Set **Build** to `1`

#### 7.2: Run Test Release
```bash
./scripts/release.sh 0.1.0
```

**Expected output:**
```
╔═══════════════════════════════════════╗
║   Picflow Release Automation          ║
║   Version: 0.1.0                      ║
╚═══════════════════════════════════════╝

==> Checking requirements...
✅ All requirements satisfied

==> Archiving Picflow...
✅ Archive created

==> Exporting and re-signing Picflow.app...
✅ App exported and re-signed

==> Creating DMG...
✅ DMG created: build/Picflow-0.1.0.dmg

==> Verifying app signature...
✅ App is properly signed

==> Notarizing DMG (may take 3-5 minutes)...
✅ DMG notarized and stapled

==> Creating latest DMG copy...
✅ Latest DMG created: build/Picflow.dmg

==> Signing versioned DMG with Sparkle 2...
✅ Sparkle 2 EdDSA signature generated

==> Creating GitHub release...
✅ GitHub release created: v0.1.0

==> Uploading assets to GitHub release...
✅ Both DMGs uploaded to GitHub release

==> Creating appcast.xml...
✅ appcast.xml created and uploaded

╔═══════════════════════════════════════╗
║   🎉 Release Complete!                ║
╚═══════════════════════════════════════╝
```

#### 7.3: Verify GitHub Action Ran

```bash
# Check recent workflow runs
gh run list --limit 1

# Should show:
# completed  success  Picflow 0.1.0  Sync Release to S3
```

#### 7.4: Verify Files on S3

Check that files are accessible:
```bash
# Test appcast.xml
curl -I https://picflow.com/download/macos/appcast.xml
# Should return: HTTP/2 200

# Test versioned DMG
curl -I https://picflow.com/download/macos/Picflow-0.1.0.dmg
# Should return: HTTP/2 200

# Test latest DMG
curl -I https://picflow.com/download/macos/Picflow.dmg
# Should return: HTTP/2 200
```

---

### ✅ Setup Complete!

**Setup time:** ~30 minutes (one-time)

**Quick Setup Checklist:**
- ☐ Tools installed (create-dmg, gh, Python cryptography)
- ☐ Sparkle EdDSA keys generated
- ☐ Public key added to Info.plist
- ☐ GitHub CLI authenticated
- ☐ Release script updated with credentials
- ☐ Apple notarization configured
- ☐ GitHub Action secrets configured
- ☐ Test release successful
- ☐ GitHub Action synced to S3
- ☐ URLs accessible

**Future releases:** Just run `./scripts/release.sh X.Y.Z`

---

## Release Process

### Quick Release (One Command)

```bash
./scripts/release.sh 0.2.0
```

That's it! The script handles everything automatically.

---

### What Happens During Release

The script and GitHub Action perform these steps:

1. **Check requirements** - Verify all tools installed (~5 sec)
2. **Archive app** - Build release in Xcode (~2-3 min)
3. **Export & re-sign** - Deep sign all frameworks and app (~30 sec)
4. **Create DMG** - Package as disk image (~30 sec)
5. **Verify signature** - Check app signature (~5 sec)
6. **Notarize** - Submit to Apple for verification (~3-5 min)
7. **Create latest DMG** - Copy notarized DMG for marketing (~5 sec)
8. **Sign with Sparkle** - Generate EdDSA signature (~5 sec)
9. **Create GitHub release** - Create release on GitHub (~5 sec)
10. **Upload DMGs** - Upload both DMGs to GitHub (~10-30 sec)
11. **Upload appcast** - Upload Sparkle feed (~5 sec)
12. **GitHub Action** - Syncs to S3 automatically (~1-2 min)

**Total time:** ~7-12 minutes (notarization is the slowest step)

---

### Before Each Release

#### 1. Update Version Number in Xcode
- Open `Picflow macOS.xcodeproj`
- Select target → **General**
- **Version:** Use semantic versioning (e.g., `0.2.0`)
- **Build:** Increment by 1

#### 2. Test Build Locally
```bash
# In Xcode: Product → Run
# Verify everything works before releasing
```

#### 3. Commit Changes
```bash
git add .
git commit -m "Version 0.2.0: Add new features"
git push origin main
```

#### 4. Run Release Script
```bash
./scripts/release.sh 0.2.0
```

---

### After Each Release

#### 1. Monitor GitHub Action

```bash
# Watch the sync to S3
gh run watch

# Should complete in ~1-2 minutes
```

#### 2. Test the URLs

```bash
# Verify all files are accessible
curl -I https://picflow.com/download/macos/appcast.xml
curl -I https://picflow.com/download/macos/Picflow-0.2.0.dmg
curl -I https://picflow.com/download/macos/Picflow.dmg
```

#### 3. Test the Update Flow

On a machine with an older version:
1. Open Picflow
2. Wait for automatic update check (or trigger manually)
3. Verify update downloads and installs
4. Confirm app relaunches with new version

#### 4. Monitor

- Check Sentry for new errors
- Check analytics for update adoption rate
- Monitor CloudWatch for S3/CloudFront usage

---

## Troubleshooting

### Setup Issues

#### "create-dmg: command not found"
```bash
brew install create-dmg
```

#### "gh: command not found"
```bash
brew install gh
gh auth login
```

#### "No module named 'cryptography'"
```bash
pip3 install cryptography
```

#### "Can't generate Sparkle keys"
```bash
# Ensure OpenSSL is installed
brew install openssl

# Generate keys manually
mkdir -p ~/.sparkle
openssl genpkey -algorithm Ed25519 -out ~/.sparkle/private_key
openssl pkey -in ~/.sparkle/private_key -pubout -outform DER | tail -c 32 | base64
```

---

### Release Issues

#### "Xcode command line tools not found"
```bash
xcode-select --install
```

#### "Sparkle private key not found"
```bash
# Check if file exists
ls -la ~/.sparkle/private_key

# If missing, regenerate (see Step 2)
```

#### "Notarization failed"
Check logs:
```bash
xcrun notarytool log <submission-id> \
  --keychain-profile notarytool
```

**Common causes:**
- Hardened Runtime not enabled
- Missing entitlements
- Unsigned frameworks

#### "Code signing failed"
```bash
# List available certificates
security find-identity -v -p codesigning

# Verify Developer ID certificate exists
# If expired, renew at developer.apple.com
```

#### "GitHub release creation failed"
```bash
# Check authentication
gh auth status

# Re-authenticate if needed
gh auth login
```

#### "GitHub Action failed to sync to S3"

Check the workflow logs:
```bash
gh run view --log
```

**Common causes:**
- Missing or incorrect AWS secrets
- S3 bucket permissions
- Incorrect S3 paths in workflow

---

### User Issues

#### "Users not receiving updates"

**Checklist:**
1. ✅ Check appcast.xml is accessible:
   ```bash
   curl https://picflow.com/download/macos/appcast.xml
   ```
2. ✅ Verify version in appcast is higher than user's version
3. ✅ Check user has "Automatically update" enabled in Settings
4. ✅ Verify SUFeedURL in Info.plist matches appcast URL
5. ✅ Check Sparkle public key in Info.plist is correct

#### "Update downloads but won't install"
- Check code signature: `codesign -dvv Picflow.app`
- Check notarization: `spctl -a -vv -t install Picflow.app`
- Verify user has admin privileges (required for installation)

#### "Update fails with signature error"
- Sparkle public key in Info.plist doesn't match private key
- Re-generate keys and update Info.plist
- Release new version with correct key

---

## Advanced Topics

### Rollback a Release

If you need to pull back a bad release:

```bash
# 1. Delete GitHub release
gh release delete v0.2.0 --yes

# 2. Delete git tag
git tag -d v0.2.0
git push origin :refs/tags/v0.2.0

# 3. Manually remove files from S3 if needed
# (GitHub Action only adds/overwrites, doesn't delete)
```

Users will see the previous version as latest in appcast.xml.

---

### Critical Security Updates

For urgent security fixes, mark update as critical:

**Edit appcast.xml manually and re-upload:**
```xml
<item>
    <title>Version 0.2.1 (Critical Security Update)</title>
    <sparkle:version>0.2.1</sparkle:version>
    <sparkle:criticalUpdate>true</sparkle:criticalUpdate>  <!-- Add this -->
    <!-- ... rest of item ... -->
</item>
```

Users will be **required** to update before continuing.

---

### Delta Updates

Sparkle 2 supports delta updates (only download changed files) for bandwidth savings. This requires additional setup with `generate_appcast` tool from Sparkle.

**Benefits:**
- 50-90% bandwidth savings
- Faster updates
- Better user experience

See [Sparkle documentation](https://sparkle-project.org/documentation/delta-updates/) for details.

---

## Quick Reference

### Common Commands

```bash
# Release new version
./scripts/release.sh 0.2.0

# Check GitHub Actions status
gh run list --limit 5

# Watch latest workflow run
gh run watch

# View workflow logs
gh run view --log

# Test URLs
curl -I https://picflow.com/download/macos/appcast.xml
curl -I https://picflow.com/download/macos/Picflow.dmg

# Check notarization status
xcrun notarytool history --keychain-profile notarytool

# Verify code signature
codesign -dvv Picflow.app

# Check certificate expiry
security find-identity -v -p codesigning
```

### File Locations

- **Sparkle private key:** `~/.sparkle/private_key`
- **Build output:** `build/`
- **Release script:** `scripts/release.sh`
- **GitHub Action:** `.github/workflows/sync-release-to-s3.yml`
- **Info.plist:** `Picflow/Info.plist`
- **S3 bucket:** `s3://picflow-webapp-prod/download/macos/`
- **Public URLs:** `https://picflow.com/download/macos/`

---

## Resources

### Documentation
- **Sparkle 2:** https://sparkle-project.org/documentation/
- **Sparkle GitHub:** https://github.com/sparkle-project/Sparkle
- **Apple Notarization:** https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
- **GitHub Actions:** https://docs.github.com/en/actions

### Tools
- **create-dmg:** https://github.com/create-dmg/create-dmg
- **gh CLI:** https://cli.github.com/
- **Python cryptography:** https://cryptography.io/

---

## Summary

**Setup:** ~30 minutes (one-time)  
**Release:** ~7-12 minutes (per version)  
**Automation:** 95% (one command + GitHub Action)  
**Distribution:** GitHub Releases → S3 → CloudFront → Users

**Workflow:**
1. Developer runs: `./scripts/release.sh X.Y.Z`
2. Script builds, signs, notarizes, uploads to GitHub
3. GitHub Action syncs to S3 automatically
4. Users get update notification via Sparkle 2
5. One-click install for users

**Next Steps:**
1. ✅ Complete one-time setup
2. ✅ Test first release
3. ✅ Verify GitHub Action syncs to S3
4. 🚀 Ship updates to users!

Happy releasing! 🎉
