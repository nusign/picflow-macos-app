# Sparkle 2 Setup for Picflow

Complete guide for Sparkle 2 automatic updates with dual URL strategy.

---

## Overview

Picflow uses **Sparkle 2** for automatic updates with a sophisticated dual URL strategy for optimal user experience and secure delivery.

### Distribution Architecture

```
Developer                 GitHub                  S3/CloudFront              Users
    │                        │                          │                       │
    ├─ Build & Sign ────────>│                          │                       │
    ├─ Create Release ───────>│                          │                       │
    │                        │                          │                       │
    │                        ├─ GitHub Action ─────────>│                       │
    │                        │  (Auto-sync)             │                       │
    │                        │                          │                       │
    │                        │                          ├─ Check Updates ──────>│
    │                        │                          │<─ Download DMG ───────┤
    │                        │                          │                       │
```

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

### Why Both?

**Sparkle 2 requires versioned URLs** because:
- Each DMG has a unique EdDSA signature based on binary content
- If you replace `Picflow.dmg` with v0.2.0, but appcast.xml has v0.1.0's signature → verification fails
- Sparkle won't install updates with mismatched signatures (security feature)

**But you also want a static URL** for:
- ✅ Email campaigns: "Download at picflow.com/download/macos/Picflow.dmg"
- ✅ Website download button (no version updates needed)
- ✅ Documentation with evergreen links
- ✅ Users always get the latest version

---

## How It Works

### 1. Release Script Creates Both Files

```bash
./scripts/release.sh 0.2.0
```

**Creates:**
- `Picflow-0.2.0.dmg` - Signed with Sparkle 2 EdDSA (for auto-updates)
- `Picflow.dmg` - Exact byte-for-byte copy (for marketing)

**Both are:**
- ✅ Apple code-signed with Developer ID
- ✅ Apple notarized (malware scanned)
- ✅ Uploaded to GitHub release
- ✅ Synced to S3 by GitHub Action

**Time saved:** ~5 minutes by notarizing once and copying!

### 2. GitHub Action Syncs to S3

When a release is published, GitHub Action automatically:
1. Downloads all release assets
2. Uploads to `s3://picflow-webapp-prod/download/macos/`
3. Overwrites `Picflow.dmg` with latest version
4. Keeps all versioned DMGs permanently
5. Updates appcast.xml

### 3. Sparkle 2 Checks for Updates

**User's Mac:**
```
App checks: https://picflow.com/download/macos/appcast.xml
```

**appcast.xml (Sparkle 2 format):**
```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Picflow Updates</title>
        <link>https://picflow.com/download/macos/appcast.xml</link>
        <language>en</language>
        <item>
            <title>Version 0.2.0</title>
            <sparkle:version>0.2.0</sparkle:version>
            <sparkle:shortVersionString>0.2.0</sparkle:shortVersionString>
            <pubDate>Wed, 29 Oct 2025 14:00:00 +0000</pubDate>
            <enclosure 
                url="https://picflow.com/download/macos/Picflow-0.2.0.dmg"
                sparkle:edSignature="UNIQUE_EDDSA_SIGNATURE_HERE"
                length="3953599"
                type="application/octet-stream"
            />
        </item>
    </channel>
</rss>
```

**Key Points:**
- ✅ Uses versioned URL: `Picflow-0.2.0.dmg`
- ✅ Has unique EdDSA signature
- ✅ Sparkle 2 namespace: `xmlns:sparkle="..."`
- ✅ EdDSA signature: `sparkle:edSignature="..."`
- ✅ Semantic versioning: `MAJOR.MINOR.PATCH`

---

## Configuration

### Info.plist

Add to `Picflow/Info.plist`:

```xml
<!-- Sparkle 2 Configuration -->
<key>SUPublicEDKey</key>
<string>YOUR_SPARKLE_PUBLIC_KEY_HERE</string>
<key>SUFeedURL</key>
<string>https://picflow.com/download/macos/appcast.xml</string>
<key>SUEnableAutomaticChecks</key>
<true/>
<key>SUScheduledCheckInterval</key>
<integer>86400</integer><!-- Check daily (86400 seconds) -->
```

