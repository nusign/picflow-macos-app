# Sentry Setup Guide

This guide will walk you through completing the Sentry integration for error reporting in Picflow.

## Implementation Status

✅ **Completed:**
- Test token authentication button added to LoginView
- Sentry error reporting code added (commented out) in:
  - `Uploader.swift` - Upload failures with file context
  - `Authenticator.swift` - Authentication failures
  - `FolderMonitor.swift` - Folder monitoring errors
  - `CaptureOneMonitor.swift` - Capture One integration errors
- Sentry initialization code added to `PicflowApp.swift`
- Constants prepared for Sentry DSN

⏳ **Remaining Steps:**
1. Create Sentry project and get DSN
2. Add Sentry SDK via Swift Package Manager
3. Update Constants with your Sentry DSN
4. Uncomment Sentry code throughout the app

---

## Step 1: Create a Sentry Project

1. Go to [sentry.io](https://sentry.io) and sign up or log in
2. Click **"Create Project"**
3. Select **"Apple"** as the platform
4. Name your project: `picflow-macos`
5. Choose your team
6. Click **"Create Project"**
7. Copy the **DSN** (it looks like: `https://[key]@[org].ingest.sentry.io/[project-id]`)

---

## Step 2: Add Sentry SDK via Swift Package Manager

### In Xcode:

1. Open `Picflow.xcodeproj` in Xcode
2. Go to **File → Add Package Dependencies...**
3. In the search bar, paste: `https://github.com/getsentry/sentry-cocoa`
4. Click **"Add Package"**
5. Select the **"Sentry"** product (check the box)
6. Click **"Add Package"**

The Sentry SDK will now be added to your project.

---

## Step 3: Update Constants with Your Sentry DSN

Open `Picflow/Picflow/Constants.swift` and replace the placeholder:

```swift
static let sentryDSN = "YOUR_SENTRY_DSN_HERE"
```

With your actual DSN from Step 1:

```swift
static let sentryDSN = "https://[your-key]@[your-org].ingest.sentry.io/[your-project-id]"
```

---

## Step 4: Uncomment Sentry Code

Now that Sentry SDK is installed, uncomment all the Sentry code in the following files:

### 4.1 PicflowApp.swift

Uncomment:
```swift
import Sentry
```

And the entire `SentrySDK.start { ... }` block in `init()`

### 4.2 Uploader.swift

Uncomment:
```swift
import Sentry
```

And all `SentrySDK.addBreadcrumb(...)` and `SentrySDK.capture(...)` calls

### 4.3 Authenticator.swift

Uncomment:
```swift
import Sentry
```

And all Sentry-related code blocks

### 4.4 FolderMonitor.swift

Uncomment:
```swift
import Sentry
```

And all Sentry-related code blocks

### 4.5 CaptureOneMonitor.swift

Uncomment:
```swift
import Sentry
```

And all Sentry-related code blocks

---

## Step 5: Test the Integration

1. **Build and run** the app
2. Check the Xcode console for any Sentry initialization messages
3. Test error scenarios:
   - Try uploading a file with no gallery selected
   - Try authenticating with an invalid token
   - Check the Sentry dashboard for reported errors

---

## What Gets Reported to Sentry

### Errors Captured:

1. **Upload Failures**
   - Context: File name, size, gallery ID, section
   - Tags: operation=upload, gallery_id

2. **Authentication Failures**
   - OAuth callback errors
   - Token exchange failures
   - Profile fetch failures
   - Context: Auth method (oauth, manual_token, jwt_callback)

3. **Folder Monitoring Errors**
   - Failed to read folder contents
   - File system event processing errors
   - Context: Folder path

4. **Capture One Integration Errors**
   - Permission denied
   - AppleScript execution errors
   - Context: Capture One running status

### Breadcrumbs Tracked:

- Upload lifecycle (started, asset created, completed)
- Authentication flow (method, success)
- Tenant details loaded
- Folder monitoring started/file added
- Manual token usage

---

## Sentry Configuration Options

In `PicflowApp.swift`, you can customize:

```swift
options.debug = true  // Enable for troubleshooting Sentry itself
options.environment = "development"  // or "staging", "production"
options.tracesSampleRate = 0.1  // Performance monitoring (10% sampling)
```

### Environments:

Consider using different Sentry environments:
- **development**: Your local machine
- **staging**: TestFlight builds
- **production**: App Store / direct distribution releases

You can set this dynamically based on build configuration.

---

## Best Practices

1. **Don't include sensitive data**: Tokens are already excluded from error reports
2. **Use breadcrumbs liberally**: They help understand the sequence of events leading to errors
3. **Tag errors appropriately**: Makes it easier to filter in Sentry dashboard
4. **Set user context** (optional): After authentication, you can identify users for better tracking
5. **Release tracking**: Already configured to use app version + build number

---

## Verifying It Works

After setup, test by triggering an error:

1. Click **"Use Test Token"** to log in
2. Try uploading a file without selecting a gallery
3. Go to your Sentry dashboard at `https://sentry.io`
4. You should see the error appear within seconds

---

## Troubleshooting

### Sentry not reporting errors:

1. Check that DSN is correct in `Constants.swift`
2. Verify all Sentry code is uncommented
3. Check Xcode console for Sentry initialization logs
4. Temporarily set `options.debug = true` in PicflowApp.swift

### Build errors:

1. Make sure Sentry package was added correctly via SPM
2. Clean build folder: **Product → Clean Build Folder**
3. Restart Xcode

### Package resolution issues:

1. Go to **File → Packages → Reset Package Caches**
2. Go to **File → Packages → Update to Latest Package Versions**

---

## Resources

- [Sentry Swift Documentation](https://docs.sentry.io/platforms/apple/)
- [Sentry Cocoa GitHub](https://github.com/getsentry/sentry-cocoa)
- [Sentry Dashboard](https://sentry.io)

---

## Test Token Feature

The new **"Use Test Token"** button in LoginView allows you to quickly authenticate during development without going through the OAuth flow:

- Click **"Use Test Token"** → instantly authenticated
- A **"Test Mode"** badge shows when using hardcoded token
- Tenant ID is automatically set
- OAuth flow remains available via **"Login with Clerk"**

This makes testing much faster during development!

