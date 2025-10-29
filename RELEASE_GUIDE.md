# Picflow Release Guide

Complete guide for releasing new versions of Picflow macOS app with automatic updates via Sparkle 2.

---

## Quick Start (For Regular Releases)

If you've already completed the one-time setup, releasing a new version takes ~7-12 minutes:

### 1. Update Version Numbers

**CRITICAL:** You must update **BOTH** files or the build will have the wrong version:

**a) Update `Picflow/Info.plist`:**
```xml
<key>CFBundleShortVersionString</key>
<string>0.1.10</string>  <!-- Change this -->
<key>CFBundleVersion</key>
<string>10</string>      <!-- Increment this -->
```

**b) Update `Picflow macOS.xcodeproj/project.pbxproj`:**

Find and replace both occurrences (Debug and Release):
```
MARKETING_VERSION = 0.1.9;  →  MARKETING_VERSION = 0.1.10;
CURRENT_PROJECT_VERSION = 9;  →  CURRENT_PROJECT_VERSION = 10;
```

### 2. Commit and Push
```bash
git add .
git commit -m "Version 0.1.10: Brief description of changes"
git push origin main
```

### 3. Run Release Script
```bash
./scripts/release.sh 0.1.10
```

The script will automatically:
- ✅ Build and archive (~2-3 min)
- ✅ Code sign with Developer ID
- ✅ Create and notarize DMG (~3-5 min)
- ✅ Sign with Sparkle 2 EdDSA
- ✅ Create GitHub release
- ✅ Upload files and appcast.xml

### 4. Wait for GitHub Action

The sync to S3 happens automatically (~1-2 min). Verify:
```bash
gh run list --limit 1  # Check status
curl -I https://picflow.com/download/macos/appcast.xml  # Test URL
```

**Done!** Users will receive the update notification within 24 hours.

---

## Version Numbering

Use semantic versioning: `MAJOR.MINOR.PATCH`

- **PATCH** (0.1.X): Bug fixes, small improvements
- **MINOR** (0.X.0): New features, UI changes  
- **MAJOR** (X.0.0): Major overhaul, breaking changes

---

## How Updates Work

### The Update Flow

```
User's Mac                    Picflow CDN
     │                              │
     ├─1. Check for updates ───────>│ appcast.xml
     │                              │
     │<─2. New version available ───┤
     │                              │
     ├─3. Download DMG ─────────────>│ Picflow-0.1.10.dmg
     │                              │
     ├─4. Verify EdDSA signature     │
     ├─5. Install & relaunch         │
```

### Dual URL Strategy

**Versioned URLs** (for Sparkle 2):
- `https://picflow.com/download/macos/Picflow-0.1.9.dmg`
- `https://picflow.com/download/macos/Picflow-0.1.10.dmg`
- Each has unique EdDSA signature
- Must remain permanent

**Static URL** (for marketing):
- `https://picflow.com/download/macos/Picflow.dmg`
- Always points to latest version
- Use in emails, website, docs

### Security (Triple Layer)

1. **Apple Code Signing** - Verified by macOS Gatekeeper
2. **Apple Notarization** - Malware scan by Apple  
3. **Sparkle EdDSA Signature** - Prevents tampering

---

## One-Time Setup

**Skip this if already configured.** Setup takes ~30 minutes.

### Prerequisites

Install required tools:
```bash
brew install create-dmg gh
pip3 install cryptography
```

### 1. Generate Sparkle Keys

```bash
# Create directory
mkdir -p ~/.sparkle

# Generate Ed25519 private key
openssl genpkey -algorithm Ed25519 -out ~/.sparkle/private_key

# Extract public key (copy this output)
openssl pkey -in ~/.sparkle/private_key -pubout -outform DER | tail -c 32 | base64
```

### 2. Add Keys to Info.plist

Edit `Picflow/Info.plist` and add (if not already present):
```xml
<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_KEY_FROM_ABOVE</string>
<key>SUFeedURL</key>
<string>https://picflow.com/download/macos/appcast.xml</string>
<key>SUEnableAutomaticChecks</key>
<true/>
<key>SUScheduledCheckInterval</key>
<integer>86400</integer><!-- Check daily -->
```

### 3. Configure GitHub CLI

```bash
gh auth login
# Follow prompts
```

### 4. Configure Apple Notarization

**a) Get App-Specific Password:**
1. Go to https://appleid.apple.com → Security
2. Generate app-specific password
3. Label: "Picflow Notarization"
4. Copy the password (format: xxxx-xxxx-xxxx-xxxx)

**b) Store in Keychain:**
```bash
xcrun notarytool store-credentials notarytool \
  --apple-id "your-email@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

**c) Verify:**
```bash
xcrun notarytool history --keychain-profile notarytool
```

### 5. Configure GitHub Secrets

Go to repo → Settings → Secrets → Actions → New secret:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_DEFAULT_REGION` (e.g., `us-east-1`)

Create environment: Settings → Environments → `production`

### 6. Update Release Script

Edit `scripts/release.sh` lines 30-33:
```bash
DEVELOPER_ID="Developer ID Application: YOUR NAME (TEAM_ID)"
NOTARIZATION_PROFILE="notarytool"
GITHUB_REPO="nusign/picflow-macos"
APPCAST_URL="https://picflow.com/download/macos/appcast.xml"
```

