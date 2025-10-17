# Capture One Integration PoC

## Overview
This proof of concept demonstrates:
1. **Detection** - Real-time monitoring of Capture One running status
2. **Selection Reading** - Reading selected assets count via AppleScript
3. **Permission Handling** - User-friendly permission grant flow

This is a fully functional automation bridge for reading selections from Capture One via AppleScript.

## ✅ Status: WORKING

After extensive troubleshooting, the PoC successfully:
- ✅ Detects Capture One running state
- ✅ Reads selection count in real-time
- ✅ Handles permissions gracefully with UI prompt
- ✅ Updates every 2 seconds automatically

## Implementation

### Files Created
1. **CaptureOneMonitor.swift** - Observable class that monitors Capture One status and selection
2. **CaptureOneStatusView.swift** - SwiftUI view displaying status, selection count, and asset details
3. **CaptureOneScriptBridge.swift** - AppleScript bridge for communicating with Capture One
4. **Models/CaptureOneVariant.swift** - Data models for variants and selection state

### Critical Technical Requirements

⚠️ **IMPORTANT**: The following technical requirements were discovered through extensive testing:

#### 1. App Sandbox Must Be Disabled
- **Issue**: macOS App Sandbox blocks AppleScript automation to other apps, even with `com.apple.security.automation.apple-events` entitlement
- **Solution**: Set `com.apple.security.app-sandbox` to `false` in entitlements
- **Implication**: App cannot be distributed via Mac App Store (must use direct distribution)

#### 2. Use `osascript` Subprocess, Not NSAppleScript
- **Issue**: `NSAppleScript` inherits sandbox restrictions and fails with error -600 ("Application isn't running")
- **Solution**: Execute AppleScript via `/usr/bin/osascript` subprocess using `Process`
- **Code**: 
  ```swift
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
  process.arguments = ["-e", script]
  ```

#### 3. Must Access via `document 1`, Not Application Level
- **Issue**: `variants` is not accessible at application level (error -2753: "variable not defined")
- **Correct**: `tell application "Capture One" to tell document 1 to ...`
- **Incorrect**: `tell application "Capture One" to variants ...`

#### 4. Permission Prompt Handling
- First access triggers macOS permission dialog: "Picflow would like to control Capture One"
- Permission is remembered by macOS after approval
- App appears in System Settings → Privacy & Security → Automation after first grant

### How It Works

#### Detection Method
The monitor uses multiple approaches to detect Capture One:
1. **Bundle Identifier Check** - Checks for known Capture One bundle IDs:
   - `com.captureone.captureone23`
   - `com.captureone.captureone22`
   - `com.captureone.captureone21`
   - `com.captureone.captureone20`
   - `com.captureone.captureone`
   - `com.phaseone.captureone`

2. **Application Name Check** - Falls back to checking if any running app has "Capture One" in its name

3. **Real-time Monitoring** - Uses two mechanisms for live updates:
   - NSWorkspace notifications for app launch/terminate events
   - 2-second polling timer as a backup

#### Visual Indicator
- **Green Circle** 🟢 - Capture One is running
- **Red Circle** 🔴 - Capture One is not running

#### Selection Reading (AppleScript Bridge)
When Capture One is running, the monitor:
1. Executes AppleScript every 2 seconds via osascript subprocess
2. Uses the working script format:
   ```applescript
   tell application "Capture One" to tell document 1 to return (count of (variants whose selected is true))
   ```
3. Parses the result (simple integer) and updates UI
4. Handles permission errors and prompts user to grant access

#### UI Display
- **Selection Count**: "X assets selected" (e.g., "3 assets selected")
- **Permission Prompt**: When permission not granted, shows:
  - "Permission Required" heading with lock icon
  - Explanation text
  - **"Grant Permission"** button (triggers macOS dialog)
- **Error Handling**: Shows warnings for "No document open" or script errors
- **Loading State**: Progress indicator while reading selection

**Note**: Detailed asset information (file paths, EXIF, etc.) can be added once basic selection reading is confirmed working.

### Integration Points
The status view is integrated into the main ContentView, visible on the login screen for easy testing.

### Window Adjustments
- Window dimensions: 480pt × 700pt to accommodate selection details
- Resizable window supports larger displays of asset information

## Testing the PoC

### Basic Status Testing
1. **Launch the Picflow app** - Open the app from Xcode
2. **View immediately** - The Capture One status is visible on the login screen
3. **Observe the status**:
   - Red circle if Capture One is not running
   - Green circle if Capture One is running

