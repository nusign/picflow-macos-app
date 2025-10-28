# Picflow Releases & Updates

Complete guide for managing Picflow releases and automatic updates using Sparkle 2 and Cloudflare R2.

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

Picflow uses **Sparkle 2** (industry standard) for automatic updates, hosted on **Cloudflare R2** (free for small apps).

### Why Sparkle?

✅ **Industry standard** - Used by Sketch, Tower, Things, Notion, Linear  
✅ **Free & open source** - No recurring costs  
✅ **Secure** - EdDSA signatures + Apple notarization  
✅ **Delta updates** - Only download changed files  
✅ **Feature-complete** - Release notes, beta channels, phased rollouts  

### Update Flow

```
User's Mac                    Cloudflare R2
     │                              │
     ├─1. Check for updates ───────>│ appcast.xml
     │                              │
     │<─2. New version available ───┤
     │                              │
     ├─3. Download DMG ─────────────>│ Picflow-1.2.0.dmg
     │                              │
     ├─4. Verify signature          │
     ├─5. Install & relaunch        │
```

**Cost:** $0/month (under 200 downloads, Cloudflare R2 free tier)  
**Release time:** ~5-10 minutes per version  
**Setup time:** ~45 minutes (one-time)

---

## How Updates Work

### Technical Details

#### 1. Sparkle Framework
- **Language:** Swift/Objective-C
- **Integration:** Swift Package Manager
- **Signing:** EdDSA (modern, secure)
- **Check frequency:** Daily (configurable)

#### 2. Update Feed (appcast.xml)
XML file listing available versions:
```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Picflow Updates</title>
        <item>
            <title>Version 1.2.0</title>
            <sparkle:version>1.2.0</sparkle:version>
            <sparkle:shortVersionString>1.2.0</sparkle:shortVersionString>
            <pubDate>Tue, 28 Jan 2025 10:00:00 +0000</pubDate>
            <enclosure 
                url="https://updates.picflow.com/Picflow-1.2.0.dmg"
                sparkle:edSignature="SIGNATURE_HERE"
                length="45678901"
                type="application/octet-stream"
            />
        </item>
    </channel>
</rss>
```

#### 3. Version Comparison
Sparkle compares `CFBundleShortVersionString` in app's Info.plist with latest version in appcast.xml.

#### 4. Security
- **Apple Code Signing** - Verified by macOS
- **Apple Notarization** - Malware scan by Apple
- **Sparkle EdDSA Signature** - Prevents tampering

---

## One-Time Setup

### Step 1: Install Tools (5 minutes)

```bash
# Install required tools via Homebrew
brew install sparkle create-dmg rclone

# Optional: Prettier Xcode output (skip if you get permission errors)
gem install xcpretty
```

**Verify:**
```bash
which sparkle && which create-dmg && which rclone
# Should show paths to all three ✓
```

---

### Step 2: Generate Sparkle Keys (5 minutes)

#### 2.1: Generate Key Pair
```bash
generate_keys
```

**Output:**
```
A key has been generated and saved in your keychain.
Public key: YOUR_PUBLIC_KEY_HERE
```

**Copy the public key** - you'll need it next.

#### 2.2: Export Private Key
```bash
# 1. Open Keychain Access app
# 2. Search for "Sparkle"
# 3. Right-click → Export "Sparkle EdDSA key"
# 4. Save as file (no password needed)
# 5. Move to ~/.sparkle/

mkdir -p ~/.sparkle
mv ~/Downloads/Sparkle\ EdDSA\ key.p12 ~/.sparkle/private_key
```

#### 2.3: Add Public Key to Info.plist

Open `Picflow/Info.plist` and add:
```xml
<key>SUPublicEDKey</key>
<string>PASTE_YOUR_PUBLIC_KEY_HERE</string>
<key>SUFeedURL</key>
<string>https://updates.picflow.com/appcast.xml</string>
<key>SUEnableAutomaticChecks</key>
<true/>
<key>SUScheduledCheckInterval</key>
<integer>86400</integer><!-- Check daily -->
```

---

### Step 3: Create Cloudflare R2 Bucket (10 minutes)