Find your Developer ID:
```bash
security find-identity -v -p codesigning
```

---

## Common Issues

### "Version in DMG doesn't match"

**Problem:** Built app shows old version number.

**Solution:** You must update BOTH `Info.plist` AND `project.pbxproj`. The Info.plist value takes precedence.

```bash
# Verify both are updated:
grep "CFBundleShortVersionString" Picflow/Info.plist
grep "MARKETING_VERSION" "Picflow macOS.xcodeproj/project.pbxproj"
```

### "Users not receiving update"

**Checklist:**
1. Verify appcast is accessible:
   ```bash
   curl https://picflow.com/download/macos/appcast.xml | grep version
   ```
2. Check version in appcast is higher than user's current version
3. Wait 24 hours (Sparkle checks daily by default)
4. User can manually check: Picflow menu → Check for Updates

### "Notarization failed"

Check logs:
```bash
xcrun notarytool log <submission-id> --keychain-profile notarytool
```

Common causes:
- Hardened Runtime not enabled (already configured in project)
- Developer ID certificate expired (renew at developer.apple.com)
- Missing entitlements (already configured)

### "Build fails in release script"

```bash
# Clean build and try again:
rm -rf build/*
xcodebuild clean -project "Picflow macOS.xcodeproj" -scheme Picflow -configuration Release
./scripts/release.sh X.Y.Z
```

### "GitHub Action failed"

```bash
# Check logs:
gh run view --log

# Common causes:
# - AWS credentials incorrect
# - S3 bucket permissions
# - Network issue (re-run workflow)
```

---

## Advanced Topics

### Rollback a Release

If you need to revert a bad release:

```bash
# 1. Delete GitHub release
gh release delete vX.Y.Z --yes

# 2. Delete git tag
git tag -d vX.Y.Z
git push origin :refs/tags/vX.Y.Z

# 3. Manually remove from S3 if needed
# (GitHub Action doesn't delete old versions)
```

Users will see the previous version as latest.

### Critical Security Updates

Mark update as required:

Edit `appcast.xml` manually and re-upload:
```xml
<item>
    <title>Version 0.2.1 (Critical Security Update)</title>
    <sparkle:version>0.2.1</sparkle:version>
    <sparkle:criticalUpdate>true</sparkle:criticalUpdate>
    <!-- ... -->
</item>
```

Users will be **forced** to update.

### Testing Before Release

Test locally without releasing:

```bash
# Build without releasing:
xcodebuild archive \
  -project "Picflow macOS.xcodeproj" \
  -scheme Picflow \
  -configuration Release \
  -archivePath build/Picflow.xcarchive

# Check version:
plutil -p build/Picflow.xcarchive/Products/Applications/Picflow.app/Contents/Info.plist | grep Version
```

---

## Files and URLs

### Local Files (after release)
- `build/Picflow-X.Y.Z.dmg` - Versioned, signed, notarized
- `build/Picflow.dmg` - Copy for marketing
- `build/RELEASE-X.Y.Z.md` - Release notes

### Production URLs
- **Update feed:** https://picflow.com/download/macos/appcast.xml
- **Versioned DMG:** https://picflow.com/download/macos/Picflow-X.Y.Z.dmg
- **Latest DMG:** https://picflow.com/download/macos/Picflow.dmg (marketing)
- **GitHub:** https://github.com/nusign/picflow-macos/releases

### Key Files in Repository
- `Picflow/Info.plist` - App version (must update for each release)
- `Picflow macOS.xcodeproj/project.pbxproj` - Build version (must update)
- `scripts/release.sh` - Release automation script
- `.github/workflows/sync-release-to-s3.yml` - Auto-sync to S3
- `~/.sparkle/private_key` - EdDSA signing key (keep secret!)

---

## Troubleshooting Commands

```bash
# Verify current version
plutil -p Picflow/Info.plist | grep CFBundleShortVersionString

# Check GitHub releases
gh release list --limit 5

# Watch GitHub Action
gh run list --limit 1

# Test URLs
curl -I https://picflow.com/download/macos/appcast.xml
curl -I https://picflow.com/download/macos/Picflow.dmg

# Check notarization history
xcrun notarytool history --keychain-profile notarytool

# Verify code signing
codesign -dvv /Applications/Picflow.app

# Check certificate expiry
security find-identity -v -p codesigning
```

---

## Summary

**Regular Release Process:**
1. Update `Info.plist` and `project.pbxproj` versions
2. Commit and push
3. Run `./scripts/release.sh X.Y.Z`
4. Wait for GitHub Action (~1-2 min)
5. Done! Users get updates within 24 hours

**Total Time:** ~7-12 minutes (notarization is slowest)

**Distribution Flow:**
```
Developer → GitHub Release → GitHub Action → S3/CloudFront → Users (Sparkle 2)
```

**For Questions:**
- Sparkle docs: https://sparkle-project.org/documentation/
- GitHub Actions: https://docs.github.com/en/actions
- Apple notarization: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution

---

**Last Updated:** October 29, 2025

