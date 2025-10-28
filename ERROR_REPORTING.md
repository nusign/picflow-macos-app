# Error Reporting with Sentry

## Overview

Picflow uses **Sentry** for comprehensive error reporting and performance monitoring. The integration captures errors, tracks breadcrumbs, and provides context for debugging production issues.

## Configuration

### Sentry DSN

Configured in: `App/Constants.swift`

```swift
static let sentryDSN = "https://8471a574e3139b4f2c0fc39059ab39f3@o1075862.ingest.us.sentry.io/4510248420048896"
```

### Environment-Aware Setup

Located in: `PicflowApp.swift`

```swift
SentrySDK.start { options in
    options.dsn = Constants.sentryDSN
    options.debug = false
    options.enableAutoSessionTracking = true
    options.attachScreenshot = true
    
    // Environment: "development" or "production"
    let environment = EnvironmentManager.shared.current
    options.environment = environment.rawValue.lowercased()
    
    // Performance monitoring (10% sampling)
    options.tracesSampleRate = 0.1
    
    // Release tracking: "picflow-macos@1.0+1"
    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
       let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
        options.releaseName = "picflow-macos@\(version)+\(build)"
    }
}
```

## What Gets Reported

### Errors Captured

#### 1. **Upload Errors** (`Uploader.swift`)

**File upload failures:**
```swift
SentrySDK.capture(error: error) { scope in
    scope.setContext(value: [
        "file_name": fileURL.lastPathComponent,
        "file_path": fileURL.path,
        "gallery_id": selectedGallery?.id ?? "unknown",
        "gallery_name": selectedGallery?.displayName ?? "unknown",
        "file_index": index,
        "total_files": uploadQueue.count
    ], key: "upload")
    scope.setTag(value: "upload", key: "operation")
    scope.setLevel(.error)
}
```

**Context provided:**
- File name and path
- Gallery ID and name
- Upload batch position (file X of Y)
- File size
- S3 upload errors
- Network failures

#### 2. **Authentication Errors** (`Authenticator.swift`)

**OAuth flow errors:**
```swift
SentrySDK.capture(error: error) { scope in
    scope.setContext(value: [
        "error_code": nsError.code,
        "error_domain": nsError.domain,
        "auth_url": url.absoluteString
    ], key: "oauth")
    scope.setTag(value: "oauth", key: "auth_method")
    scope.setLevel(.error)
}
```

**Profile fetch failures:**
```swift
SentrySDK.capture(error: error) { scope in
    scope.setContext(value: ["auth_method": "jwt_callback"], key: "auth")
    scope.setTag(value: "jwt_callback", key: "auth_method")
    scope.setLevel(.error)
}
```

**Context provided:**
- Auth method (oauth, jwt_callback)
- Error codes and domains
- Authorization URLs
- Code verifier status
- Token exchange failures
- Profile API errors

#### 3. **Folder Monitoring Errors** (`FolderMonitor.swift`)

**Initial read failure:**
```swift
SentrySDK.capture(error: error) { scope in
    scope.setContext(value: ["folder_path": url.path], key: "folder_monitor")
    scope.setTag(value: "folder_monitor", key: "component")
}
```

**Scan failure:**
```swift
SentrySDK.capture(error: error) { scope in
    scope.setContext(value: ["folder_path": url.path], key: "folder_monitor")
    scope.setLevel(.warning)
}
```

**Context provided:**
- Folder path
- Component tag
- Warning level

### Breadcrumbs Tracked

#### Upload Lifecycle Breadcrumbs

**Upload batch started:**
```swift
let breadcrumb = Breadcrumb(level: .info, category: "upload")
breadcrumb.message = "Upload started"
breadcrumb.data = [
    "file_count": uploadQueue.count,
    "gallery_id": selectedGallery?.id ?? "unknown"
]
SentrySDK.addBreadcrumb(breadcrumb)
```

**Individual file uploaded:**
```swift
let breadcrumb = Breadcrumb(level: .info, category: "upload")
breadcrumb.message = "File uploaded successfully"
breadcrumb.data = [
    "file_name": fileURL.lastPathComponent,
    "file_size": fileData.count,
    "gallery_id": gallery.id
]
SentrySDK.addBreadcrumb(breadcrumb)
```

#### Authentication Breadcrumbs

**OAuth login successful:**
```swift
let breadcrumb = Breadcrumb(level: .info, category: "auth")
breadcrumb.message = "OAuth login successful"
breadcrumb.data = ["user_email": profile.user.email]
SentrySDK.addBreadcrumb(breadcrumb)
```

**JWT token authentication:**
```swift
let breadcrumb = Breadcrumb(level: .info, category: "auth")
breadcrumb.message = "JWT token authentication successful"
SentrySDK.addBreadcrumb(breadcrumb)
```

#### Folder Monitoring Breadcrumbs

**Monitoring started:**
```swift
let breadcrumb = Breadcrumb(level: .info, category: "folder_monitor")
breadcrumb.message = "Folder monitoring started"
breadcrumb.data = [
    "folder_path": url.path,
    "initial_file_count": contents.count
]
SentrySDK.addBreadcrumb(breadcrumb)
```

