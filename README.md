# Picflow macOS App (Picflow)

SwiftUI app that uploads assets to Picflow.

## Features

- **Detachable popover**: Click the menu bar icon to show a popover; drag it away to convert to a floating window with standard controls
- **Visual upload status**: Menu bar icon changes to show upload states (idle, uploading, success, failed)
- **Gallery selection**: Select from available galleries; currently selected gallery is displayed in the popover
- **Folder watch mode**: Enable/disable watching, pick a folder (auto-reselects last), stop watching anytime; new files auto-upload
- **Uploads**: Presigned S3 multipart uploads with progress tracking and error handling
- **Storage management**: Account storage limits displayed based on tenant data; no per-file size limits
- **Sleep prevention**: Automatically prevents system sleep during active uploads to ensure reliability
- **Auth**: Clerk (OIDC + PKCE) browser-based login; logout supported; tokens stored securely in Keychain
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
1. **Launch app** - The app appears in the menu bar
2. **Click menu bar icon** - A popover appears below the icon
3. **Authenticate** - Click Login to authenticate with Clerk via browser
4. **Select gallery** - Choose a gallery from your workspace

### Daily Use

**Popover Mode**
- Click the menu bar icon to show the popover
- Click outside to dismiss

**Detached Window Mode**
- Click and drag the popover away from the menu bar
- The popover transforms into a floating window with close/minimize/resize controls
- Position the window anywhere on your screen
- Close the window when done; next click shows the popover again
- Reattaching to popover mode when dragging back to menu bar icon

**Upload Status**
- Menu bar icon should show current state (uploading, completed, errors) while uploading
- Display current count of files being uploaded with progress indication
- Show checkmark when each file completes, then auto-dismiss after brief delay

**Folder Monitoring**
- Enable folder watch in the app
- New files added to the watched folder auto-upload to the selected gallery
- Monitor upload progress via the menu bar icon

## Architecture

### App Structure
- **SwiftUI + AppKit**: Menu bar status item, detachable popover, folder monitoring
- **Authenticator**: Clerk OIDC + PKCE authentication flow with Keychain storage
- **Uploader**: S3 multipart upload with state tracking (idle/uploading/completed/failed)
- **Networking**: API client with JWT bearer tokens and tenant headers
- **Models**: Gallery, Asset, Tenant response structures

### UI Components
- **AppDelegate**: Menu bar management, popover/window lifecycle, upload state icon updates
- **ContentView**: Main UI showing login prompt or gallery selection
- **GallerySelectionView**: Gallery picker with async loading
- **SelectedGalleryView**: Gallery preview with thumbnail
- **DropAreaView**: Drag & drop zone for file uploads

### Key Features Implementation
- **Detachable Popover**: Custom `NSWindow` with drag-based attach/detach behavior and animated snapping
- **Menu Bar Only**: `.accessory` activation policy (no Dock icon)
- **Upload States**: Published `UploadState` enum with auto-reset timers
- **Folder Monitoring**: `FolderMonitor` with FSEvents watching for file additions
- **Sleep Prevention**: `NSProcessInfo.processInfo.beginActivity` with `.userInitiated` option during uploads

## Capture One Integration

### Detection
- **CaptureOneMonitor**: Real-time detection of Capture One app status (running/not running)
- **NSWorkspace integration**: Monitors app launch/terminate events + 2-second polling fallback
- **Multi-version support**: Detects Capture One versions 15, 16, 20, 21, 22, 23

### AppleScript Automation Capabilities
Capture One provides extensive AppleScript support for workflow automation. See [CAPTURE_ONE_APPLESCRIPT_CAPABILITIES.md](CAPTURE_ONE_APPLESCRIPT_CAPABILITIES.md) for full details.

**Key Capabilities:**
- ✅ **Selection reading**: Get count and properties of selected variants
- ✅ **File access**: Read file paths, names, and metadata of selected images
- ✅ **Metadata**: Full access to IPTC, EXIF, ratings, color tags, GPS coordinates
- ✅ **Process/Export**: Trigger exports using Capture One recipes via `process` command
- ✅ **Adjustments**: Copy/apply/reset adjustments between variants
- ✅ **Image operations**: Rotate, crop, autoadjust selected images

**Planned Workflow:**
1. User selects images in Capture One
2. Picflow monitors selection and displays count
3. User triggers upload in Picflow
4. AppleScript exports via "Picflow Upload" recipe to temp folder
5. Picflow auto-uploads exported files
6. Temp files cleaned up automatically

**Example AppleScript:**
```applescript
tell application "Capture One 16"
    tell front document
        -- Get selected variants
        set selectedVariants to (get variants whose selected is true)
        
        -- Process with Picflow recipe
        repeat with v in selectedVariants
            process v recipe "Picflow Upload"
        end repeat
    end tell
end tell
```

**Resources:**
- [Capture One Scripting Documentation](https://support.captureone.com/hc/en-us/articles/360002681418-Scripting-for-Capture-One)
- AppleScript Dictionary: Open Capture One → Scripts → Open Scripting Dictionary

## TBD

- Distribution: Mac App Store vs direct distribution with [Sparkle](https://sparkle-project.org) (Apple approval concerns)
- Authentication: Clerk OAuth with consent page vs JWT token-based flow
- Feedback sync: Sync favorites and color labels back to photography software (Lightroom, Capture One, Photo Mechanic)
