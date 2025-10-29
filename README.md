# Picflow macOS App (Picflow)

SwiftUI app that uploads assets to Picflow.

## Features

### Core Functionality
- **Modern macOS App**: Regular dock app with menu bar icon for quick access
- **Visual Upload Status**: Menu bar icon changes to show upload states (idle, uploading, success, failed)
- **Gallery Selection**: Select from available galleries; currently selected gallery is displayed in the upload view
- **Live Folder Monitoring**: Watch a local folder and automatically upload new images to your selected gallery
- **Drag & Drop Upload**: Simple drag-and-drop interface for quick file uploads
- **Uploads**: Presigned S3 multipart uploads with progress tracking and error handling
- **Storage Management**: Account storage limits displayed based on tenant data; no per-file size limits
- **Sleep Prevention**: Automatically prevents system sleep during active uploads to ensure reliability

### Settings & Preferences
- **Settings Access**: Available from macOS menu bar (Picflow > Settings...) or profile dropdown, opens as separate window
- **Menu Bar Icon Control**: Toggle switch to show/hide menu bar icon (default: enabled)
- **Launch at Startup**: Toggle switch to automatically start Picflow when you log in (default: enabled, uses SMAppService)
- **Auto-Update**: Toggle switch to keep Picflow up to date with latest features (default: enabled, UI ready)
- **Logs Management**: Open logs folder button with automatic 7-day retention and cleanup
- **Integration Placeholders**: Finder extension and conflict behavior toggles (coming soon, disabled but visible)

### Authentication & Profile
- **Auth**: Clerk (OIDC + PKCE) browser-based login; logout supported; tokens stored securely in Keychain
- **Profile Management**: User avatar dropdown in toolbar with quick access to:
  - Open Picflow (web app)
  - Account Settings
  - App Settings
  - Switch Workspace
  - Logout

### Integrations
- **Capture One**: Seamless integration with selection monitoring, export automation, and upload
- **Automation Bridges**: AppleScript/JXA for Capture One communication

## Auth (Clerk)

- Domain: `clerk.picflow.com`
- Redirect URI: `picflow://auth/callback`
- Client ID: set in app configuration (Info.plist key `ClerkClientId`)

## Permissions

- ~~App Sandbox with user-selected read/write file access~~ (Currently disabled for Capture One integration)
- Apple Events permission for host automations (Capture One)
- Custom URL scheme `picflow://` for OAuth callback

**Note:** App sandboxing is currently disabled to allow AppleScript automation with Capture One. This means the app can only be distributed outside the Mac App Store.

## Usage

### First Launch
1. **Launch app** - The app appears in both the dock and menu bar
2. **Authenticate** - Click Login to authenticate with Clerk via browser
3. **Select gallery** - Choose a gallery from your workspace

### Daily Use

**Main Window**
- Click the dock icon or menu bar icon to open the main window
- Window size: 480x400px default, 720x640px maximum (fully resizable)
- Modern SwiftUI window management with `.frame()` and `.windowResizability(.contentSize)`
- Window features rounded corners with hidden title bar styling
- Profile dropdown in toolbar provides quick access to settings

**Upload Modes**
1. **Drag & Drop**: Drag files directly onto the upload area
2. **Choose Files**: Click "Choose Files" button to select files manually
3. **Live Mode**: Toggle "Live" to enable folder monitoring
   - Select a folder to watch
   - New files added to the folder automatically upload to your selected gallery
   - Perfect for automatic workflow integration

**Upload Status**
- Menu bar icon shows current state (uploading, completed, errors) while uploading
- Displays current count of files being uploaded with progress indication
- Shows checkmark when each file completes

**Settings Management**
- Access via macOS menu bar (Picflow > Settings..., or Cmd+,) or profile dropdown
- Opens as separate 600x500px window with organized sections:
  - **General**: Toggle switches for menu bar icon visibility and launch at startup
  - **Updates**: Toggle switch for automatic updates
  - **Integration**: Finder extension and conflict behavior (coming soon - disabled toggles with "Soon" badges)
  - **Advanced**: Open logs folder button to access debug information

