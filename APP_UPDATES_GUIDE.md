# macOS App Update Management Guide

## Overview

For macOS apps distributed **outside the Mac App Store**, you need an auto-update mechanism. This guide covers Sparkle (the industry standard) and alternatives.

## Distribution Method

**Current:** Direct Distribution (not Mac App Store)
- ✅ No Apple review delays
- ✅ Full system access (no sandbox restrictions)
- ✅ Can use system APIs freely
- ❌ Need to implement updates yourself

---

## Option 1: Sparkle 2 (Recommended) ⭐

### What is Sparkle?

**Sparkle** is the de-facto standard auto-update framework for macOS apps. Used by thousands of apps including:
- Sketch
- Tower
- Things
- Notion
- Linear
- And many more

### Key Features

✅ **Automatic updates** - Download and install in background  
✅ **Delta updates** - Only download changed files (saves bandwidth)  
✅ **Code signing verification** - Ensures updates are authentic  
✅ **Release notes** - Show users what's new  
✅ **Beta channels** - Separate dev/production releases  
✅ **Silent updates** - Install without user intervention (optional)  
✅ **Phased rollouts** - Gradually release to users  
✅ **Skipped versions** - Users can skip updates  

### How Sparkle Works

```
┌─────────────────────────────────────────┐
│  Your macOS App                          │
│  + Sparkle Framework                     │
└──────────────┬──────────────────────────┘
               │
               │ 1. Check for updates (appcast.xml)
               ▼
┌─────────────────────────────────────────┐
│  Your Web Server                         │
│  - appcast.xml (update feed)             │
│  - Picflow-1.1.0.dmg                     │
│  - Picflow-1.2.0.dmg                     │
│  - Release notes                         │
└──────────────┬──────────────────────────┘
               │
               │ 2. Download new version
               ▼
┌─────────────────────────────────────────┐
│  Verify signature → Install → Relaunch   │
└─────────────────────────────────────────┘
```

### Implementation Steps

#### 1. Add Sparkle Framework

**Via Swift Package Manager:**
```swift
// In Xcode: File → Add Package Dependencies
// URL: https://github.com/sparkle-project/Sparkle
// Version: 2.5.0 or later
```

**Package.swift:**
```swift
dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.5.0")
]
```

#### 2. Configure Info.plist

Add to your `Info.plist`:
```xml
<key>SUFeedURL</key>
<string>https://updates.picflow.com/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_KEY_HERE</string>
<key>SUEnableAutomaticChecks</key>
<true/>
<key>SUScheduledCheckInterval</key>
<integer>86400</integer><!-- Check daily -->
```

#### 3. Generate EdDSA Keys

Sparkle uses EdDSA signatures for security:

```bash
# Install Sparkle's tools
brew install sparkle

# Generate key pair
generate_keys

# Output:
# Public key: YOUR_PUBLIC_KEY
# Private key: YOUR_PRIVATE_KEY (keep secret!)
```

#### 4. Create Update Manager

**Create:** `Services/SparkleUpdateManager.swift`

```swift
import Sparkle

@MainActor
class SparkleUpdateManager: ObservableObject {
    static let shared = SparkleUpdateManager()
    
    private var updaterController: SPUStandardUpdaterController?
    @Published var canCheckForUpdates = false
    
    private init() {}
    
    func setup() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        canCheckForUpdates = true
    }
    
    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }
    
    // Respect user's auto-update preference
    func setAutomaticChecks(enabled: Bool) {
        updaterController?.updater.automaticallyChecksForUpdates = enabled
    }
}
```

#### 5. Initialize in App

**Update:** `PicflowApp.swift`

```swift
import Sparkle

@main
struct PicflowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Initialize Sparkle
        Task { @MainActor in
            SparkleUpdateManager.shared.setup()
        }
        
        // Initialize analytics
        Task { @MainActor in
            AnalyticsManager.shared.initialize()
        }
        
        // Initialize Sentry...
    }
}
```

#### 6. Connect to Settings

**Update:** `SettingsManager.swift`