**File added:**
```swift
let breadcrumb = Breadcrumb(level: .info, category: "folder_monitor")
breadcrumb.message = "File added to monitored folder"
breadcrumb.data = ["file_name": file]
SentrySDK.addBreadcrumb(breadcrumb)
```

## Integration Points

### Files with Sentry Integration

1. **`PicflowApp.swift`** ✅ - SDK initialization
2. **`Uploader.swift`** ✅ - Upload errors and lifecycle tracking
3. **`Authenticator.swift`** ✅ - Authentication errors and flow tracking
4. **`FolderMonitor.swift`** ✅ - File system monitoring errors
5. **`CaptureOneMonitor.swift`** ⚠️ - SDK imported, ready for implementation

### Future Integration Points

The following files can be enhanced with Sentry:
- **`CaptureOneUploadManager.swift`** - Export/upload failures
- **`CaptureOneScriptBridge.swift`** - AppleScript execution errors
- **`FolderMonitoringManager.swift`** - Live folder monitoring errors

## Features Enabled

✅ **Automatic Session Tracking** - Tracks app sessions and crashes  
✅ **Stack Trace Attachment** - Attaches stack traces to all events  
✅ **Environment Tagging** - Separates dev/prod errors  
✅ **Release Tracking** - Links errors to specific app versions  
✅ **Performance Monitoring** - 10% transaction sampling  
✅ **Breadcrumb Trail** - Context leading to errors  
✅ **Upload Error Tracking** - Full upload lifecycle with file context  
✅ **Auth Error Tracking** - OAuth and JWT authentication failures  

## Viewing Errors in Sentry

### Dashboard Access

URL: https://sentry.io  
Organization: `o1075862`  
Project: Look for errors under your Sentry project

### What You'll See

**For each error:**
- Error message and full stack trace
- Environment (development/production)
- Release version (e.g., "picflow-macos@1.0+1")
- Breadcrumb trail showing user actions leading to error
- Custom context (file paths, gallery info, auth method, etc.)
- Device and OS information
- Upload batch context (file X of Y)
- Authentication flow details

### Filtering

**By Environment:**
- `environment:development` - Dev builds
- `environment:production` - Production builds

**By Operation:**
- `operation:upload` - Upload failures
- `operation:upload_file` - Individual file upload errors
- `component:folder_monitor` - File system issues

**By Auth Method:**
- `auth_method:oauth` - OAuth flow errors
- `auth_method:jwt_callback` - JWT token errors

**By Release:**
- `release:picflow-macos@1.0+1` - Specific versions

## Testing the Integration

### 1. Verify Initialization

**Run the app** and check console for:
```
[Sentry] SDK initialized
```

### 2. Trigger a Test Error

**Option A: Folder Monitor Error**
- Start monitoring a folder that doesn't exist
- Should report error to Sentry with folder path context

**Option B: Manual Test**
```swift
// Add temporarily to test
SentrySDK.capture(message: "Test error from Picflow")
```

### 3. Check Sentry Dashboard

- Go to https://sentry.io
- Navigate to your project
- Error should appear within seconds
- Verify environment, release, and context are correct

## Best Practices

### Do's
✅ Use breadcrumbs liberally for context  
✅ Add relevant tags for filtering  
✅ Set appropriate error levels (.error, .warning, .info)  
✅ Include context (file paths, user actions, state)  
✅ Test in development before deploying  

### Don'ts
❌ Don't include sensitive data (tokens, passwords)  
❌ Don't report expected errors (404s, validation)  
❌ Don't set tracesSampleRate to 1.0 in production (performance impact)  
❌ Don't forget to test error reporting  

## Performance Impact

**Minimal overhead:**
- Errors are sent asynchronously
- Breadcrumbs stored in memory (limited buffer)
- Performance monitoring at 10% sampling
- Screenshot capture only on errors

**Estimated impact:** < 1% performance overhead

## Troubleshooting

### Errors Not Appearing

1. **Check DSN** - Verify Constants.sentryDSN is correct
2. **Check Environment** - Development errors go to dev environment
3. **Check Network** - Ensure app has network access
4. **Enable Debug** - Set `options.debug = true` temporarily

### Build Issues

1. **Clean Build** - Cmd+Shift+K in Xcode
2. **Reset Package Cache** - File → Packages → Reset Package Caches
3. **Verify Package** - Ensure `sentry-cocoa` is in Package Dependencies

### Common Issues

**Issue:** "Sentry DSN is empty"  
**Fix:** Verify Constants.sentryDSN is set correctly

**Issue:** "Cannot find 'SentrySDK' in scope"  
**Fix:** Ensure `import Sentry` at top of file

**Issue:** "Package resolution failed"  
**Fix:** Check internet connection, reset package caches

## Dependencies

**Package:** `sentry-cocoa`  
**URL:** https://github.com/getsentry/sentry-cocoa  
**Version:** 8.0.0+  
**License:** MIT  

## Resources

- [Sentry Swift Documentation](https://docs.sentry.io/platforms/apple/)
- [Sentry Cocoa GitHub](https://github.com/getsentry/sentry-cocoa)
- [Sentry Dashboard](https://sentry.io)
- [Best Practices](https://docs.sentry.io/platforms/apple/best-practices/)

---

**Status:** ✅ Fully Integrated  
**Last Updated:** January 28, 2025  
**SDK Version:** 8.0.0+

