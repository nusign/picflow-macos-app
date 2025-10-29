# Sparkle Debugging Guide

## How to View Sparkle Logs

The app now includes comprehensive logging for Sparkle updates. Here's how to view the logs:

### Option 1: Console.app (Recommended for Production Builds)

1. Open **Console.app** (found in `/Applications/Utilities/`)
2. In the search bar, enter: `subsystem:com.picflow.macos category:Sparkle`
3. Click "Start" to begin streaming logs
4. Launch Picflow and check for updates
5. Watch the logs appear in real-time

### Option 2: Terminal (For Development Builds)

When running from Xcode, logs will appear in Xcode's debug console automatically.

You can also view system logs in Terminal:
```bash
log stream --predicate 'subsystem == "com.picflow.macos" AND category == "Sparkle"' --level debug
```

Then launch Picflow in another window.

### Option 3: Export Logs for Analysis

To export recent logs to a file for analysis:
```bash
log show --predicate 'subsystem == "com.picflow.macos" AND category == "Sparkle"' --last 1h > sparkle_logs.txt
```

## What the Logs Tell You

### On App Launch
You should see:
- ✅ Bundle ID, version, and build number
- ✅ Sparkle Feed URL configuration
- ✅ Sparkle Public Key (first 20 characters)
- ✅ Whether Sparkle can check for updates
- ✅ Auto-check settings

### When Checking for Updates
You should see:
- ✅ Manual update check triggered
- ✅ Appcast loading
- ✅ Number of items found in appcast
- ✅ Version numbers available
- ✅ Whether an update was found
- ❌ Any errors that occur

### Common Issues and What Logs Will Show

#### Issue: "Unable to Check For Updates"
**Logs will show:**
- `canCheckForUpdates = false`
- Reasons why (code signing, development mode, etc.)

**Solutions:**
1. **Running from Xcode**: This is expected. Sparkle doesn't work in development builds because:
   - App isn't properly code-signed
   - Bundle structure is different
   - No hardened runtime
   
   **Fix**: Test with a notarized .dmg instead

2. **Production build still failing**: Check logs for:
   - Missing Info.plist keys
   - Code signing issues
   - Sparkle framework not embedded

#### Issue: "Appcast won't load"
**Logs will show:**
- Error loading appcast URL
- Network errors
- Invalid XML

**Solutions:**
1. Check that `https://picflow.com/download/macos/appcast.xml` is accessible
2. Verify CloudFront cache is cleared
3. Check XML syntax

#### Issue: "Invalid signature"
**Logs will show:**
- Signature verification failed
- EdDSA key mismatch

**Solutions:**
1. Verify the public key in Info.plist matches the private key used for signing
2. Check that the appcast.xml signature is correct
3. Re-run the release script to regenerate signatures

## Expected Behavior

### In Development (Xcode)
- ⚠️ **Sparkle will NOT work** - this is normal and expected
- Logs will show: "Running in DEBUG mode - Sparkle may not work properly"
- The "Check for Updates" button will be disabled
- Error: "The update checker failed to start correctly"

This is because:
- Development builds aren't code-signed with Distribution certificates
- The bundle structure is different
- Sparkle requires a properly signed, notarized app

### In Production (Notarized .dmg)
- ✅ Sparkle should work normally
- "Check for Updates" button should be enabled
- Should connect to appcast and check for updates
- Should download and install updates automatically

## Testing Checklist

1. **View logs in Console.app** before launching the app
2. **Launch Picflow** from the notarized .dmg (not from Xcode)
3. **Check the logs** for:
   - Successful initialization
   - `canCheckForUpdates = true`
   - Sparkle Feed URL is correct
4. **Click "Check for Updates..."** in the menu
5. **Watch logs** for appcast loading
6. **Verify** update check completes (either "update found" or "no updates")

## Troubleshooting

If logs show problems, check these files:
- `Picflow/Info.plist` - Contains Sparkle configuration
- `~/.sparkle/private_key` - Used to sign releases
- `appcast.xml` - Update feed (should be at https://picflow.com/download/macos/appcast.xml)
- Release script: `scripts/release.sh`

## Support

If you're still having issues after reviewing the logs, include:
1. Complete log output from Console.app
2. Which build you're testing (Xcode vs notarized .dmg)
3. macOS version
4. App version (from logs)