```swift
@Published var autoUpdate: Bool {
    didSet {
        UserDefaults.standard.set(autoUpdate, forKey: Keys.autoUpdate)
        // Connect to Sparkle
        SparkleUpdateManager.shared.setAutomaticChecks(enabled: autoUpdate)
    }
}
```

#### 7. Add Menu Item (Optional)

**Update:** `PicflowApp.swift` commands:

```swift
.commands {
    CommandGroup(after: .appInfo) {
        Button("Check for Updates...") {
            SparkleUpdateManager.shared.checkForUpdates()
        }
        .keyboardShortcut("u", modifiers: .command)
    }
}
```

#### 8. Create Appcast.xml

Host this on your server (e.g., `https://updates.picflow.com/appcast.xml`):

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Picflow Updates</title>
        <link>https://updates.picflow.com/appcast.xml</link>
        <description>Picflow app updates</description>
        <language>en</language>
        
        <!-- Latest version -->
        <item>
            <title>Version 1.2.0</title>
            <link>https://picflow.com/downloads/Picflow-1.2.0.dmg</link>
            <sparkle:version>1.2.0</sparkle:version>
            <sparkle:shortVersionString>1.2.0</sparkle:shortVersionString>
            <sparkle:releaseNotesLink>https://picflow.com/release-notes/1.2.0.html</sparkle:releaseNotesLink>
            <pubDate>Tue, 28 Jan 2025 10:00:00 +0000</pubDate>
            <enclosure 
                url="https://picflow.com/downloads/Picflow-1.2.0.dmg"
                sparkle:edSignature="YOUR_SIGNATURE_HERE"
                length="45678901"
                type="application/octet-stream"
            />
        </item>
        
        <!-- Previous version -->
        <item>
            <title>Version 1.1.0</title>
            <link>https://picflow.com/downloads/Picflow-1.1.0.dmg</link>
            <sparkle:version>1.1.0</sparkle:version>
            <sparkle:shortVersionString>1.1.0</sparkle:shortVersionString>
            <pubDate>Mon, 20 Jan 2025 10:00:00 +0000</pubDate>
            <enclosure 
                url="https://picflow.com/downloads/Picflow-1.1.0.dmg"
                sparkle:edSignature="PREVIOUS_SIGNATURE"
                length="45123456"
                type="application/octet-stream"
            />
        </item>
    </channel>
</rss>
```

#### 9. Sign Your Releases

```bash
# Sign the .dmg file
sign_update Picflow-1.2.0.dmg --ed-key-file ~/sparkle_private_key

# Output includes EdDSA signature to add to appcast.xml
```

#### 10. Release Process

```bash
# 1. Build release version in Xcode
# 2. Archive (Product → Archive)
# 3. Export as .app
# 4. Create .dmg
# 5. Sign with Apple Developer ID
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name (TEAMID)" \
  Picflow.app

# 6. Notarize with Apple
xcrun notarytool submit Picflow-1.2.0.dmg \
  --keychain-profile "notarytool" \
  --wait

# 7. Sign for Sparkle
sign_update Picflow-1.2.0.dmg --ed-key-file ~/sparkle_private_key

