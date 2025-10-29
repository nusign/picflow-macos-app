# Sparkle 2 Setup for Picflow

Complete guide for Sparkle 2 automatic updates with dual URL strategy.

---

## Overview

Picflow uses **Sparkle 2** for automatic updates with a dual URL strategy:

### Dual URL Strategy

**1. Versioned URLs** (for Sparkle 2 auto-updates)
```
https://picflow.com/download/macos/Picflow-1.0.0.dmg
https://picflow.com/download/macos/Picflow-1.1.0.dmg
https://picflow.com/download/macos/Picflow-1.2.0.dmg
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
- If you replace `Picflow.dmg` with v1.1.0, but appcast.xml has v1.0.0's signature → verification fails
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
./scripts/release.sh 1.0.0
```

**Creates:**
- `Picflow-1.0.0.dmg` - Signed with Sparkle 2 EdDSA
- `Picflow.dmg` - Exact copy (for marketing)

**Both are:**
- ✅ Code signed by Apple
- ✅ Notarized by Apple
- ✅ Uploaded to GitHub release

### 2. GitHub Action Syncs to S3

When a release is published, GitHub Action:
1. Downloads all release assets
2. Uploads to S3 at `s3://your-bucket/download/macos/`
3. Overwrites `Picflow.dmg` with latest version
4. Keeps all versioned DMGs permanently

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
            <title>Version 1.0.0</title>
            <sparkle:version>1.0.0</sparkle:version>
            <sparkle:shortVersionString>1.0.0</sparkle:shortVersionString>
            <pubDate>Tue, 28 Jan 2025 10:00:00 +0000</pubDate>
            <enclosure 
                url="https://picflow.com/download/macos/Picflow-1.0.0.dmg"
                sparkle:edSignature="UNIQUE_EDDSA_SIGNATURE_HERE"
                length="45678901"
                type="application/octet-stream"
            />
        </item>
    </channel>
</rss>
```

**Key Points:**
- ✅ Uses versioned URL: `Picflow-1.0.0.dmg`
- ✅ Has unique EdDSA signature
- ✅ Sparkle 2 namespace: `xmlns:sparkle="..."`
- ✅ EdDSA signature: `sparkle:edSignature="..."`

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
<integer>86400</integer><!-- Check daily -->
```

### Generate Sparkle Keys (One-Time)

```bash
# 1. Install Sparkle tools
brew install sparkle

# 2. Generate key pair
generate_keys

# Output:
# Public key: YOUR_PUBLIC_KEY_HERE

# 3. Export private key from Keychain
# - Open Keychain Access
# - Search "Sparkle"
# - Right-click → Export "Sparkle EdDSA key"
# - Save to: ~/.sparkle/private_key
```

### Update release.sh

Edit `scripts/release.sh`:

```bash
DEVELOPER_ID="Developer ID Application: YOUR_NAME (YOUR_TEAM_ID)"
GITHUB_REPO="your-username/picflow-macos"
```

---

## Release Process

### 1. Update Version in Xcode

- Open `Picflow macOS.xcodeproj`
- Target → General
- **Version:** `1.0.0`
- **Build:** Increment by 1

### 2. Run Release Script

```bash
./scripts/release.sh 1.0.0
```

**What happens:**
1. ✅ Builds and archives app
2. ✅ Creates versioned DMG: `Picflow-1.0.0.dmg`
3. ✅ Creates latest DMG: `Picflow.dmg` (copy)
4. ✅ Code signs both with Apple Developer ID
5. ✅ Notarizes both with Apple
6. ✅ Signs versioned DMG with Sparkle 2 EdDSA
7. ✅ Creates GitHub release with both DMGs
8. ✅ Creates appcast.xml (Sparkle 2 format)

### 3. GitHub Action Syncs to S3

- Triggered automatically on release
- Syncs all files to S3
- Overwrites `Picflow.dmg` with latest
- Updates appcast.xml

### 4. Users Get Updates

- Sparkle 2 checks appcast.xml daily
- Finds new version
- Downloads versioned DMG
- Verifies EdDSA signature
- Installs update

---

## File Structure

### S3 Bucket: `s3://your-bucket/download/macos/`