**Profile Management**
- Click profile icon in toolbar to access:
  - Open Picflow (web app)
  - Account Settings
  - App Settings
  - Switch Workspace
  - Logout

**Logs & Debugging**
- Logs location: `~/Library/Application Support/Picflow/Logs`
- Automatic cleanup: Logs older than 7 days are removed on startup
- Access via Settings → Advanced → Open Logs Folder

## Architecture

### App Structure
- **SwiftUI WindowGroup**: Modern SwiftUI-first architecture with `.frame()` and `.windowResizability()` for window constraints
- **AppDelegate**: Lightweight app lifecycle coordinator for menu bar integration and core services
- **Authenticator**: Clerk OIDC + PKCE authentication flow with Keychain storage
- **Uploader**: S3 multipart upload with state tracking (idle/uploading/completed/failed)
- **SettingsManager**: Centralized app preferences singleton with UserDefaults persistence and system integration
- **SettingsWindowManager**: Dedicated manager for presenting Settings as separate NSWindow
- **MenuBarManager**: Extracted menu bar icon lifecycle, visibility control, and upload state indicators
- **Networking**: API client with JWT bearer tokens and tenant headers
- **Models**: Gallery, Asset, Tenant response structures

### UI Components
- **PicflowApp**: SwiftUI app entry point with WindowGroup, window modifiers, and Settings command
- **AppDelegate**: Lightweight lifecycle coordinator (menu bar, settings manager, authentication observers)
- **MenuBarManager**: Extracted menu bar icon management with visibility control
- **SettingsWindowManager**: Manages Settings window presentation as separate NSWindow
- **AppView**: Main authenticated container with navigation state management and debug shortcuts (D/C keys)
- **LoginView**: Modern login screen with Picflow branding, no auto-focus
- **SettingsView**: Comprehensive settings UI with toggle switches, disabled previews (no opacity), and action buttons
- **GallerySelectionView**: Gallery picker with async loading, workspace indicator, optimized card layout
- **UploaderView**: Upload interface with Live mode toggle, smooth status transitions
- **LiveFolderView**: Folder selection interface for automated monitoring
- **DropAreaView**: Drag & drop zone for manual file uploads
- **AvatarToolbarButton**: Profile dropdown with settings access and workspace/account management
- **CaptureOneStatusView**: Capture One integration status and controls
- **UploadStatusView**: Unified upload progress component for all upload types

### Key Features Implementation
- **Dock & Menu Bar App**: Standard macOS app with `.regular` activation policy, menu bar icon can be hidden via settings
- **Modern Window Management**: Pure SwiftUI approach using `.frame(minWidth:maxWidth:minHeight:maxHeight:)` + `.windowResizability(.contentSize)`
- **Window Sizing**: 480x400px minimum, 720x640px maximum, 480x400px default launch size
- **Settings Access**: Dual access via macOS menu bar (Cmd+,) and profile dropdown
- **Settings Window**: Separate NSWindow (600x500px) managed by `SettingsWindowManager`
- **Profile Dropdown**: NSToolbar integration with SwiftUI popover
- **Settings System**: `SettingsManager` singleton with `@Published` properties, UserDefaults persistence, toggle switches
- **Launch at Startup**: `SMAppService` integration for macOS 13+, toggle switch in Settings
- **Logs Management**: Automatic 7-day retention in `~/Library/Application Support/Picflow/Logs`
- **Upload States**: Published `UploadState` enum with auto-reset timers and status area transitions
- **Folder Monitoring**: `FolderMonitor` with FSEvents watching for file additions
- **Live Mode Toggle**: Switch between manual and automated upload workflows with smooth animations
- **Sleep Prevention**: `NSProcessInfo.processInfo.beginActivity` with `.userInitiated` option during uploads
- **Debug Shortcuts**: Press `D` for feature borders, `C` for core structure borders (dev mode)
- **No Auto-Focus**: Global focus management via ContentView, no buttons receive focus on window open
- **Hover Effects**: Gallery cards use native hover detection with instant feedback, no button wrappers

## Capture One Integration

Seamless integration with Capture One for automated photo uploads. **Phase 1 complete!** ✅