# 8. Upload to server
# 9. Update appcast.xml with new version
```

### Pros & Cons

**Pros:**
✅ Industry standard (battle-tested)  
✅ Free and open source  
✅ Excellent documentation  
✅ Delta updates save bandwidth  
✅ Secure (EdDSA signatures)  
✅ Active development  
✅ Works on all macOS versions  

**Cons:**
❌ Requires hosting infrastructure  
❌ Manual release process  
❌ Need to manage signing keys  
❌ Apple notarization required  

---

## Option 2: AppCenter (Microsoft)

### What is AppCenter?

Microsoft's app distribution and update service (formerly HockeyApp).

### Features

✅ Hosted solution (no server needed)  
✅ Crash reporting included  
✅ Analytics included  
✅ CI/CD integration  
✅ Beta distribution  
✅ In-app updates  

### Limitations

❌ **Discontinued for macOS** - Only iOS/Android now supported  
❌ Not recommended for new projects  

**Verdict:** ❌ Not suitable

---

## Option 3: Squirrel.Mac

### What is Squirrel?

Alternative update framework (used by Slack, Atom, VS Code).

### Features

✅ Delta updates  
✅ Silent updates  
✅ JSON-based feed (not XML)  
✅ Modern Swift API  

### Limitations

❌ Less popular than Sparkle  
❌ Smaller community  
❌ Less documentation  
❌ Not as actively maintained  

**Verdict:** ⚠️ Consider only if Sparkle doesn't meet needs

---

## Option 4: Custom Solution

### Build Your Own

Implement update checking manually:

```swift
class CustomUpdateManager {
    func checkForUpdates() async throws {
        // 1. Fetch version from server
        let url = URL(string: "https://api.picflow.com/updates/check")!
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // 2. Parse response
        struct UpdateResponse: Codable {
            let latestVersion: String
            let downloadURL: String
            let releaseNotes: String
        }
        let response = try JSONDecoder().decode(UpdateResponse.self, from: data)
        
        // 3. Compare versions
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        if response.latestVersion > currentVersion! {
            // Show update dialog
        }
    }
}
```

### Limitations

❌ No automatic installation  
❌ No delta updates  
❌ No signature verification  
❌ More work to implement  
❌ More to maintain  

**Verdict:** ❌ Not recommended - use Sparkle instead

---

## Recommendation for Picflow

### ⭐ Use Sparkle 2

**Why:**
1. ✅ **Industry standard** - Proven and trusted
2. ✅ **Free** - Open source, no recurring costs
3. ✅ **Feature-complete** - Everything you need
4. ✅ **Secure** - EdDSA signatures
5. ✅ **Easy to implement** - ~1-2 hours setup
6. ✅ **Already have toggle** - UI is ready

### Implementation Plan

**Phase 1: Setup (2 hours)**
- [ ] Add Sparkle via Swift Package Manager
- [ ] Generate EdDSA keys
- [ ] Configure Info.plist
- [ ] Create SparkleUpdateManager
- [ ] Connect to existing autoUpdate toggle
- [ ] Add "Check for Updates" menu item

**Phase 2: Infrastructure (4 hours)**
- [ ] Set up update server/CDN
- [ ] Create appcast.xml template
- [ ] Write release script
- [ ] Test update flow

**Phase 3: Release Process (ongoing)**
- [ ] Archive app in Xcode
- [ ] Code sign with Developer ID
- [ ] Notarize with Apple
- [ ] Sign with Sparkle
- [ ] Upload to server
- [ ] Update appcast.xml

### Hosting Options

**Option A: Own Server**
- Simple nginx/Apache server
- ~$5-10/month
- Full control

**Option B: CDN (Cloudflare, AWS CloudFront)**
- Fast global distribution
- ~$1-5/month for small app
- Better performance

**Option C: GitHub Releases**
- Free!
- Can host DMG files
- Use raw.githubusercontent.com for appcast.xml
- Good for side projects

### Cost Estimate

**One-time:**
- Developer ID Certificate: $99/year (already have)
- Setup time: 4-6 hours

**Ongoing:**
- Server hosting: $0-10/month
- Maintenance: ~1 hour per release

**Total:** Nearly free!

---

## Example: GitHub-Hosted Updates

### Setup (Free!)

1. **Store releases in GitHub:**
```
https://github.com/picflow/picflow-macos/releases
```

2. **appcast.xml location:**
```
https://raw.githubusercontent.com/picflow/picflow-macos/main/appcast.xml
```

3. **DMG location:**
```
https://github.com/picflow/picflow-macos/releases/download/v1.2.0/Picflow-1.2.0.dmg
```

### Automated Release Script

```bash
#!/bin/bash
# release.sh

VERSION=$1
DMG="Picflow-${VERSION}.dmg"

# Sign with Sparkle
SIGNATURE=$(sign_update "$DMG" --ed-key-file ~/sparkle_private_key | grep "sparkle:edSignature" | cut -d'"' -f2)

# Get file size
SIZE=$(stat -f%z "$DMG")

