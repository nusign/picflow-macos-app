# Picflow macOS App (Picflow)

SwiftUI app that uploads assets to Picflow.

## Features

- **Modern macOS App**: Regular dock app with menu bar icon for quick access
- **Visual upload status**: Menu bar icon changes to show upload states (idle, uploading, success, failed)
- **Gallery selection**: Select from available galleries; currently selected gallery is displayed in the upload view
- **Live Folder Monitoring**: Watch a local folder and automatically upload new images to your selected gallery
- **Drag & Drop Upload**: Simple drag-and-drop interface for quick file uploads
- **Uploads**: Presigned S3 multipart uploads with progress tracking and error handling
- **Storage management**: Account storage limits displayed based on tenant data; no per-file size limits
- **Sleep prevention**: Automatically prevents system sleep during active uploads to ensure reliability
- **Auth**: Clerk (OIDC + PKCE) browser-based login; logout supported; tokens stored securely in Keychain
- **Profile Management**: User avatar dropdown in toolbar with quick access to account settings and workspace switching
- **Automation bridges**: Capture One selection read + export via AppleScript/JXA

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
- Window size: 440x320px (login), 380px height (after login), max 960x720px
- Window features rounded corners with modern macOS styling
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

**Profile Management**
- Click profile icon in toolbar to access:
  - Open Picflow (web app)
  - Account Settings
  - Switch Workspace
  - Logout

## Architecture

### App Structure
- **SwiftUI + AppKit**: Menu bar status item, main window, folder monitoring, toolbar integration
- **Authenticator**: Clerk OIDC + PKCE authentication flow with Keychain storage
- **Uploader**: S3 multipart upload with state tracking (idle/uploading/completed/failed)
- **Networking**: API client with JWT bearer tokens and tenant headers
- **Models**: Gallery, Asset, Tenant response structures

### UI Components
- **AppDelegate**: Menu bar management, window lifecycle, toolbar setup, upload state icon updates
- **AppView**: Main authenticated container with navigation state management
- **LoginView**: Modern login screen with Picflow branding
- **GallerySelectionView**: Gallery picker with async loading, workspace indicator, optimized card layout
- **UploaderView**: Upload interface with Live mode toggle and drag & drop
- **LiveFolderView**: Folder selection interface for automated monitoring
- **DropAreaView**: Drag & drop zone for manual file uploads
- **AvatarToolbarButton**: Profile dropdown with workspace/account management
- **CaptureOneStatusView**: Capture One integration status and controls

### Key Features Implementation
- **Dock & Menu Bar App**: Standard macOS app with `.regular` activation policy
- **Modern Window**: Fixed sizing (440x320 login, 380 height after login), rounded corners via unified toolbar style
- **Profile Dropdown**: NSToolbar integration with SwiftUI popover
- **Upload States**: Published `UploadState` enum with auto-reset timers
- **Folder Monitoring**: `FolderMonitor` with FSEvents watching for file additions
- **Live Mode Toggle**: Switch between manual and automated upload workflows
- **Sleep Prevention**: `NSProcessInfo.processInfo.beginActivity` with `.userInitiated` option during uploads

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

## Development & Testing

### Project Structure
The app follows a clean SwiftUI architecture with organized folders:

```
Picflow/Picflow/
├── App/
│   ├── AppDelegate.swift           # Main app lifecycle & window management
│   └── PicflowApp.swift            # SwiftUI app entry point
├── Views/
│   ├── AppView.swift               # Main authenticated container
│   ├── LoginView.swift             # Login screen
│   ├── Gallery/
│   │   ├── GallerySelectionView.swift
│   │   └── GalleryCardView.swift
│   ├── Upload/
│   │   ├── UploaderView.swift      # Main upload interface
│   │   ├── DropAreaView.swift      # Drag & drop UI
│   │   └── LiveFolderView.swift    # Folder monitoring UI
│   ├── Shared/
│   │   ├── AvatarToolbarButton.swift
│   │   └── CaptureOneStatusView.swift
│   └── Workspace/
│       └── WorkspaceSelectionView.swift
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

## TBD

- Distribution: Mac App Store vs direct distribution with [Sparkle](https://sparkle-project.org) (Apple approval concerns - sandboxing required for App Store)
- ~~Authentication: Clerk OAuth with consent page vs JWT token-based flow~~ ✅ OAuth implemented
- Feedback sync: Sync favorites and color labels back to photography software (Lightroom, Capture One, Photo Mechanic)
- Multipart uploads: For large files (>20MB), investigate backend multipart upload support

## Recent Major Updates

### UI/UX Improvements (October 2025)
- ✅ Converted from menu bar-only app to regular dock app with menu bar icon for quick access
- ✅ Added profile dropdown in toolbar with workspace/account management
- ✅ Implemented workspace selection flow via notification-based navigation
- ✅ Redesigned window sizing: 440x320px (login), 380px+ (after login), max 960x720px
- ✅ Added rounded corners via unified toolbar style (no manual traffic light positioning)
- ✅ Optimized gallery card layout with 4:3 preview images, centered 640px max width
- ✅ Fixed gallery asset count display (removed CodingKeys conflict with snake_case decoder)
- ✅ Added Live mode toggle for folder monitoring workflow
- ✅ Integrated custom Picflow icons (PDFs with light/dark variants)
- ✅ Disabled autofocus on launch and in popovers for cleaner UX
- ✅ Added "Current Workspace" indicator in gallery selection view

### Architecture Improvements
- ✅ Removed complex window attach/detach logic in favor of standard window behavior
- ✅ Simplified AppDelegate with better MainActor isolation
- ✅ Created reusable `GenericUploadProgressView` component (eliminated code duplication)
- ✅ Organized views into logical folders: App/, Views/Gallery/, Views/Upload/, Views/Shared/, Views/Workspace/