#### 3.1: Create Bucket
1. Go to https://dash.cloudflare.com
2. Click **R2** in sidebar
3. Click **Create bucket**
4. Name: `picflow-updates`
5. Location: Automatic
6. Click **Create bucket**

#### 3.2: Make Bucket Public
1. Open bucket → **Settings**
2. Scroll to **Public access**
3. Click **Allow Access**
4. **Copy public URL:** `https://pub-xxxxx.r2.dev`

#### 3.3: Get API Credentials
1. Go to **R2** → **Overview**
2. Click **Manage R2 API Tokens**
3. Click **Create API token**
4. Name: `Picflow Releases`
5. Permissions: **Object Read & Write**
6. Click **Create API token**

**Save these (you'll need them next):**
- Access Key ID
- Secret Access Key  
- Endpoint URL

#### 3.4: Configure rclone
```bash
rclone config
```

**Follow prompts:**
```
n) New remote
name> r2
Storage> s3 (pick the number)
provider> Cloudflare (pick the number)
env_auth> 1 (false)
access_key_id> [PASTE ACCESS KEY ID]
secret_access_key> [PASTE SECRET ACCESS KEY]
region> auto
endpoint> [PASTE ENDPOINT URL]
location_constraint> [LEAVE BLANK]
acl> private
Edit advanced config? n
y) Yes this is OK
q) Quit
```

**Test connection:**
```bash
rclone lsd r2:picflow-updates
# Should show your bucket ✓
```

#### 3.5: Upload Initial appcast.xml
```bash
cat > /tmp/appcast.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Picflow Updates</title>
        <link>https://updates.picflow.com/appcast.xml</link>
        <description>Picflow app updates</description>
        <language>en</language>
    </channel>
</rss>
EOF

rclone copy /tmp/appcast.xml r2:picflow-updates/
```

**Verify:**
```bash
curl https://pub-xxxxx.r2.dev/appcast.xml
# Should show XML ✓
```

---

### Step 4: Set Up Custom Domain (Optional, 10 minutes)

Instead of `pub-xxxxx.r2.dev`, use `updates.picflow.com`:

#### 4.1: Connect Domain
1. R2 bucket → **Settings** → **Custom Domains**
2. Click **Connect Domain**
3. Enter: `updates.picflow.com`

#### 4.2: Add DNS Record
1. Go to **Cloudflare DNS** for picflow.com
2. Add CNAME record:
   - Name: `updates`
   - Target: (shown in R2 settings)
   - Proxy: ✅ Proxied
3. Click **Save**

#### 4.3: Wait for DNS & Test
```bash
# Wait 5-10 minutes, then test:
curl https://updates.picflow.com/appcast.xml
# Should show XML ✓
```

**Update Info.plist if using custom domain:**
```xml
<key>SUFeedURL</key>
<string>https://updates.picflow.com/appcast.xml</string>
```

---

### Step 5: Configure Apple Notarization (5 minutes)

#### 5.1: Get App-Specific Password
1. Go to https://appleid.apple.com
2. Sign in
3. **Security** → **App-Specific Passwords**
4. Click **+** to generate
5. Label: `Picflow Notarization`
6. **Copy the password**

#### 5.2: Store in Keychain
```bash
xcrun notarytool store-credentials notarytool \
  --apple-id "your-email@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

**Find your Team ID:**
```bash
security find-identity -v -p codesigning
# Look for: "Developer ID Application: Your Name (XXXXXXXXXX)"
# XXXXXXXXXX is your Team ID
```

**Verify:**
```bash
xcrun notarytool history --keychain-profile notarytool
# Should list recent notarizations (or empty) ✓
```

---

### Step 6: Update Release Script (5 minutes)

Edit `scripts/release.sh`:

**Lines 17-19:**
```bash
DEVELOPER_ID="Developer ID Application: YOUR NAME (YOUR_TEAM_ID)"
R2_BUCKET="picflow-updates"
APPCAST_URL="https://updates.picflow.com/appcast.xml"  # or your pub- URL
```

**Line ~110 (inside export_app function):**
```bash
<string>YOUR_TEAM_ID</string>  # Replace with your actual Team ID
```

**Make executable:**
```bash
chmod +x scripts/release.sh
```

---

### Step 7: Test First Release (10 minutes)

#### 7.1: Update Version in Xcode
1. Open `Picflow macOS.xcodeproj`
2. Select target **Picflow**
3. **General** tab
4. Set **Version** to `1.0.0`
5. Set **Build** to `1`

#### 7.2: Run Test Release
```bash
./scripts/release.sh 1.0.0
```

**Expected output:**
```
╔═══════════════════════════════════════╗
║   Picflow Release Automation          ║
║   Version: 1.0.0                      ║
╚═══════════════════════════════════════╝

==> Checking requirements...
✅ All requirements satisfied

==> Archiving Picflow...
✅ Archive created

==> Exporting Picflow.app...
✅ App exported

==> Creating DMG...
✅ DMG created

==> Signing DMG...
✅ DMG signed

==> Notarizing DMG (may take 3-5 minutes)...
✅ DMG notarized and stapled

==> Signing with Sparkle...
✅ Sparkle signature generated

==> Uploading to Cloudflare R2...
✅ DMG uploaded to R2

==> Updating appcast.xml...
✅ appcast.xml updated

╔═══════════════════════════════════════╗
║   🎉 Release Complete!                ║
╚═══════════════════════════════════════╝

📦 DMG: build/Picflow-1.0.0.dmg
🌐 Download: https://updates.picflow.com/Picflow-1.0.0.dmg
```

#### 7.3: Verify Upload
```bash
# Check files on R2
rclone ls r2:picflow-updates

# Should show:
# Picflow-1.0.0.dmg
# appcast.xml
```

#### 7.4: Test Download & Verification
```bash
# Download
curl -O https://updates.picflow.com/Picflow-1.0.0.dmg

# Verify code signature
codesign -dvv Picflow-1.0.0.dmg
# Should show: signed by your Developer ID ✓

# Verify notarization
spctl -a -vv -t install Picflow-1.0.0.dmg
# Should show: accepted ✓
```

---

### ✅ Setup Complete!

**Setup time:** ~45 minutes (one-time)

**Quick Setup Checklist:**
- ☐ Tools installed (sparkle, create-dmg, rclone)
- ☐ Sparkle keys generated and saved
- ☐ Public key added to Info.plist
- ☐ R2 bucket created and configured
- ☐ rclone configured and tested
- ☐ Custom domain set up (optional)
- ☐ Apple notarization configured
- ☐ Release script updated
- ☐ Test release successful
- ☐ DMG downloadable and verified

**Future releases:** Just run `./scripts/release.sh X.Y.Z`

---

## Release Process

### Quick Release (One Command)

```bash
./scripts/release.sh 1.2.0
```

That's it! The script handles everything automatically.

---

### What Happens During Release

The script performs these steps:

1. **Check requirements** - Verify all tools installed
2. **Archive app** - Build release in Xcode (~2-3 min)
3. **Export .app** - Extract signed app (~30 sec)
4. **Create DMG** - Package as disk image (~30 sec)
5. **Sign with Apple** - Code sign DMG (~10 sec)
6. **Notarize** - Submit to Apple for verification (~3-5 min)
7. **Sign with Sparkle** - Generate EdDSA signature (~5 sec)
8. **Upload to R2** - Upload DMG (~10-30 sec)
9. **Update appcast.xml** - Add new version to feed (~5 sec)
10. **Generate release notes** - Create markdown summary (~5 sec)

**Total time:** ~5-10 minutes (notarization is the slowest step)

---

### Before Each Release

#### 1. Update Version Number in Xcode
- Open `Picflow macOS.xcodeproj`
- Select target → **General**
- **Version:** `1.2.0` (semantic versioning)
- **Build:** Increment by 1

#### 2. Test Build Locally
```bash
# In Xcode: Product → Archive
# Verify it works before releasing
```

#### 3. Commit Changes
```bash
git add .
git commit -m "Version 1.2.0: Add new features"
git tag v1.2.0
git push origin main --tags
```

#### 4. Run Release Script
```bash
./scripts/release.sh 1.2.0
```

---

### After Each Release

#### 1. Archive the DMG
Keep the DMG in `build/` for future reference:
```bash
# Optionally move to archive folder
mkdir -p releases
cp build/Picflow-1.2.0.dmg releases/
```

#### 2. Test the Update Flow
```bash
# On a machine with older version installed:
# 1. Open Picflow
# 2. Settings → Check for updates (if you added menu item)
# 3. Or wait for automatic check
# 4. Verify update downloads and installs
```

#### 3. Monitor
- Check Sentry for new errors
- Check analytics for update adoption rate
- Monitor Cloudflare R2 for bandwidth usage

---

## Troubleshooting

### Setup Issues

#### "generate_keys: command not found"
```bash
brew install sparkle
```

#### "rclone: command not found"
```bash
brew install rclone
```

#### "Can't export Sparkle private key from Keychain"
```bash
# Try regenerating:
generate_keys

# Then export again:
# Keychain Access → Search "Sparkle" → Right-click → Export
```

#### "rclone can't connect to R2"
```bash
# Reconfigure:
rclone config

# Test connection:
rclone lsd r2:picflow-updates

# If fails, verify:
# 1. Access Key ID is correct
# 2. Secret Access Key is correct
# 3. Endpoint URL is correct (include https://)
```

---

### Release Issues

#### "Xcode command line tools not found"
```bash
xcode-select --install
```

#### "Sparkle private key not found at ~/.sparkle/private_key"
```bash
# Check if file exists:
ls -la ~/.sparkle/

# If missing, export from Keychain Access again
# Save to: ~/.sparkle/private_key
```

#### "Notarization failed"
Check logs:
```bash
xcrun notarytool log <submission-id> \
  --keychain-profile notarytool
```

**Common causes:**
- Hardened Runtime not enabled (check Xcode settings)
- Missing entitlements
- Unsigned frameworks

**Fix:**
```bash
# Verify signing in Xcode:
# Target → Signing & Capabilities
# - Enable Hardened Runtime
# - Check signing certificate is valid
```

#### "Code signing failed"
```bash
# List available certificates:
security find-identity -v -p codesigning

# Verify Developer ID certificate exists
# If expired, renew at developer.apple.com
```

#### "rclone: Failed to copy"
```bash
# Test R2 connection:
rclone lsd r2:picflow-updates

# If fails, reconfigure:
rclone config

# Check bucket permissions in Cloudflare dashboard
```

#### "Upload succeeded but appcast.xml not updating"
**Manual fix:**
```bash
# Download current appcast
rclone copy r2:picflow-updates/appcast.xml ./

# Edit appcast.xml manually (add your version)

# Upload back
rclone copy appcast.xml r2:picflow-updates/
```

---

### User Issues

#### "Users not receiving updates"

**Checklist:**
1. ✅ Check appcast.xml is accessible:
   ```bash
   curl https://updates.picflow.com/appcast.xml
   ```
2. ✅ Verify version in appcast is higher than user's version
3. ✅ Check user has "Automatically update" enabled in Settings
4. ✅ Verify SUFeedURL in Info.plist matches R2 URL
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
# 1. Delete DMG from R2
rclone delete r2:picflow-updates/Picflow-1.2.0.dmg

# 2. Download and edit appcast.xml
rclone copy r2:picflow-updates/appcast.xml ./

# Edit appcast.xml - remove the <item> for version 1.2.0

# 3. Upload updated appcast
rclone copy appcast.xml r2:picflow-updates/

# Users will now see previous version as latest
```

---

### Critical Security Updates

For urgent security fixes, mark update as critical:

**Edit appcast.xml:**
```xml
<item>
    <title>Version 1.2.1 (Critical Security Update)</title>
    <sparkle:version>1.2.1</sparkle:version>
    <sparkle:criticalUpdate>true</sparkle:criticalUpdate>  <!-- Add this -->
    <!-- ... rest of item ... -->
</item>
```

Users will be **required** to update before continuing.

---

### Beta Releases

#### Separate Beta Channel

**1. Create beta appcast:**
```bash
cat > /tmp/appcast-beta.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Picflow Beta Updates</title>
        <link>https://updates.picflow.com/appcast-beta.xml</link>
        <description>Picflow beta channel</description>
    </channel>
</rss>
EOF

rclone copy /tmp/appcast-beta.xml r2:picflow-updates/
```

**2. Beta builds use different feed:**
```swift
#if DEBUG
let feedURL = "https://updates.picflow.com/appcast-beta.xml"
#else
let feedURL = "https://updates.picflow.com/appcast.xml"
#endif
```

**3. Modify release script for beta:**
```bash
# In scripts/release.sh, add beta flag:
APPCAST_FILE="appcast-beta.xml"
DMG_NAME="${APP_NAME}-${VERSION}-beta.dmg"
```

---

### Delta Updates

Sparkle 2 supports delta updates (only download changed files):

**Benefits:**
- 50-90% bandwidth savings
- Faster updates
- Better user experience

**How it works:**
- Sparkle generates binary diffs automatically
- Users download only changed files
- Falls back to full DMG if diff fails

**Enable in appcast.xml:**
```xml
<enclosure 
    url="https://updates.picflow.com/Picflow-1.2.0.dmg"
    sparkle:edSignature="..."
    length="45678901"
    type="application/octet-stream"
/>
<sparkle:deltas>
    <enclosure 
        url="https://updates.picflow.com/Picflow-1.1.0-to-1.2.0.delta"
        sparkle:edSignature="..."
        sparkle:deltaFrom="1.1.0"
        length="5123456"
    />
</sparkle:deltas>
```

---

### Monitoring & Analytics

#### Track Update Events

Add to your `SparkleUpdateManager`:

```swift
extension SparkleUpdateManager: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        AnalyticsManager.shared.captureMessage(
            "Update available",
            context: ["version": item.versionString]
        )
    }
    
    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        AnalyticsManager.shared.captureMessage("No update available")
    }
    
    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        AnalyticsManager.shared.captureMessage(
            "Installing update",
            context: ["version": item.versionString]
        )
    }
}
```

#### Monitor R2 Usage

```bash
# List all files
rclone ls r2:picflow-updates

# Check bucket size
rclone size r2:picflow-updates

# Check Cloudflare dashboard for:
# - Bandwidth usage
# - Number of requests
# - Storage used
```

---

### Costs & Limits

**Cloudflare R2 Free Tier:**
- 10 GB storage (free)
- 10 GB egress per month (free)
- 10 million operations per month (free)

**For Picflow (~50 MB DMG):**
- Storage: ~500 MB (10 versions) = **$0**
- Bandwidth: 10 GB = ~200 downloads/month = **$0**
- Beyond free tier: $0.015/GB egress

**Estimated monthly cost:** 
- 0-200 downloads: **$0/month**
- 500 downloads: **~$1/month**
- 1,000 downloads: **~$2/month**

---

## Quick Reference

### Common Commands

```bash
# Release new version
./scripts/release.sh 1.2.0

# Test R2 connection
rclone lsd r2:picflow-updates

# Download current appcast
rclone copy r2:picflow-updates/appcast.xml ./

# Upload appcast
rclone copy appcast.xml r2:picflow-updates/

# List all files on R2
rclone ls r2:picflow-updates

# Check bucket size
rclone size r2:picflow-updates

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
- **R2 bucket:** `picflow-updates`
- **Public URL:** `https://updates.picflow.com/`
- **Info.plist:** `Picflow/Info.plist`

---

## Resources

### Documentation
- **Sparkle:** https://sparkle-project.org/documentation/
- **Sparkle GitHub:** https://github.com/sparkle-project/Sparkle
- **Apple Notarization:** https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
- **Cloudflare R2:** https://developers.cloudflare.com/r2/

### Tools
- **create-dmg:** https://github.com/create-dmg/create-dmg
- **rclone:** https://rclone.org/
- **Sparkle CLI:** `brew install sparkle`

---

## Summary

**Setup:** ~45 minutes (one-time)  
**Release:** ~5-10 minutes (per version)  
**Cost:** $0-2/month (depending on downloads)  
**Automation:** 95% (one command releases)  

**Next Steps:**
1. ✅ Complete one-time setup
2. ✅ Test first release
3. ✅ Set up monitoring
4. 🚀 Ship updates to users!

Happy releasing! 🎉