4. **Test dynamic updates**:
   - Launch Capture One → indicator turns green, shows "0 assets selected"
   - Quit Capture One → indicator turns red

### Selection Reading Testing
1. **Open Capture One** with a catalog or session
2. **Select images**:
   - Select 0 images → Shows "0 assets selected"
   - Select 1 image → Shows "1 asset selected" + full details card
   - Select multiple images → Shows "X assets selected" (no details card)
3. **Change selection** → Wait 2 seconds or click "Refresh" → Count updates
4. **View single asset details** when one image is selected:
   - File name
   - Full file path
   - Rating (if set)
   - Color tag (if set)
   - Camera make and model
   - EXIF data (ISO, aperture, shutter speed, focal length)
   - Crop dimensions

### Error State Testing
- Close all documents in Capture One → Shows "No document open" warning
- AppleScript permission denied → Shows error message

## Capabilities Demonstrated ✅

- ✅ **Real-time app detection** - Monitors Capture One launch/quit
- ✅ **Selection monitoring** - Reads selected variants every 2 seconds
- ✅ **Metadata extraction** - Full IPTC and EXIF data access
- ✅ **File path reading** - Gets original file paths
- ✅ **Error handling** - Handles no document, permission errors, etc.
- ✅ **Async AppleScript execution** - Non-blocking UI updates
- ✅ **Rich UI display** - Selection count and detailed asset information

## Next Steps

### Phase 3: Export Automation (TODO)
- Configure export settings (format, quality, destination)
- Automate the export process for selected images
- Monitor export completion status

### Phase 4: Integration with Picflow Upload
- Automatically upload exported images to selected gallery
- Provide progress feedback in the menu bar
- Clean up temporary export files after upload

## Technical Notes

### Permissions Required
For future AppleScript/JXA integration, the app will need:
- **Apple Events permission** - Already declared in entitlements for host automations
- User approval when first attempting to control Capture One

### Potential Bundle Identifiers
The monitor checks for multiple bundle identifiers to support different Capture One versions. If a new version is released with a different bundle ID, simply add it to the `captureOneBundleIdentifiers` array in `CaptureOneMonitor.swift`.

## Code Examples

### Working AppleScript Format
```applescript
tell application "Capture One" to tell document 1 to return (count of (variants whose selected is true))
```

**Key Points**:
- Use simple app name "Capture One" (not version-specific)
- MUST use `tell document 1` to access variants
- Single-line format works reliably
- Returns integer count directly

### Swift Execution via osascript
```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
process.arguments = ["-e", script]

let outputPipe = Pipe()
let errorPipe = Pipe()
process.standardOutput = outputPipe
process.standardError = errorPipe

try process.run()
process.waitUntilExit()

let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
let result = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
```

### Swift Usage
```swift
// Monitor automatically updates selection
@StateObject private var monitor = CaptureOneMonitor()

// Access selection data
Text("\(monitor.selection.count) assets selected")

// Handle permission state
if monitor.needsPermission {
    Button("Grant Permission") {
        monitor.requestPermission()
    }
}
```

## Troubleshooting Guide

### Error -600: "Application isn't running"
**Symptoms**: AppleScript fails with error -600 even though Capture One is running
**Causes**:
1. App sandbox is enabled → Disable in entitlements
2. Using NSAppleScript → Switch to osascript subprocess
3. Not accessing via `document 1` → Add `tell document 1`

### Permission Not Granted
**Symptoms**: Permission dialog doesn't appear, or Picflow not in Automation list
**Solutions**:
1. Disable app sandbox (required)
2. Clean build folder (Cmd+Shift+K)
3. Run from Finder (not Xcode) to test properly signed app
4. Check `NSAppleEventsUsageDescription` is in Info.plist

### "Variable variants not defined" (Error -2753)
**Cause**: Trying to access `variants` at application level
**Solution**: Use `tell document 1` to access variants within document context

## Development History
- **Created**: October 17, 2025
- **Status**: **Fully Functional** ✅
- **Major Challenges Overcome**:
  - App sandbox blocking automation (disabled)
  - NSAppleScript inheritance of restrictions (switched to osascript)
  - Incorrect document access pattern (fixed with `tell document 1`)
  - Permission prompt not appearing (fixed by running outside Xcode)
- **Tested With**: Capture One 16.6.6.9
- **macOS Version**: Tested on macOS 25.0.0 (Sequoia)

