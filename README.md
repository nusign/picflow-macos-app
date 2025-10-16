# Picflow macOS App (Picflow)

SwiftUI menubar app that uploads images to Picflow.

## Features

- **Menu bar app**: Lives in the menu bar with no Dock icon; clean, unobtrusive interface
- **Detachable popover**: Click the menu bar icon to show a popover; drag it away to convert to a floating window with standard controls (close, minimize, resize)
- **Visual upload status**: Menu bar icon changes to show upload states (idle, uploading, success, failed) using SF Symbols with custom asset fallbacks
- **Gallery selection**: Select from available galleries; currently selected gallery is displayed in the popover
- **Folder watch mode**: Enable/disable watching, pick a folder (auto-reselects last), stop watching anytime; new files auto-upload
- **Uploads**: Presigned S3 multipart uploads with progress tracking and error handling
- **Auth**: Clerk (OIDC + PKCE) browser-based login; logout supported; tokens stored securely in Keychain
- **Automation bridges** (planned): Capture One, Lightroom Classic, Photo Mechanic selection read + export via AppleScript/JXA

## Requirements

- macOS 15+
- Xcode 16+
- Picflow account and Clerk application configured for OIDC

## Auth Configuration (Clerk)

- Domain: `clerk.picflow.com`
- Redirect URI: `picflow://auth/callback`
- Client ID: set in app configuration (Info.plist key `ClerkClientId`)

The app launches the system browser via `ASWebAuthenticationSession`, completes login at Clerk, and stores tokens in the Keychain. API requests attach the Bearer token; refresh is attempted on 401.

## Permissions

- App Sandbox with user-selected read/write file access
- Apple Events permission for host automations (Capture One, LR Classic, Photo Mechanic)
- Custom URL scheme `picflow://` for OAuth callback

## Usage

### First Launch
1. **Launch app** - The app appears in the menu bar (no Dock icon)
2. **Click menu bar icon** - A popover appears below the icon
3. **Authenticate** - Click Login to authenticate with Clerk via browser
4. **Select gallery** - Choose a gallery from your workspace

### Daily Use

**Quick Access (Popover Mode)**
- Click the menu bar icon to show the popover
- Select or change gallery
- Click outside to dismiss

**Detached Window Mode**
- Click and drag the popover away from the menu bar
- The popover transforms into a floating window with close/minimize/resize controls
- Position the window anywhere on your screen
- Close the window when done; next click shows the popover again

**Upload Status**
- Menu bar icon shows current state:
  - 📷 Idle (default icon or `photo.on.rectangle`)
  - ⬆️ Uploading (`arrow.up.circle`)
  - ✅ Success (`checkmark.circle.fill`) - shows for 3 seconds
  - ❌ Failed (`xmark.circle.fill`)

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
- **DropAreaView**: Drag & drop zone for file uploads (planned)

### Key Features Implementation
- **Detachable Popover**: `NSPopoverDelegate` with `popoverShouldDetach` and `detachableWindow(for:)`
- **Menu Bar Only**: `.accessory` activation policy (no Dock icon)
- **Upload States**: Published `UploadState` enum with auto-reset timers
- **Folder Monitoring**: `FolderMonitor` with FSEvents watching for file additions

## Troubleshooting

- Auth fails: verify Client ID and that `picflow://auth/callback` is registered at Clerk
- Folder watch not triggering: ensure the folder permission was granted and still valid; reselect folder
- Upload errors: check network connectivity and reauthenticate; the queue will retry failed parts with backoff

## Roadmap

- Enhanced automation options and host coverage
- More granular queue controls and per-file diagnostics
