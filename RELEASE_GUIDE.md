# Picflow Release Guide

Complete guide for releasing new versions of Picflow using Cloudflare R2 and automated scripts.

---

## Table of Contents

1. [One-Time Setup](#one-time-setup)
2. [Release Process](#release-process)
3. [Troubleshooting](#troubleshooting)
4. [Rollback](#rollback)

---

## One-Time Setup

### 1. Install Required Tools

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install sparkle        # For update signing
brew install create-dmg     # For DMG creation
brew install rclone         # For Cloudflare R2 uploads

# Optional: Install xcpretty for prettier Xcode output
gem install xcpretty        # (Can skip - script works without it)
```

### 2. Generate Sparkle Keys

```bash
# Generate EdDSA key pair for signing updates
generate_keys

# Output will show:
# A key has been generated and saved in your keychain.
# Public key: <YOUR_PUBLIC_KEY>
# 
# Copy the public key for your Info.plist

# Save private key
mkdir -p ~/.sparkle
# The private key is in your keychain, export it:
# Open Keychain Access → search for "Sparkle" → export as file
# Save to: ~/.sparkle/private_key
```

**Important:** Add public key to `Picflow/Info.plist`:
```xml
<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_KEY_HERE</string>
<key>SUFeedURL</key>
<string>https://updates.picflow.com/appcast.xml</string>
```

### 3. Configure Cloudflare R2

#### Step 3.1: Create R2 Bucket

1. Go to https://dash.cloudflare.com
2. Navigate to **R2** in the sidebar
3. Click **Create bucket**
4. Name: `picflow-updates`
5. Location: Automatic
6. Click **Create bucket**

#### Step 3.2: Make Bucket Public

1. Open your bucket
2. Click **Settings**
3. Scroll to **Public access**
4. Click **Allow Access**
5. Copy the public URL (e.g., `https://pub-xxxxx.r2.dev`)

#### Step 3.3: Get API Credentials

1. Go to **R2** → **Overview**
2. Click **Manage R2 API Tokens**
3. Click **Create API token**
4. Name: `Picflow Release Uploads`
5. Permissions: **Object Read & Write**
6. Click **Create API token**
7. **Copy and save:**
   - Access Key ID
   - Secret Access Key
   - Endpoint URL

#### Step 3.4: Configure rclone

```bash
# Run rclone config
rclone config

# Follow the prompts:
# n) New remote
# name> r2
# Storage> s3 (choose number for Amazon S3)
# provider> Cloudflare (choose number)
# env_auth> 1 (false - enter credentials manually)
# access_key_id> <YOUR_ACCESS_KEY_ID>
# secret_access_key> <YOUR_SECRET_ACCESS_KEY>
# region> auto
# endpoint> <YOUR_ENDPOINT_URL>
# location_constraint> (leave blank)
# acl> private
# Edit advanced config? n
# y) Yes this is OK
# q) Quit config
```

**Test connection:**
```bash
rclone lsd r2:picflow-updates
# Should show your bucket
```

#### Step 3.5: Set Up Custom Domain (Optional but Recommended)

Instead of `pub-xxxxx.r2.dev`, use `updates.picflow.com`:

1. Go to your R2 bucket → **Settings**
2. Click **Connect Custom Domain**
3. Enter: `updates.picflow.com`
4. Follow DNS instructions to add CNAME record
5. Wait for DNS propagation (~5-10 minutes)

Update `scripts/release.sh`:
```bash
APPCAST_URL="https://updates.picflow.com/appcast.xml"
```

### 4. Configure Apple Notarization

```bash
# Store your Apple ID credentials in keychain
xcrun notarytool store-credentials \
  --apple-id "your-email@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password" \
  notarytool
```

**Get app-specific password:**
1. Go to https://appleid.apple.com
2. Sign in
3. Security → App-Specific Passwords
4. Generate new password
5. Use this password in the command above

### 5. Update Release Script

Edit `scripts/release.sh` and update these variables:

```bash
DEVELOPER_ID="Developer ID Application: Your Name (YOUR_TEAM_ID)"
NOTARIZATION_PROFILE="notarytool"
R2_BUCKET="picflow-updates"
APPCAST_URL="https://updates.picflow.com/appcast.xml"

# In the export_app function, update:
<string>YOUR_TEAM_ID</string>
```

Find your Team ID:
```bash
# List all certificates
security find-identity -v -p codesigning

# Look for "Developer ID Application: Your Name (XXXXXXXXXX)"
# The XXXXXXXXXX is your Team ID
```

### 6. Make Script Executable

```bash
chmod +x scripts/release.sh
```

### 7. Initial appcast.xml

Create initial appcast on R2:

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

# Upload to R2
rclone copy /tmp/appcast.xml r2:picflow-updates/
```

---

## Release Process

### Quick Release (One Command)

```bash
# From repo root
./scripts/release.sh 1.2.0
```

That's it! The script will:
1. ✅ Archive the app
2. ✅ Export signed .app
3. ✅ Create DMG
4. ✅ Sign DMG with Apple Developer ID
5. ✅ Notarize with Apple
6. ✅ Sign with Sparkle
7. ✅ Upload to Cloudflare R2
8. ✅ Update appcast.xml
9. ✅ Generate release notes

### What Happens During Release

```
╔═══════════════════════════════════════╗
║   Picflow Release Automation          ║
║   Version: 1.2.0                      ║
╚═══════════════════════════════════════╝

==> Checking requirements...
✅ All requirements satisfied

==> Archiving Picflow...
[Xcode builds app...]
✅ Archive created

==> Exporting Picflow.app...
[Xcode exports signed app...]
✅ App exported

==> Creating DMG...
[create-dmg packages app...]
✅ DMG created: build/Picflow-1.2.0.dmg

==> Signing DMG...
[codesign signs DMG...]
✅ DMG signed

==> Notarizing DMG (this may take a few minutes)...
[Apple verifies and notarizes...]
✅ DMG notarized and stapled

==> Signing with Sparkle...
✅ Sparkle signature generated

==> Uploading to Cloudflare R2...
[Uploading: 45.2 MB of 45.2 MB, 100%, 12 MB/s]
✅ DMG uploaded to R2

==> Updating appcast.xml...
✅ appcast.xml updated and uploaded

==> Creating release notes...
✅ Release notes created: build/RELEASE-1.2.0.md

==> Cleaning up...
✅ Cleanup complete

╔═══════════════════════════════════════╗
║   🎉 Release Complete!                ║
╚═══════════════════════════════════════╝

📦 DMG: build/Picflow-1.2.0.dmg
📄 Release Notes: build/RELEASE-1.2.0.md
🌐 Download URL: https://updates.picflow.com/Picflow-1.2.0.dmg
🔔 Users will receive update notification automatically
```

### Time Estimates

- Archive: ~2-3 minutes
- Export: ~30 seconds
- DMG creation: ~30 seconds
- Signing: ~10 seconds
- **Notarization: ~3-5 minutes** (varies by Apple)
- Sparkle signing: ~5 seconds
- Upload to R2: ~10-30 seconds (depends on file size)
- Total: **~5-10 minutes**

### Before Each Release

1. **Update version number** in Xcode:
   - Target → General → Version: `1.2.0`
   - Target → General → Build: `10` (increment each release)

2. **Test the build locally**:
   ```bash
   # Build in Xcode
   Product → Archive
   # Verify it works
   ```

3. **Commit your changes**:
   ```bash
   git add .
   git commit -m "Version 1.2.0"
   git tag v1.2.0
   git push origin main --tags
   ```

4. **Run release script**:
   ```bash
   ./scripts/release.sh 1.2.0
   ```

5. **Update changelog** (after release):
   - Add release notes to your website/docs

### After Each Release

1. **Keep the DMG** (in `build/` directory):
   - Archive it for future reference
   - Useful if you need to verify signatures later

2. **Test the update**:
   ```bash
   # In a test environment with older version installed
   # Check for Updates in the app
   # Verify it downloads and installs correctly
   ```

3. **Monitor analytics**:
   - Watch Sentry for any new errors
   - Check analytics for update adoption rate

---

## Troubleshooting

### Issue: "Xcode command line tools not found"

**Solution:**
```bash
xcode-select --install
```

### Issue: "Sparkle private key not found"

**Solution:**
```bash
# Re-generate keys
generate_keys

# Export private key from Keychain Access
# Save to ~/.sparkle/private_key
```

### Issue: "Notarization failed"

**Check the logs:**
```bash
xcrun notarytool log <submission-id> \
  --keychain-profile notarytool
```

**Common causes:**
- Hardened Runtime not enabled
- Missing entitlements
- Unsigned frameworks

**Fix:**
- Ensure Hardened Runtime is enabled in Xcode
- Check all frameworks are properly signed

### Issue: "rclone: Failed to copy"

**Check R2 configuration:**
```bash
# Test connection
rclone lsd r2:picflow-updates

# If fails, reconfigure:
rclone config
```

### Issue: "Upload worked but appcast.xml not updating"

**Manual fix:**
```bash
# Download current appcast
rclone copy r2:picflow-updates/appcast.xml ./

# Edit appcast.xml manually
# Upload back
rclone copy appcast.xml r2:picflow-updates/
```

### Issue: "Users not receiving updates"

**Checklist:**
- ✅ Check appcast.xml is accessible: `curl https://updates.picflow.com/appcast.xml`
- ✅ Verify version number in appcast is higher than user's version
- ✅ Check user has "Automatically update Picflow" enabled in Settings
- ✅ Verify SUFeedURL in Info.plist is correct

### Issue: Script Fails Midway

**Resume options:**

If it fails after DMG is created:
```bash
# Skip to upload step (modify script to comment out early steps)
# Or manually upload:
rclone copy build/Picflow-1.2.0.dmg r2:picflow-updates/
```

---

## Rollback

### Remove a Bad Release

If you need to pull back a release:

```bash
# 1. Delete DMG from R2
rclone delete r2:picflow-updates/Picflow-1.2.0.dmg

# 2. Download and edit appcast.xml
rclone copy r2:picflow-updates/appcast.xml ./
# Remove the <item> for version 1.2.0
# Save and upload
rclone copy appcast.xml r2:picflow-updates/

# 3. Users will now see previous version as latest
```

### Force Users to Update

If you have a critical security fix:

**Update appcast.xml:**
```xml
<item>
    <title>Version 1.2.1 (Critical Security Update)</title>
    <sparkle:version>1.2.1</sparkle:version>
    <sparkle:criticalUpdate>true</sparkle:criticalUpdate>  <!-- Add this -->
    <!-- ... rest of item ... -->
</item>
```

Users will be required to update before continuing to use the app.

---

## Advanced: Beta Releases

### Separate Beta Channel

1. **Create beta appcast:**
```bash
cat > /tmp/appcast-beta.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Picflow Beta Updates</title>
        <link>https://updates.picflow.com/appcast-beta.xml</link>
        <description>Picflow beta channel</description>
        <language>en</language>
    </channel>
</rss>
EOF

rclone copy /tmp/appcast-beta.xml r2:picflow-updates/
```

2. **Modify release script for beta:**
```bash
# Add beta flag
APPCAST_FILE="appcast-beta.xml"  # Instead of appcast.xml
DMG_NAME="${APP_NAME}-${VERSION}-beta.dmg"
```

3. **Beta builds use different feed:**
```swift
#if DEBUG
let feedURL = "https://updates.picflow.com/appcast-beta.xml"
#else
let feedURL = "https://updates.picflow.com/appcast.xml"
#endif
```

---

## Monitoring

### Check R2 Usage

```bash
# List all files
rclone ls r2:picflow-updates

# Check bucket size
rclone size r2:picflow-updates
```

### Download Stats

Cloudflare R2 doesn't provide download stats directly, but you can:
- Use Cloudflare Analytics (if using custom domain)
- Add simple download counter via Cloudflare Workers

---

## Costs

**Cloudflare R2 Free Tier:**
- 10 GB storage (free)
- 10 GB egress per month (free)
- 10 million Class A operations per month (free)

**For Picflow (~50 MB DMG):**
- Storage: Negligible (each version is 50 MB)
- Bandwidth: 10 GB = ~200 downloads/month (free)
- Beyond free tier: $0.015/GB egress

**Estimated monthly cost:** $0 (under 200 downloads/month)

---

## Security Best Practices

1. ✅ **Never commit private keys** to git
   - Add `~/.sparkle/` to `.gitignore`
   - Add `scripts/release.sh` credentials to `.gitignore` if you hardcode them

2. ✅ **Use keychain for credentials**
   - Apple ID: Stored via `notarytool store-credentials`
   - R2 credentials: Stored via `rclone config`

3. ✅ **Always notarize**
   - Required by macOS Gatekeeper
   - Protects users from malware

4. ✅ **Verify signatures**
   - Sparkle verifies EdDSA signature automatically
   - Users can verify: `codesign -dvv Picflow.app`

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

# Check notarization status
xcrun notarytool log <submission-id> --keychain-profile notarytool

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

---

## Support

If you run into issues:
1. Check [Troubleshooting](#troubleshooting) section
2. Review script output for error messages
3. Test each step manually
4. Check Cloudflare R2 dashboard
5. Verify Apple Developer account status

---

**Setup Time:** ~1 hour (one-time)  
**Release Time:** ~5-10 minutes (per release)  
**Cost:** $0/month (under 200 downloads)  
**Automation Level:** 95% (one command releases)

Happy releasing! 🚀

