# Release Setup Checklist

Quick checklist to set up automated releases for Picflow. Follow this once, then use `./scripts/release.sh` for all future releases.

---

## ☐ Step 1: Install Tools (5 minutes)

```bash
# Install required tools
brew install sparkle create-dmg rclone

# Optional: Install xcpretty for prettier Xcode output
gem install xcpretty
# (Can skip this - script works without it)
```

**Verify:**
```bash
which sparkle && which create-dmg && which rclone
# Should show paths to all three ✓
```

---

## ☐ Step 2: Generate Sparkle Keys (2 minutes)

```bash
# Generate key pair
generate_keys
```

**Output will show:**
```
A key has been generated and saved in your keychain.
Public key: YOUR_PUBLIC_KEY_HERE
```

**Save private key:**
```bash
# Open Keychain Access app
# Search for "Sparkle"
# Right-click → Export "Sparkle EdDSA key"
# Save to: ~/.sparkle/private_key
mkdir -p ~/.sparkle
# (Move exported file there)
```

**Add public key to Info.plist:**

Open `Picflow/Info.plist` and add:
```xml
<key>SUPublicEDKey</key>
<string>PASTE_YOUR_PUBLIC_KEY_HERE</string>
<key>SUFeedURL</key>
<string>https://updates.picflow.com/appcast.xml</string>
```

---

## ☐ Step 3: Create Cloudflare R2 Bucket (10 minutes)

### 3.1: Create Bucket
1. Go to https://dash.cloudflare.com
2. Click **R2** in sidebar
3. Click **Create bucket**
4. Name: `picflow-updates`
5. Click **Create bucket**

### 3.2: Make Public
1. Open bucket → **Settings**
2. **Public access** → **Allow Access**
3. **Copy public URL:** `https://pub-xxxxx.r2.dev`

### 3.3: Get API Token
1. **R2** → **Overview** → **Manage R2 API Tokens**
2. **Create API token**
3. Name: `Picflow Releases`
4. Permissions: **Object Read & Write**
5. **Create API token**

**Save these (you'll need them next):**
- ✍️ Access Key ID: `________________`
- ✍️ Secret Access Key: `________________`
- ✍️ Endpoint: `________________`

### 3.4: Configure rclone
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
endpoint> [PASTE ENDPOINT]
location_constraint> [LEAVE BLANK]
acl> private
Edit advanced config? n
y) Yes this is OK
q) Quit
```

**Test:**
```bash
rclone lsd r2:picflow-updates
# Should show your bucket ✓
```

### 3.5: Upload Initial appcast.xml
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
# (use your actual URL)
# Should show XML ✓
```

---

## ☐ Step 4: Set Up Custom Domain (Optional but Recommended, 10 minutes)

Instead of `pub-xxxxx.r2.dev`, use `updates.picflow.com`:

### 4.1: Connect Domain
1. R2 bucket → **Settings** → **Custom Domains**
2. Click **Connect Domain**
3. Enter: `updates.picflow.com`

### 4.2: Add DNS Record
1. Go to **Cloudflare DNS** for picflow.com
2. Add CNAME record:
   - Name: `updates`
   - Target: (shown in R2 settings)
   - Proxy: ✅ Proxied

### 4.3: Wait for DNS
```bash
# Wait 5-10 minutes, then test:
curl https://updates.picflow.com/appcast.xml
# Should show XML ✓
```

**If using custom domain, update Info.plist:**
```xml
<key>SUFeedURL</key>
<string>https://updates.picflow.com/appcast.xml</string>
```

---

## ☐ Step 5: Configure Apple Notarization (5 minutes)

