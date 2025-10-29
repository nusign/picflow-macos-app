# Picflow Release Process

Quick guide for releasing new versions of Picflow macOS app.

## Prerequisites

Ensure these tools are installed (one-time setup):
```bash
brew install create-dmg gh
pip3 install cryptography
```

## Release Steps

### 1. Update Version Numbers

**IMPORTANT:** You must update **BOTH** the Xcode project AND the Info.plist file.

#### a) Update Info.plist

Edit `Picflow/Info.plist`:
```xml
<key>CFBundleShortVersionString</key>
<string>0.1.8</string>  <!-- Update this -->
<key>CFBundleVersion</key>
<string>8</string>  <!-- Increment this -->
```

#### b) Update Xcode Project

Edit `Picflow macOS.xcodeproj/project.pbxproj`:

Find and update both `MARKETING_VERSION` (appears twice - Debug and Release):
```xml
MARKETING_VERSION = 0.1.8;  <!-- Update this -->
```

Find and update both `CURRENT_PROJECT_VERSION` (appears twice - Debug and Release):
```xml
CURRENT_PROJECT_VERSION = 8;  <!-- Increment this (matches last digit of version) -->
```

**Quick way using search and replace:**
```bash
# For version 0.1.8, build 8:
# In Info.plist:
<string>0.1.7</string>   →   <string>0.1.8</string>

# In the project file:
MARKETING_VERSION = 0.1.7;   →   MARKETING_VERSION = 0.1.8;
CURRENT_PROJECT_VERSION = 7;   →   CURRENT_PROJECT_VERSION = 8;
```

### 2. Commit Changes

```bash
git add .
git commit -m "Version 0.1.8: [Brief description of changes]"
git push origin main
```

### 3. Run Release Script

```bash
./scripts/release.sh 0.1.8
```

The script will:
- ✅ Build and archive the app (~2-3 min)
- ✅ Code sign with Developer ID
- ✅ Create DMG (~30 sec)
- ✅ Notarize with Apple (~3-5 min)
- ✅ Sign with Sparkle 2 EdDSA
- ✅ Create GitHub release
- ✅ Upload versioned DMG (`Picflow-0.1.8.dmg`)
- ✅ Upload latest DMG (`Picflow.dmg`)
- ✅ Generate and upload `appcast.xml`

**Total time:** ~7-12 minutes

### 4. Verify Release

The GitHub Action will automatically sync to S3 (~1-2 min).

Check the workflow:
```bash
gh run watch
```

Verify URLs are accessible:
```bash
curl -I https://picflow.com/download/macos/appcast.xml
curl -I https://picflow.com/download/macos/Picflow-0.1.8.dmg
curl -I https://picflow.com/download/macos/Picflow.dmg
```

### 5. Test Update (Optional)

On a machine with an older version:
1. Open Picflow
2. Wait for automatic update notification
3. Install update
4. Verify new version

## Quick Reference

### Version Numbering

Use semantic versioning: `MAJOR.MINOR.PATCH`

- **PATCH** (0.1.X): Bug fixes, small improvements
- **MINOR** (0.X.0): New features, UI changes
- **MAJOR** (X.0.0): Major overhaul, breaking changes

### Common Issues

**"Xcode command line tools not found"**
```bash
xcode-select --install
```

**"Notarization failed"**
```bash
# Check logs
xcrun notarytool log <submission-id> --keychain-profile notarytool
```

**"GitHub release creation failed"**
```bash
gh auth status
gh auth login  # Re-authenticate if needed
```

**"GitHub Action failed"**
```bash
gh run view --log  # Check workflow logs
```

## Files Generated

After release, `build/` contains:
- `Picflow-0.1.8.dmg` - Versioned, signed, notarized
- `Picflow.dmg` - Copy for marketing (always latest)
- `RELEASE-0.1.8.md` - Release notes

These are uploaded to:
- **GitHub Releases:** https://github.com/nusign/picflow-macos/releases
- **S3/CloudFront:** https://picflow.com/download/macos/

## Changelog Template

When releasing, update `build/RELEASE-X.Y.Z.md` with actual changes:

```markdown
## Changelog

### New Features
- Feature description

### Improvements
- Improvement description

### Bug Fixes
- Bug fix description

### Technical
- Technical changes
```

## Post-Release

After successful release:
1. ✅ Monitor Sentry for errors
2. ✅ Check analytics for update adoption
3. ✅ Update website/marketing materials if needed
4. ✅ Announce release to users (optional)

---

**Full Documentation:** See [RELEASES.md](RELEASES.md) for complete setup and troubleshooting guide.

