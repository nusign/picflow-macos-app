# Picflow Release Scripts

Automated release tooling for Picflow macOS app.

## Quick Start

```bash
# Release new version
./scripts/release.sh 0.2.0
```

## What It Does

The release script automates the entire release process:

1. ✅ **Archive** - Builds release version in Xcode
2. ✅ **Export & Re-sign** - Deep signs all frameworks and app with Developer ID
3. ✅ **DMG** - Creates installer DMG
4. ✅ **Verify** - Verifies app signature
5. ✅ **Notarize** - Submits to Apple for notarization (~3-5 min)
6. ✅ **Latest DMG** - Creates copy for marketing (notarization-free)
7. ✅ **Sparkle** - Signs with EdDSA for secure updates
8. ✅ **GitHub Release** - Creates release with assets
9. ✅ **Upload** - Uploads both DMGs and appcast.xml
10. ⚡ **GitHub Action** - Automatically syncs to S3 (~1-2 min)

**Total time:** ~7-12 minutes (mostly waiting for Apple notarization)

## Output

After running the script, you'll have:

```
build/
├── Picflow-0.2.0.dmg          # Versioned, signed, notarized (for Sparkle)
├── Picflow.dmg                # Latest, signed, notarized (for marketing)
├── appcast.xml                # Sparkle 2 update feed
├── signature.txt              # EdDSA signature
├── length.txt                 # DMG file size
└── RELEASE-0.2.0.md           # Release notes

GitHub Release (created automatically):
├── Picflow-0.2.0.dmg
├── Picflow.dmg
└── appcast.xml

S3 (synced by GitHub Action):
s3://picflow-webapp-prod/download/macos/
├── Picflow-0.2.0.dmg          # Permanent versioned URL
├── Picflow.dmg                # Overwritten with each release
└── appcast.xml                # Updated with latest version
```

## Dual URL Strategy

The script creates two DMGs for different purposes:

### 1. Versioned DMG (`Picflow-0.2.0.dmg`)
- **Purpose:** Sparkle 2 automatic updates
- **URL:** `https://picflow.com/download/macos/Picflow-0.2.0.dmg`
- **Signature:** Unique EdDSA signature for this version
- **Lifecycle:** Permanent (never changes)
- **Why:** Sparkle verifies signature against binary content

### 2. Latest DMG (`Picflow.dmg`)
- **Purpose:** Marketing, emails, website downloads
- **URL:** `https://picflow.com/download/macos/Picflow.dmg`
- **Signature:** None (not used by Sparkle)
- **Lifecycle:** Overwritten with each release
- **Why:** Evergreen URL, always points to latest version

**Both DMGs are:**
- ✅ Identical content (byte-for-byte copy)
- ✅ Apple code-signed
- ✅ Apple notarized
- ✅ Safe to distribute

**Time Saved:** ~5 minutes per release by notarizing once and copying!

## First Time Setup

Follow: `../RELEASES.md` → One-Time Setup section

**Quick checklist:**
- [ ] Install tools: `brew install create-dmg gh`
- [ ] (Optional) Install xcpretty: `gem install xcpretty`
- [ ] Install Python cryptography: `pip3 install cryptography`
- [ ] Generate Sparkle EdDSA keys
- [ ] Configure Apple notarization
- [ ] Set up GitHub CLI authentication
- [ ] Configure GitHub Action with AWS secrets
- [ ] Update script with your credentials

## Usage

### Release Script

```bash
# Standard release
./scripts/release.sh 0.2.0

# The script will:
# 1. Build and sign everything
# 2. Create GitHub release
# 3. Upload DMGs and appcast.xml
# 4. Trigger GitHub Action to sync to S3
# 5. Generate release notes
```

### Workflow

1. **Update version in Xcode**
   - Open project
   - Select target → General
   - Update Version (e.g., `0.2.0`)
   - Increment Build number

2. **Commit changes**
   ```bash
   git add .
   git commit -m "Version 0.2.0: New features"
   git push origin main
   ```

3. **Run release script**
   ```bash
   ./scripts/release.sh 0.2.0
   ```

4. **Monitor GitHub Action**
   ```bash
   gh run watch
   # Wait for S3 sync to complete (~1-2 min)
   ```

5. **Verify URLs**
   ```bash
   curl -I https://picflow.com/download/macos/Picflow.dmg
   curl -I https://picflow.com/download/macos/Picflow-0.2.0.dmg
   curl -I https://picflow.com/download/macos/appcast.xml
   # All should return: HTTP/2 200
   ```

## Configuration

### Required Settings (scripts/release.sh)

Edit these lines in the script:

```bash
# Line 17: Your Apple Developer ID
DEVELOPER_ID="Developer ID Application: YOUR NAME (YOUR_TEAM_ID)"

# Line 18: Notarization profile name (created via xcrun notarytool)
NOTARIZATION_PROFILE="notarytool"

# Line 19: Path to Sparkle private key
SPARKLE_KEY_PATH="$HOME/.sparkle/private_key"

# Line 20: Your GitHub repository
GITHUB_REPO="your-username/picflow-macos"

# Line 21: Appcast URL (where Sparkle checks for updates)
APPCAST_URL="https://picflow.com/download/macos/appcast.xml"
```