# Update appcast.xml
cat > appcast.xml << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Picflow Updates</title>
        <item>
            <title>Version ${VERSION}</title>
            <sparkle:version>${VERSION}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <pubDate>$(date -R)</pubDate>
            <enclosure 
                url="https://github.com/picflow/picflow-macos/releases/download/v${VERSION}/${DMG}"
                sparkle:edSignature="${SIGNATURE}"
                length="${SIZE}"
                type="application/octet-stream"
            />
        </item>
    </channel>
</rss>
EOF

# Commit and push
git add appcast.xml
git commit -m "Release v${VERSION}"
git push

echo "✅ Release ready! Now upload ${DMG} to GitHub Releases"
```

---

## Testing Updates

### Local Testing

1. **Create test appcast:**
```xml
<!-- test-appcast.xml -->
<item>
    <title>Version 99.0.0</title>
    <sparkle:version>99.0.0</sparkle:version>
    <!-- Point to local file -->
    <enclosure url="file:///Users/you/Desktop/Picflow-Test.dmg" ... />
</item>
```

2. **Override feed URL:**
```swift
// In development build
#if DEBUG
updaterController?.updater.feedURL = URL(string: "file:///path/to/test-appcast.xml")
#endif
```

3. **Test update flow:**
- Check for updates
- Download
- Install
- Relaunch

### Beta Testing

**Separate beta channel:**
```xml
<!-- Info.plist -->
<key>SUFeedURL</key>
<string>https://updates.picflow.com/appcast-beta.xml</string>
```

Or use build configuration:
```swift
let feedURL = isProduction 
    ? "https://updates.picflow.com/appcast.xml"
    : "https://updates.picflow.com/appcast-beta.xml"
```

---

## Analytics Integration

Track update events:

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

---

## Security Considerations

### Code Signing

**Required:**
1. ✅ Apple Developer ID certificate
2. ✅ Hardened Runtime enabled
3. ✅ Notarization
4. ✅ Sparkle EdDSA signature

### Best Practices

✅ **Keep private key secure** - Never commit to Git  
✅ **Use HTTPS** - For appcast and downloads  
✅ **Verify signatures** - Sparkle does this automatically  
✅ **Notarize all releases** - Required by macOS Gatekeeper  
✅ **Version numbers** - Use semantic versioning (1.2.3)  

---

## FAQ

### Q: Can I use Sparkle with Mac App Store?
**A:** No. Mac App Store handles updates automatically.

### Q: What if users don't have internet?
**A:** Updates are optional. App works offline.

### Q: Can I force updates?
**A:** Yes, but not recommended. Better to show critical update dialog.

### Q: Delta updates - how much do they save?
**A:** 50-90% bandwidth for small changes.

### Q: Do I need a server?
**A:** Not necessarily - GitHub Releases works great (and it's free).

### Q: How often should I check for updates?
**A:** Daily is standard. Don't check more than once per hour.

---

## Resources

### Sparkle
- **Documentation:** https://sparkle-project.org/documentation/
- **GitHub:** https://github.com/sparkle-project/Sparkle
- **Examples:** https://github.com/sparkle-project/Sparkle/tree/2.x/Samples

### Apple
- **Notarization Guide:** https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
- **Code Signing:** https://developer.apple.com/support/code-signing/

### Tools
- **create-dmg:** https://github.com/create-dmg/create-dmg
- **Sparkle CLI:** `brew install sparkle`

---

## Next Steps

1. **Add Sparkle** via Swift Package Manager
2. **Generate keys** with `generate_keys`
3. **Implement SparkleUpdateManager**
4. **Test locally** with test appcast
5. **Set up hosting** (GitHub or own server)
6. **Create release process** script
7. **Ship first update!**

---

**Recommendation:** ⭐ **Start with Sparkle 2 + GitHub Releases (free and simple)**

**Time Investment:** ~6 hours setup + 30 min per release  
**Cost:** $0 (using GitHub) or ~$5-10/month (own server)  
**User Experience:** Professional, seamless updates  

Your `autoUpdate` toggle is already built - just needs to be connected to Sparkle! 🚀