### Generate Sparkle Keys (One-Time)

```bash
# 1. Create directory
mkdir -p ~/.sparkle

# 2. Generate Ed25519 private key
openssl genpkey -algorithm Ed25519 -out ~/.sparkle/private_key

# 3. Extract public key (base64 encoded)
openssl pkey -in ~/.sparkle/private_key -pubout -outform DER | tail -c 32 | base64

# Output: YOUR_PUBLIC_KEY_HERE
# Copy this to Info.plist (SUPublicEDKey)
```

**Keep private key safe:**
- Never commit to git
- Backup securely
- Required for all future releases

### Update release.sh

Edit `scripts/release.sh`:

```bash
DEVELOPER_ID="Developer ID Application: YOUR_NAME (YOUR_TEAM_ID)"
SPARKLE_KEY_PATH="$HOME/.sparkle/private_key"
GITHUB_REPO="your-username/picflow-macos"
APPCAST_URL="https://picflow.com/download/macos/appcast.xml"
```

---

## Release Process

### 1. Update Version in Xcode

- Open `Picflow macOS.xcodeproj`
- Target → General
- **Version:** Use semantic versioning (e.g., `0.2.0`)
  - MAJOR: Breaking changes
  - MINOR: New features
  - PATCH: Bug fixes
- **Build:** Increment by 1

### 2. Run Release Script

```bash
./scripts/release.sh 0.2.0
```

**What happens:**
1. ✅ Builds and archives app (~2-3 min)
2. ✅ Exports and deep signs with Developer ID (~30 sec)
3. ✅ Creates versioned DMG: `Picflow-0.2.0.dmg` (~30 sec)
4. ✅ Notarizes with Apple (~3-5 min)
5. ✅ Creates latest DMG: `Picflow.dmg` (copy, ~5 sec)
6. ✅ Signs versioned DMG with Sparkle 2 EdDSA (~5 sec)
7. ✅ Creates GitHub release with both DMGs (~10 sec)
8. ✅ Uploads appcast.xml (Sparkle 2 format) (~5 sec)

**Total time:** ~7-12 minutes (Apple notarization is slowest)

### 3. GitHub Action Syncs to S3

- Triggered automatically when release is published
- Syncs all files to S3 (~1-2 min)
- Overwrites `Picflow.dmg` with latest
- Updates appcast.xml

### 4. Users Get Updates

- Sparkle 2 checks appcast.xml daily
- Finds new version
- Downloads versioned DMG
- Verifies EdDSA signature
- Installs update
- Relaunches app

---

## File Structure

### S3 Bucket: `s3://picflow-webapp-prod/download/macos/`

```
download/macos/
├── appcast.xml                 # Sparkle 2 update feed
├── Picflow.dmg                 # Latest version (marketing, overwritten)
├── Picflow-0.1.0.dmg          # Version 0.1.0 (permanent)
├── Picflow-0.2.0.dmg          # Version 0.2.0 (permanent)
└── Picflow-0.3.0.dmg          # Version 0.3.0 (permanent)
```

### URLs

```
# Sparkle 2 checks this:
https://picflow.com/download/macos/appcast.xml

# Sparkle 2 downloads from this (versioned):
https://picflow.com/download/macos/Picflow-0.2.0.dmg

# Marketing/emails use this (always latest):
https://picflow.com/download/macos/Picflow.dmg
```

### Cache Control Headers

Set by GitHub Action for optimal delivery:

```bash
# Versioned DMGs (immutable)
Cache-Control: public, max-age=31536000, immutable
# 1 year cache, never changes

# Latest DMG (frequently updated)
Cache-Control: public, max-age=300
# 5 minutes cache

# appcast.xml (update feed)
Cache-Control: public, max-age=3600, must-revalidate
# 1 hour cache, revalidate
```

---

## Usage Examples