### Current Features
- **Real-time Detection**: Monitors Capture One running status (green/red indicator)
- **Selection Reading**: Displays count of selected assets
- **Permission Handling**: User-friendly automation permission prompts
- **Automatic Recipe Creation**: One-click setup of export recipe
- **Multi-version Support**: Works with Capture One 15, 16, 20, 21, 22, 23

### Upload Options
1. **Export & Upload** (Recommended)
   - Includes all Capture One edits (color grading, adjustments, crops)
   - Auto-creates "Picflow Upload" recipe
   - JPEG format, web-ready
   - Automatic cleanup after upload

2. **Upload Original Files**
   - Direct RAW file upload
   - No export needed
   - For backup workflows

### Documentation
- 📖 [**CAPTURE_ONE_INTEGRATION.md**](CAPTURE_ONE_INTEGRATION.md) - Complete integration guide
- 📚 [**CAPTURE_ONE_API_REFERENCE.md**](CAPTURE_ONE_API_REFERENCE.md) - Full AppleScript API documentation

### Technical Notes
- Requires app sandbox to be disabled (direct distribution only, no Mac App Store)
- Uses `osascript` subprocess for reliable AppleScript execution
- Exports to isolated temp folder: `~/Library/Application Support/Picflow/CaptureOneExports/`
- **Recipe Configuration**: Use `root folder type` and `root folder location` properties (NOT `output location`)

**Planned Workflow:**
1. User selects images in Capture One
2. Picflow monitors selection and displays count
3. User triggers upload in Picflow
4. AppleScript exports via "Picflow Upload" recipe to temp folder
5. Picflow auto-uploads exported files
6. Temp files cleaned up automatically

**Example AppleScript:**
```applescript
-- Create/configure export recipe
tell application "Capture One"
    tell document 1
        set newRecipe to make new recipe with properties {name:"Picflow Upload"}
        tell newRecipe
            set root folder type to custom location
            set root folder location to "/path/to/export/folder"
        end tell
        set format of newRecipe to JPEG
        set quality of newRecipe to 90
        
        -- Process selected variants
        set selectedVariants to (get variants whose selected is true)
        repeat with v in selectedVariants
            process v recipe "Picflow Upload"
        end repeat
    end tell
end tell
```

