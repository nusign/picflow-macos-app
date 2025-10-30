# Error Alert Implementation Summary

## Overview

Implemented a centralized error alert system to ensure users are notified when errors occur, rather than silently swallowing them. Previously, errors were only logged to console and reported to Sentry, but users never saw what went wrong.

## Problem

The Picflow app was catching errors everywhere but not showing them to users:

1. **Upload errors**: Files failed to upload but user only saw vague status messages
2. **Authentication errors**: OAuth failures left users confused with no feedback
3. **Capture One errors**: Export/upload failures were logged but not displayed
4. **Folder monitoring errors**: Live folder uploads failed silently after retries
5. **No SwiftUI alerts**: Zero `.alert()` modifiers found in the entire Views directory

Errors were being:
- ✅ Logged to console (good for developers)
- ✅ Reported to Sentry (good for developers)
- ❌ **Not shown to users** (bad for UX)

## Solution

Created a centralized `ErrorAlertManager` that:
- Shows user-friendly error alerts
- Still logs to console for debugging
- Still reports to Sentry for monitoring
- Provides helper methods for common error types
- Uses SwiftUI alerts for consistent presentation

## Files Changed

### New Files

1. **`Picflow/Services/ErrorAlertManager.swift`** (NEW)
   - Centralized error alert management
   - Helper methods for different error contexts (upload, auth, Capture One, folder monitoring, network)
   - SwiftUI modifier for automatic alert display
   - Integration with Sentry for error tracking

### Modified Files

2. **`Picflow/Views/AppView.swift`**
   - Added `.errorAlert()` modifier to show alerts app-wide

3. **`Picflow/Services/Uploader.swift`**
   - Added error alerts when file uploads fail
   - Shows user-friendly message with file name

4. **`Picflow/Services/Authenticator.swift`**
   - Added error alerts for OAuth authentication failures
   - Does NOT show alert for session restoration (expected to fail when tokens expire)

5. **`Picflow/Services/CaptureOneUploadManager.swift`**
   - Added error alerts for:
     - Failed to get file paths from Capture One
     - Export failures
     - Upload failures
     - Recipe recreation failures

6. **`Picflow/Services/FolderMonitoringManager.swift`**
   - Added error alerts when live folder upload fails after max retries (3 attempts)
   - Shows clear message that file will be skipped

## Usage

### For Users

Users will now see a native alert dialog whenever a critical error occurs:

- **Upload fails**: "Upload Failed - Failed to upload [filename]. Please try again."
- **Auth fails**: "Authentication Failed - Failed to complete authentication. Please try again."
- **Capture One error**: "Capture One Error - [specific error message]"
- **Folder monitoring**: "Folder Monitoring Error - Failed to upload [filename] from live folder after 3 attempts. The file will be skipped."

### For Developers

To show an error alert from anywhere in the app:

```swift
// Basic error alert
ErrorAlertManager.shared.showError(
    title: "Operation Failed",
    message: "Something went wrong. Please try again.",
    error: error,
    context: .general
)

// Helper methods for common cases
ErrorAlertManager.shared.showUploadError(fileName: "photo.jpg", error: error)
ErrorAlertManager.shared.showAuthenticationError(message: "Login failed", error: error)
ErrorAlertManager.shared.showCaptureOneError(message: "Export failed", error: error)
ErrorAlertManager.shared.showFolderMonitoringError(message: "Failed to monitor folder", error: error)
ErrorAlertManager.shared.showNetworkError(message: "Connection failed", error: error)
```

## Error Contexts

The system supports different error contexts for better categorization in Sentry:

- `general`: Generic errors
- `upload`: File upload errors
- `authentication`: Auth/login errors
- `captureOne`: Capture One integration errors
- `folderMonitoring`: Live folder monitoring errors
- `network`: Network/API errors

## When NOT to Show Alerts

Some errors are intentionally NOT shown as alerts because they have inline UI handling:

1. **Gallery loading errors**: `GallerySelectionView` shows inline error with retry button
2. **Workspace loading errors**: `WorkspaceSelectionView` shows inline error view
3. **Session restoration failures**: Expected when tokens expire, user just logs in again

## Logging for Non-Developers

For users like Nathan who don't use Xcode, errors are visible in **two** ways:

### 1. On-Screen Alert Dialogs (Primary)
- Native macOS alert pops up when errors occur
- Clear, user-friendly messages
- No technical knowledge required

### 2. Console.app Logs (For Debugging)
We use **Apple's unified logging system** (`os.log`) which shows up beautifully in Console.app:

**How to view in Console.app:**
1. Open `/Applications/Utilities/Console.app`
2. Click **Action** menu → **Include Info/Debug Messages**
3. In search bar, type: `subsystem:com.picflow`
4. All Picflow errors appear with ❌ emoji prefix

**Example log entry:**
```
❌ Upload Failed: Failed to upload photo.jpg. Please try again. - Details: The Internet connection appears to be offline.
```

**Why unified logging is better than print():**
- ✅ Properly categorized and filterable in Console.app
- ✅ Persisted even after app closes
- ✅ Performance optimized for production
- ✅ Structured with subsystem and category metadata

## Benefits

✅ **Better UX**: Users know when something goes wrong and what to do about it
✅ **Transparency**: No more silent failures
✅ **Debugging**: Logs visible in Console.app for non-developers (not just Xcode)
✅ **Production-ready logging**: Uses Apple's unified logging system (os.log)
✅ **Consistency**: All errors use the same alert system
✅ **Maintainable**: Centralized error handling logic

## Testing

To test the error alert system:

1. **Upload error**: Try uploading when offline
2. **Auth error**: Manually trigger an auth failure
3. **Capture One error**: Try export with Capture One not running
4. **Folder monitoring error**: Place a locked file in monitored folder

## Future Improvements

Potential enhancements:

1. **Error details toggle**: Allow users to expand and see technical error details
2. **Copy to clipboard**: Let users copy error messages for support tickets
3. **Error recovery actions**: Suggest specific fixes based on error type
4. **Rate limiting**: Prevent alert spam if multiple files fail rapidly
5. **Persistent error log**: Keep a history of errors in the app for user reference