### In Marketing Emails

```html
<a href="https://picflow.com/download/macos/Picflow.dmg">
  Download Picflow for Mac
</a>
```

✅ Always points to latest version  
✅ No need to update links

### On Website

```html
<a href="https://picflow.com/download/macos/Picflow.dmg" 
   class="download-button">
  Download for macOS
</a>
```

### In Documentation

```markdown
Download Picflow: https://picflow.com/download/macos/Picflow.dmg
```

### For Specific Version (Support)

```markdown
If you need version 0.1.0 specifically:
https://picflow.com/download/macos/Picflow-0.1.0.dmg
```

---

## Sparkle 2 Features

### Automatic Updates

```swift
// Sparkle 2 checks daily (configured in Info.plist)
// No code needed - fully automatic

// Configured in Info.plist:
// SUScheduledCheckInterval = 86400 (24 hours)
```

### Manual Update Check

Add menu item to trigger manual check:

```swift
import Sparkle

// In your App Menu:
Button("Check for Updates...") {
    SPUStandardUpdaterController.shared().checkForUpdates(nil)
}
```

### Update Notifications

Users see a native macOS alert:
1. "A new version of Picflow is available!"
2. Release notes (from appcast.xml description)
3. "Install and Relaunch" button
4. "Skip This Version" option

### Silent Background Updates

Sparkle 2 features:
- Downloads updates in background
- Can download delta patches (smaller size)
- Installs on next launch (or prompts immediately)
- Respects user's auto-update preference

---

## Security

### Triple Layer Security

1. **Apple Code Signing**
   - Verified by macOS Gatekeeper
   - Ensures DMG is from verified developer
   - Certificate: `Developer ID Application`

2. **Apple Notarization**
   - Scanned for malware by Apple
   - Required for macOS 10.15+
   - Stapled to DMG for offline verification

3. **Sparkle 2 EdDSA Signature**
   - Prevents tampering with updates
   - Ensures update integrity
   - Private key never leaves developer's machine
   - Modern Ed25519 algorithm

### Signature Verification Flow

```
User's Mac                      CDN (S3/CloudFront)
     │                                 │
     ├─1. Check appcast ──────────────>│ appcast.xml
     │                                 │
     │<─2. New version available ──────┤ (with EdDSA signature)
     │                                 │
     ├─3. Download DMG ───────────────>│ Picflow-0.2.0.dmg
     │                                 │
     ├─4. Verify EdDSA signature       │
     │   (using public key in app)     │
     │                                 │
     ├─5. Verify Apple code signature  │
     │   (Gatekeeper)                  │
     │                                 │
     ├─6. Verify notarization ticket   │
     │   (stapled or online check)     │
     │                                 │
     ├─7. Install & relaunch           │
```

If any signature fails → update rejected ❌

---

## Troubleshooting

### "Signature verification failed"

**Cause:** EdDSA signature doesn't match DMG content

**Fix:**
1. Ensure you didn't modify DMG after signing
2. Re-run release script to regenerate signature
3. Verify public key in Info.plist matches private key

```bash
# Verify keys match
openssl pkey -in ~/.sparkle/private_key -pubout -outform DER | tail -c 32 | base64
# Should match SUPublicEDKey in Info.plist
```

### "Users not receiving updates"

**Checklist:**
- ✅ appcast.xml is accessible:
  ```bash
  curl https://picflow.com/download/macos/appcast.xml
  ```
- ✅ SUFeedURL in Info.plist matches appcast URL
- ✅ Version in appcast is higher than user's version (semantic versioning)
- ✅ Public key in Info.plist is correct
- ✅ User has "Automatically update" enabled in Settings
- ✅ At least 24 hours have passed since last check

### "Update downloads but won't install"

**Check:**
- Code signature:
  ```bash
  codesign -dvv Picflow-0.2.0.dmg
  # Should show: signed by Developer ID Application
  ```
- Notarization:
  ```bash
  spctl -a -vv -t install Picflow-0.2.0.dmg
  # Should show: accepted
  ```
