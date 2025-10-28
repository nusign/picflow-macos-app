# Picflow Release Scripts

Automated release tooling for Picflow macOS app.

## Quick Start

```bash
# Release new version
./scripts/release.sh 1.2.0
```

## What It Does

The release script automates the entire release process:

1. ✅ **Archive** - Builds release version in Xcode
2. ✅ **Export** - Exports signed .app bundle
3. ✅ **DMG** - Creates installer DMG
4. ✅ **Sign** - Code signs with Apple Developer ID
5. ✅ **Notarize** - Submits to Apple for notarization
6. ✅ **Sparkle** - Signs with EdDSA for secure updates
7. ✅ **Upload** - Pushes to Cloudflare R2
8. ✅ **Appcast** - Updates XML feed for Sparkle
9. ✅ **Notes** - Generates release notes

**Total time:** ~5-10 minutes (mostly waiting for Apple)

## First Time Setup

Follow: `../RELEASES.md` → One-Time Setup section

**Quick checklist:**
- [ ] Install tools: `brew install sparkle create-dmg rclone`
- [ ] (Optional) Install xcpretty: `gem install xcpretty`
- [ ] Generate Sparkle keys: `generate_keys`
- [ ] Configure Cloudflare R2
- [ ] Setup Apple notarization
- [ ] Update script with your credentials

## Usage

### Release Script

```bash
# Standard release
./scripts/release.sh 1.2.0

# The script will:
# - Build and sign everything
# - Upload to Cloudflare R2
# - Update appcast.xml
# - Generate release notes in build/RELEASE-1.2.0.md
```

## Output

```
build/
├── Picflow-1.2.0.dmg          # Signed, notarized DMG
└── RELEASE-1.2.0.md           # Release notes
```

## Files

- `release.sh` - Main release automation script
- `README.md` - This file

## Documentation

See `../RELEASES.md` for complete documentation:
- One-time setup guide
- Release process
- Troubleshooting
- How updates work

## Requirements

- macOS 14.0+
- Xcode with command line tools
- Apple Developer ID certificate
- Cloudflare R2 account (free tier works)
- Sparkle tools (`brew install sparkle`)

## Troubleshooting

See `../RELEASES.md` → Troubleshooting section

## Cost

**Cloudflare R2 Free Tier:**
- 10 GB storage
- 10 GB bandwidth/month
- = ~200 downloads/month (free)

**For most indie apps:** $0/month

## Security

- ✅ Private key never leaves your machine
- ✅ Credentials stored in macOS Keychain
- ✅ All releases code signed by Apple
- ✅ EdDSA signatures for update verification
- ✅ Apple notarization for Gatekeeper

## Support

Questions? Check:
1. Script comments
2. `../RELEASES.md`
3. Error messages in terminal

---

**Setup time:** 45 minutes (one-time)  
**Release time:** 5-10 minutes (per version)  
**Automation:** One command releases