### 5.1: Get App-Specific Password
1. Go to https://appleid.apple.com
2. Sign in
3. **Security** → **App-Specific Passwords**
4. Click **+** to generate
5. Label: `Picflow Notarization`
6. **Copy the password** (you can't see it again)

### 5.2: Store in Keychain
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
# Should list recent notarizations (or show empty list) ✓
```

---

## ☐ Step 6: Update Release Script (5 minutes)

Edit `scripts/release.sh`:

**Line 17-19 - Update these:**
```bash
DEVELOPER_ID="Developer ID Application: YOUR NAME (YOUR_TEAM_ID)"
R2_BUCKET="picflow-updates"
APPCAST_URL="https://updates.picflow.com/appcast.xml"  # or your pub- URL
```

**Line 110 - Update Team ID:**
```bash
# Inside export_app() function, around line 110:
<string>YOUR_TEAM_ID</string>  # Replace with your actual Team ID
```

**Make executable:**
```bash
chmod +x scripts/release.sh
```

---

## ☐ Step 7: Test Release (10 minutes)

### 7.1: Update Version in Xcode
1. Open project in Xcode
2. Select target **Picflow**
3. **General** tab
4. Set **Version** to `1.0.0`
5. Set **Build** to `1`

### 7.2: Run Test Release
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
[Building...]
✅ Archive created

==> Exporting Picflow.app...
✅ App exported

==> Creating DMG...
✅ DMG created

==> Signing DMG...
✅ DMG signed

==> Notarizing DMG (this may take a few minutes)...
[Waiting for Apple...]
✅ DMG notarized and stapled

==> Signing with Sparkle...
✅ Sparkle signature generated

==> Uploading to Cloudflare R2...
✅ DMG uploaded to R2

==> Updating appcast.xml...
✅ appcast.xml updated and uploaded

╔═══════════════════════════════════════╗
║   🎉 Release Complete!                ║
╚═══════════════════════════════════════╝
```

### 7.3: Verify Upload
```bash
# Check files on R2
rclone ls r2:picflow-updates

# Should show:
# Picflow-1.0.0.dmg
# appcast.xml
```

### 7.4: Test Download
```bash
# Download and verify
curl -O https://updates.picflow.com/Picflow-1.0.0.dmg

# Verify signature
codesign -dvv Picflow-1.0.0.dmg
# Should show: signed by your Developer ID ✓

# Verify notarization
spctl -a -vv -t install Picflow-1.0.0.dmg
# Should show: accepted ✓
```

---

## ✅ Setup Complete!

**Time spent:** ~45 minutes (one-time)

**Future releases:** Just run:
```bash
./scripts/release.sh 1.1.0
```

---

## Quick Test Checklist

Before your first real release, verify:

- ☐ Sparkle keys generated and saved
- ☐ Public key in Info.plist
- ☐ R2 bucket created and configured
- ☐ rclone can connect to R2
- ☐ Custom domain working (optional)
- ☐ Apple notarization credentials stored
- ☐ Release script updated with your info
- ☐ Test release completed successfully
- ☐ DMG downloadable and verified
- ☐ appcast.xml accessible

---

## Common Issues During Setup

### "generate_keys: command not found"
```bash
brew install sparkle
```

### "rclone config doesn't show my bucket"
```bash
rclone config  # Reconfigure
# Make sure endpoint URL is correct
```

### "Notarization failed: Authentication failed"
```bash
# Regenerate app-specific password at appleid.apple.com
# Re-run: xcrun notarytool store-credentials notarytool
```

### "Can't find Team ID"
```bash
# In Xcode: Select target → Signing & Capabilities → Team
# Or: security find-identity -v -p codesigning
```

---

## What's Next?

1. ✅ Setup is complete (you're here)
2. Read `RELEASE_GUIDE.md` for detailed release process
3. When ready for next release: `./scripts/release.sh 1.1.0`

---

## Support

If stuck, check:
1. `RELEASE_GUIDE.md` - Full documentation
2. Script output - Shows detailed errors
3. Cloudflare R2 dashboard - Verify uploads
4. Apple Developer portal - Check certificates

Need help? Open an issue with:
- Script output
- Error messages
- What step failed