- User has admin privileges (macOS requirement for app installation)

### "Update fails with 'Damaged' error"

**Causes:**
- Quarantine attribute on downloaded DMG
- Failed notarization
- Corrupted download

**Fix:**
```bash
# Check notarization status
spctl -a -vv -t install Picflow-0.2.0.dmg

# Re-download DMG
# Verify file size matches appcast.xml length attribute
```

---

## Advanced Topics

### Release Notes in Updates

Add formatted release notes in appcast.xml:

```xml
<item>
    <title>Version 0.2.0</title>
    <description><![CDATA[
        <h2>What's New in 0.2.0</h2>
        <ul>
            <li><strong>New:</strong> Capture One integration</li>
            <li><strong>Improved:</strong> Upload speed 2x faster</li>
            <li><strong>Fixed:</strong> Memory leak in live folder monitoring</li>
        </ul>
        <p>See <a href="https://picflow.com/changelog">full changelog</a>.</p>
    ]]></description>
    <!-- ... -->
</item>
```

Users see this formatted in the update alert.

### Critical Security Updates

For urgent security fixes, mark as critical:

```xml
<item>
    <title>Version 0.2.1 (Critical Security Update)</title>
    <sparkle:version>0.2.1</sparkle:version>
    <sparkle:criticalUpdate>true</sparkle:criticalUpdate>  <!-- Add this -->
    <!-- ... -->
</item>
```

Users **must** update before using the app.

### Beta Channel

Create separate beta update feed:

1. Create `appcast-beta.xml`
2. Use `SUFeedURL` based on build configuration:
   ```swift
   #if DEBUG
   let feedURL = "https://picflow.com/download/macos/appcast-beta.xml"
   #else
   let feedURL = "https://picflow.com/download/macos/appcast.xml"
   #endif
   ```
3. Release beta versions: `./scripts/release.sh 0.2.0-beta.1`

### Delta Updates

Sparkle 2 supports delta updates (only download changed files):

**Benefits:**
- 50-90% bandwidth savings
- Faster downloads
- Better user experience

Requires additional setup with `generate_appcast` tool. See [Sparkle documentation](https://sparkle-project.org/documentation/delta-updates/).

---

## Summary

### What You Get

✅ **Automatic updates** via Sparkle 2  
✅ **Versioned URLs** for secure signed updates  
✅ **Static URL** for marketing (`Picflow.dmg`)  
✅ **Triple security** (Apple signing + notarization + Sparkle EdDSA)  
✅ **One command releases** (`./scripts/release.sh X.Y.Z`)  
✅ **Automated workflow** (GitHub → S3 → CloudFront → Users)  
✅ **Fast delivery** via CloudFront CDN  
✅ **Cost-effective** (mostly free tier usage)

### Release Timeline

- **Build & sign:** ~5-10 minutes
- **GitHub Action sync:** ~1-2 minutes
- **CDN propagation:** ~5 minutes
- **Total:** ~10-20 minutes from script to users

### User Experience

1. User opens Picflow (or waits 24 hours)
2. Sparkle checks for updates (background, ~1 sec)
3. "Update available" notification appears
4. User clicks "Install and Relaunch"
5. Update downloads (~10-30 sec)
6. Signatures verified (~1 sec)
7. App relaunches with new version
8. Done! 🎉

**Zero friction for users, fully automated for developers.**

---

## Next Steps

1. ✅ Configure Info.plist with Sparkle keys ([see above](#configuration))
2. ✅ Set up GitHub repository and Action ([see RELEASES.md](RELEASES.md))
3. ✅ Configure S3 bucket and CloudFront ([see RELEASES.md](RELEASES.md))
4. ✅ Run first release: `./scripts/release.sh 0.1.0`
5. ✅ Test update flow on older version
6. ✅ Add "Check for Updates" menu item (optional)
7. ✅ Ship! 🚀

**For complete setup instructions, see [RELEASES.md](RELEASES.md).**