**Resources:**
- [Capture One Scripting Documentation](https://support.captureone.com/hc/en-us/articles/360002681418-Scripting-for-Capture-One)
- AppleScript Dictionary: Open Capture One → Scripts → Open Scripting Dictionary

## Developer Settings

Developer settings (API environment switcher, test features) are automatically hidden in production releases.

**Xcode builds:** Developer settings always visible (no setup needed)

**Production builds:** Enable with terminal command:
```bash
defaults write com.picflow.macos com.picflow.macos.developerMode -bool true
```
Then restart the app. To disable, set to `false`.

## Development & Testing

### Project Structure
The app follows a clean SwiftUI architecture with organized folders:

```
Picflow/
├── App/
│   ├── AppDelegate.swift           # Lightweight lifecycle coordinator
│   ├── MenuBarManager.swift        # Menu bar icon management
│   ├── ContentView.swift           # Root SwiftUI view switcher
│   ├── Constants.swift             # App constants
│   └── PicflowApp.swift            # SwiftUI app entry point with WindowGroup
├── Views/
│   ├── AppView.swift               # Main authenticated container
│   ├── LoginView.swift             # Login screen
│   ├── Gallery/
│   │   ├── GallerySelectionView.swift
│   │   └── GalleryCardView.swift
│   ├── Upload/
│   │   ├── UploaderView.swift      # Main upload interface
│   │   ├── DropAreaView.swift      # Drag & drop UI
│   │   ├── LiveFolderView.swift    # Folder monitoring UI
│   │   ├── CaptureOneStatusView.swift
│   │   └── UploadStatusView.swift  # Unified upload progress
│   ├── Settings/
│   │   └── SettingsView.swift      # App settings & preferences UI
│   ├── Shared/
│   │   ├── AvatarToolbarButton.swift
│   │   └── UserProfileView.swift
│   └── Workspace/
│       └── WorkspaceSelectionView.swift
├── Settings/
│   ├── SettingsManager.swift       # App preferences manager singleton
│   └── SettingsWindowManager.swift # Settings window presentation manager
├── Models/
│   ├── Gallery.swift
│   ├── CreateAssetRequest.swift
│   ├── CreateAssetResponse.swift
│   └── FileEventType.swift
├── Networking/
│   ├── Endpoint.swift
│   └── EndpointError.swift
├── Authenticator.swift
├── Uploader.swift
├── FolderMonitor.swift
├── FolderMonitoringManager.swift
└── CaptureOne/
    ├── CaptureOneMonitor.swift
    ├── CaptureOneScriptBridge.swift
    └── CaptureOneUploadManager.swift
```

### Icon Assets
The app uses custom icon assets from Figma, exported as PDFs with preserve vector data:
- `Picflow-Logo`: App branding (login screen)
- `Capture-One-Logo`: Capture One integration indicator
- `Folder-Sync-Connect`: Live folder monitoring icon
- `Image-Stack-Upload`: Drag & drop upload icon

Icons support light/dark mode variants automatically via Xcode asset catalog.

### Error Reporting (Sentry)
Comprehensive error reporting is integrated throughout the app:
- Upload failures with file context
- Authentication errors
- Folder monitoring issues
- Capture One integration errors

See [SENTRY_SETUP_GUIDE.md](SENTRY_SETUP_GUIDE.md) for complete setup instructions (if available).

## Distribution & Updates

**Distribution Method:** Direct distribution via GitHub Releases and S3  
**Automatic Updates:** Sparkle 2 framework with EdDSA signatures  
**Update URL:** https://picflow.com/download/macos/

### How Updates Work

Picflow uses **Sparkle 2** (industry standard) for secure automatic updates:
- ✅ **Automatic checks** - App checks daily for new versions
- ✅ **Secure updates** - EdDSA signatures + Apple notarization + code signing
- ✅ **User control** - Toggle auto-updates in Settings
- ✅ **Dual URL strategy** - Versioned URLs for Sparkle, static URL for marketing
- ✅ **One-click releases** - Fully automated via `./scripts/release.sh X.Y.Z`

**For detailed setup and release process, see:**
- 📖 [**RELEASE_GUIDE.md**](RELEASE_GUIDE.md) - Complete release guide (setup, releases, updates, debugging, troubleshooting)
- 📂 [**scripts/README.md**](scripts/README.md) - Release script documentation

### Release Process (One Command)

```bash
# Update version in Xcode, then:
./scripts/release.sh 0.2.0

# Automatically:
# 1. Builds and archives app
# 2. Creates and notarizes DMGs (versioned + latest)
# 3. Signs with Sparkle 2 EdDSA
# 4. Uploads to GitHub Releases
# 5. GitHub Action syncs to S3
# 6. Updates appcast.xml for Sparkle
```

**Users get notified and can install updates with one click.**

## TBD

- ~~Distribution: Mac App Store vs direct distribution~~ ✅ Direct distribution with Sparkle 2 implemented
- ~~Authentication: Clerk OAuth with consent page vs JWT token-based flow~~ ✅ OAuth implemented
- ~~Automatic updates~~ ✅ Sparkle 2 with EdDSA signatures implemented
- Feedback sync: Sync favorites and color labels back to photography software (Lightroom, Capture One, Photo Mechanic)
- ~~Multipart uploads: For large files (>20MB)~~ ✅ Implemented with configurable chunk sizes

## Recent Major Updates (October 2025)

**Release Automation & Updates**
- Sparkle 2 auto-updates with EdDSA signatures
- Automated releases: `./scripts/release.sh X.Y.Z` → GitHub → S3 (~7-12 min)
- Dual URL strategy (versioned + static) at https://picflow.com/download/macos/

**Settings & Preferences**
- Comprehensive settings window with organized sections
- Launch at startup, menu bar visibility, auto-updates
- Logs management with 7-day retention

**UI/UX & Architecture**
- Regular dock app + menu bar icon (was menu bar-only)
- Pure SwiftUI WindowGroup with modern window management
- Profile dropdown, workspace selection, Live mode toggle
- Extracted managers: `MenuBarManager`, `SettingsWindowManager`, `SettingsManager`
- Custom Picflow icons with light/dark variants