### Find Your Team ID

```bash
security find-identity -v -p codesigning
# Look for: "Developer ID Application: Your Name (XXXXXXXXXX)"
# XXXXXXXXXX is your Team ID
```

## GitHub Action

The GitHub Action (`.github/workflows/sync-release-to-s3.yml`) automatically:
1. Triggers when a release is published
2. Downloads release assets
3. Uploads to `s3://picflow-webapp-prod/download/macos/`
4. Sets cache control headers:
   - Versioned DMG: 1 year (immutable)
   - Latest DMG: 5 minutes (frequently updated)
   - appcast.xml: 1 hour (update feed)

### Required GitHub Secrets

Configure in GitHub repo → Settings → Secrets → Actions:
- `AWS_ACCESS_KEY_ID` - AWS access key
- `AWS_SECRET_ACCESS_KEY` - AWS secret key
- `AWS_DEFAULT_REGION` - S3 region (e.g., `us-east-1`)

### Environment

Configure GitHub repo → Settings → Environments → `production`

This allows the workflow to access the secrets.

## Requirements

- macOS 14.0+
- Xcode with command line tools
- Apple Developer ID certificate
- Apple app-specific password (for notarization)
- GitHub account with CLI authentication
- AWS account with S3 bucket
- Python 3 with `cryptography` library

## Troubleshooting

### Script Errors

#### "xcpretty: command not found"
```bash
# Optional tool for prettier output, safe to ignore
# Or install: gem install xcpretty
```

#### "ERROR: Developer ID certificate not found"
```bash
security find-identity -v -p codesigning
# Verify you have a valid Developer ID Application certificate
# If expired, renew at developer.apple.com
```

#### "ERROR: Notarization failed"
```bash
# Check notarization logs
xcrun notarytool log <submission-id> --keychain-profile notarytool

# Common causes:
# - Hardened Runtime not enabled (should be enabled in project)
# - Missing entitlements
# - Invalid signature
```

#### "ERROR: Sparkle signing failed"
```bash
# Check if private key exists
ls -la ~/.sparkle/private_key

# Regenerate if needed (see RELEASES.md)
```

#### "ERROR: GitHub release creation failed"
```bash
# Check gh CLI authentication
gh auth status

# Re-authenticate if needed
gh auth login
```

### GitHub Action Errors

#### "AccessControlListNotSupported"
Fixed! The workflow no longer uses ACL flags (removed `--acl public-read`).

#### "Incorrect S3 path"
Fixed! The workflow now uploads to `s3://picflow-webapp-prod/download/macos/`.

#### "Permission denied"
Check GitHub secrets are configured correctly:
- Settings → Secrets → Actions
- Verify AWS credentials are valid
- Check S3 bucket permissions

### View Action Logs

```bash
# List recent runs
gh run list --limit 5

# View specific run
gh run view <run-id> --log

# Watch live
gh run watch
```

## Files

- `release.sh` - Main release automation script
- `README.md` - This file
- `../RELEASES.md` - Complete setup and process documentation
- `../.github/workflows/sync-release-to-s3.yml` - GitHub Action for S3 sync

## Documentation

See `../RELEASES.md` for complete documentation:
- One-time setup guide
- Detailed release process
- Troubleshooting
- Advanced topics

See `../SPARKLE_SETUP.md` for Sparkle 2 configuration:
- Dual URL strategy explained
- Security details
- Update flow

## Security

- ✅ Private key never leaves your machine (stored in `~/.sparkle/`)
- ✅ Notarization credentials stored in macOS Keychain
- ✅ AWS credentials stored as GitHub encrypted secrets
- ✅ All releases code signed by Apple
- ✅ EdDSA signatures for update verification
- ✅ Apple notarization for Gatekeeper
- ✅ Triple-layer security: Apple signing + notarization + Sparkle signature

## Cost

### GitHub
- **GitHub Releases:** Free (unlimited)
- **GitHub Actions:** Free (2,000 minutes/month)
- **Estimated usage:** ~10 minutes per release

### AWS
- **S3 Storage:** $0.023/GB/month
  - ~500 MB for 10 versions = ~$0.01/month
- **S3 Data Transfer:** $0.09/GB (after 100 GB free tier)
  - With CloudFront CDN: Minimal direct S3 egress
- **CloudFront:** $0.085/GB for first 10 TB
  - First 1 TB/month free for 12 months

**Estimated monthly cost:** $0-5/month for typical indie app

## Support

Questions? Check:
1. Script comments (well-documented)
2. `../RELEASES.md` (comprehensive guide)
3. `../SPARKLE_SETUP.md` (Sparkle configuration)
4. Error messages in terminal (descriptive)
5. GitHub Action logs (detailed output)

---

**Setup time:** 30 minutes (one-time)  
**Release time:** 7-12 minutes (per version)  
**Automation:** 95% (one command + automatic S3 sync)

**Happy releasing! 🎉**