```
download/macos/
├── appcast.xml                 # Sparkle 2 update feed
├── Picflow.dmg                 # Latest version (marketing)
├── Picflow-1.0.0.dmg          # Version 1.0.0 (permanent)
├── Picflow-1.1.0.dmg          # Version 1.1.0 (permanent)
└── Picflow-1.2.0.dmg          # Version 1.2.0 (permanent)
```

### URLs

```
# Sparkle 2 checks this:
https://picflow.com/download/macos/appcast.xml

# Sparkle 2 downloads from this (versioned):
https://picflow.com/download/macos/Picflow-1.0.0.dmg

# Marketing/emails use this (always latest):
https://picflow.com/download/macos/Picflow.dmg
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
If you need version 1.0.0 specifically:
https://picflow.com/download/macos/Picflow-1.0.0.dmg
```

---

## Sparkle 2 Features

### Automatic Updates

```swift
// Sparkle 2 checks daily (configured in Info.plist)
// No code needed - fully automatic
```

### Manual Update Check

```swift
import Sparkle

// User clicks "Check for Updates" menu item
SPUStandardUpdaterController.shared().checkForUpdates(nil)
```

### Update Notifications

Users see:
1. "A new version of Picflow is available!"
2. Release notes from appcast.xml
3. "Install and Relaunch" button

### Silent Background Updates

Sparkle 2 can download updates in background:
- Downloads delta patches (smaller size)
- Installs on next launch
- Or prompts user immediately

---

## Security

### Triple Layer Security

1. **Apple Code Signing**
   - Verified by macOS Gatekeeper
   - Ensures DMG is from you

2. **Apple Notarization**
   - Scanned for malware by Apple
   - Required for macOS 10.15+

3. **Sparkle 2 EdDSA Signature**
   - Prevents tampering
   - Ensures update integrity
   - Private key never leaves your machine

### Signature Verification Flow

```
User's Mac                      S3
     │                          │
     ├─1. Check appcast ───────>│ appcast.xml
     │                          │
     │<─2. New version available┤ (with EdDSA signature)
     │                          │
     ├─3. Download DMG ─────────>│ Picflow-1.0.0.dmg
     │                          │
     ├─4. Verify EdDSA signature│
     │   (using public key)     │
     │                          │
     ├─5. Verify Apple signature│
     │                          │
     ├─6. Install & relaunch    │
```

If any signature fails → update rejected

---

## Troubleshooting

### "Signature verification failed"

**Cause:** EdDSA signature doesn't match DMG content

**Fix:**
1. Ensure you didn't modify DMG after signing
2. Re-run release script to regenerate signature
3. Verify public key in Info.plist matches private key

### "Users not receiving updates"

**Checklist:**
- ✅ appcast.xml is accessible: `curl https://picflow.com/download/macos/appcast.xml`
- ✅ SUFeedURL in Info.plist matches appcast URL
- ✅ Version in appcast is higher than user's version
- ✅ Public key in Info.plist is correct

### "Update downloads but won't install"

**Check:**
- Code signature: `codesign -dvv Picflow-1.0.0.dmg`
- Notarization: `spctl -a -vv -t install Picflow-1.0.0.dmg`
- User has admin privileges

---

## Summary

### What You Get

✅ **Automatic updates** via Sparkle 2  
✅ **Versioned URLs** for secure signed updates  
✅ **Static URL** for marketing (`Picflow.dmg`)  
✅ **Triple security** (Apple + Sparkle)  
✅ **One command releases** (`./scripts/release.sh X.Y.Z`)  
✅ **Automated workflow** (GitHub → S3)  

### Release Time

- **Build & sign:** ~5-10 minutes
- **GitHub Action sync:** ~1-2 minutes
- **Total:** ~7-12 minutes per release

### User Experience

1. User opens Picflow
2. Sparkle checks for updates (background)
3. "Update available" notification
4. User clicks "Install"
5. App relaunches with new version
6. Done! 🎉

---

## Next Steps

1. ✅ Configure Info.plist with Sparkle keys
2. ✅ Set up GitHub repository
3. ✅ Create GitHub Action (next step)
4. ✅ Run first release: `./scripts/release.sh 1.0.0`
5. ✅ Test update flow
6. ✅ Ship! 🚀

