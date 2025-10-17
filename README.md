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

- App Sandbox with user-selected read/write file access
- Apple Events permission for host automations (Capture One)
- Custom URL scheme `picflow://` for OAuth callback

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

## TBD

- Distribution: Mac App Store vs direct distribution with [Sparkle](https://sparkle-project.org) (Apple approval concerns)
- Authentication: Clerk OAuth with consent page vs JWT token-based flow
- Feedback sync: Sync favorites and color labels back to photography software (Lightroom, Capture One, Photo Mechanic)
