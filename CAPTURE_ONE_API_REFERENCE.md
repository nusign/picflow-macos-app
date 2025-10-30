# Capture One AppleScript Capabilities

## Overview
Capture One has extensive AppleScript support defined in `CaptureOne.sdef`. This document outlines all the key capabilities available for automation.

## ⚠️ Critical Implementation Notes

### App Sandbox Requirement
**AppleScript automation from a sandboxed macOS app DOES NOT WORK**, even with proper entitlements. You must:
- Set `com.apple.security.app-sandbox` to `false` in entitlements
- This means **Mac App Store distribution is not possible**
- Direct distribution only (Sparkle, DMG, etc.)

### Execution Method
**Use `osascript` subprocess, NOT `NSAppleScript`**:
- `NSAppleScript` inherits sandbox restrictions and fails with error -600
- Execute via `/usr/bin/osascript` using `Process` class
- This bypasses NSAppleScript's limitations

### Document Access Pattern
**Variants are NOT accessible at application level**:
- ❌ Wrong: `tell application "Capture One" to variants`
- ✅ Correct: `tell application "Capture One" to tell document 1 to variants`
- Error -2753 ("variable not defined") indicates incorrect access pattern

### Recipe Output Location Properties

**⚠️ CRITICAL: Set Document `output` Property FIRST (Required for Catalogs)**

Capture One has TWO levels of output location:

1. **Document-level `output` property** - The catalog's default output folder (**REQUIRED for catalogs**)
2. **Recipe-level `root folder location`** - Where individual recipes export to

#### Why This Matters
- **Sessions**: Have `output` implicitly set (to session folder), so recipes work immediately
- **Catalogs**: Start with `output` UNSET, causing all exports to fail with error -43 until it's set
- **Error message**: "An output folder has not yet been chosen for this catalog"

#### The Solution: Set BOTH Properties

✅ **CORRECT** (works for both sessions and catalogs):
```applescript
tell application "Capture One"
    tell front document
        -- STEP 1: Set document-level output (catalog requirement)
        set output to POSIX file "/Users/username/exports" as alias
        
        -- STEP 2: Create recipe with custom output location
        set newRecipe to make new recipe with properties {name:"My Recipe"}
        set exportPath to POSIX file "/Users/username/exports" as alias
        
        -- Set recipe output (ORDER MATTERS!)
        tell newRecipe
            set root folder location to exportPath  -- Set location FIRST
            set root folder type to custom location  -- Then set type
        end tell
        
        -- Optional: Set format
        set output format of newRecipe to JPEG
        set JPEG quality of newRecipe to 90
    end tell
end tell
```

**Critical Points**:
1. **Set document `output` first** - Required for catalogs, harmless for sessions
2. **Convert to alias**: Path MUST be converted with `POSIX file "/path" as alias`
3. **Order matters**: Set `root folder location` BEFORE `root folder type`
4. **Both paths can be the same** - Document `output` and recipe `root folder location`
5. Error -43 "Invalid process output folder" = document `output` not set
6. Setting type before location causes it to revert to "Session Default"

---

## ✅ Getting Selected Assets

### Count Selected Variants

**Working Format** (tested and confirmed ✅):
```applescript
tell application "Capture One" to tell document 1 to return (count of (variants whose selected is true))
```

**Alternative Multi-line Format**:
```applescript
tell application "Capture One"
    tell document 1
        set selectedVariants to (get variants whose selected is true)
        set selectedCount to count of selectedVariants
        return selectedCount
    end tell
end tell
```

**Key Points**:
- Use "Capture One" (not version-specific like "Capture One 16")
- MUST use `tell document 1` to access variants
- `front document` can also work but `document 1` is more reliable

### Get Selected Variant Properties
Each selected variant provides access to:

#### File Information
- `name` - The name of the parent image (read-only)
- `id` - Unique identifier of the variant (read-only)
- `file` - The file of the original RAW file (read-only)
- `parent image` - Reference to the parent image object (read-only)

#### Selection & Visibility
- **`selected`** - Boolean indicating if variant is selected (read-only)
- `visible` - Is variant visible in current collection filter (read-only)
- `pick` - Is this the picked variant (read/write)
- `position` - Index relative to parent image's variants (read-only)

#### Metadata
- `color tag` - Integer color tag value
- `rating` - Integer rating value
- `contact creator` - Creator name
- `content headline` - Headline text
- `content description` - Description text
- And ~40+ other IPTC metadata fields

#### Image Properties
- `crop` - Crop rectangle {centerX, centerY, width, height}
- `crop width`, `crop height` - Dimensions in pixels
- `crop aspect ratio` - Current aspect ratio name
- `latitude`, `longitude`, `altitude` - GPS coordinates (read-only)
- `exposure meter` - Center-weighted exposure measure (±2 EV)

#### Adjustments
- `adjustments` - Full adjustment settings object
- `styles` - List of applied style/preset names
- `color tag`, `rating` - Quick access to common properties

---

## 📁 Working with Images

### Image Class Properties
```applescript
tell application "Capture One 16"
    tell front document
        set imgs to every image
        repeat with img in imgs
            -- Access properties:
            get path of img -- Full path to original file
            get name of img -- File name
            get dimensions of img -- {width, height}
            get file size of img -- Size in bytes
            get extension of img -- File type (uppercase)
            get EXIF capture date of img
            get EXIF camera make of img
            get EXIF camera model of img
            get EXIF ISO of img
            -- ... and more EXIF data
        end repeat
    end tell
end tell
```

---

## 🎯 Key Commands Available

### Selection & Navigation
- `select` - Add variants to selection
- `deselect` - Remove variants from selection

### Processing & Export
- **`process`** - Process a variant with a specific recipe
  ```applescript
  process theVariant recipe "My Recipe Name"
  ```
  - Returns batch job identifier or error message
  - Can process single variant or list of variants
  - Optional recipe parameter (uses current recipe if omitted)

### Adjustments
- `copy adjustments` - Copy variant adjustments to clipboard
- `apply adjustments` - Apply adjustments from clipboard
- `reset adjustments` - Reset adjustments to default
- `autoadjust` - Automatically adjust settings

### Image Manipulation
- `rotate left` - Rotate 90° left
- `rotate right` - Rotate 90° right
- `autocrop` - Auto crop variant (CH only)
- `maximum crop` - Determine maximum crop

### Variant Management
- `add variant` - Create new variant
- `clone variant` - Clone existing variant
- `promote` - Promote variant among clones
- `demote` - Demote variant among clones

### Lens & Color
- `create LCC` - Create lens cast correction from variant
- `apply LCC` - Apply lens cast correction to variants
- `pick normalize` - Set normalize target color from point
- `apply normalize` - Apply normalization to point

### Metadata
- `reload metadata` - Reload from source file
- `sync metadata` - Sync metadata back to source file
- `apply keyword` - Apply existing keyword to variants

### Document Operations
- `import` - Perform image import
- `export originals` - Export original images
- `batch rename` - Rename according to batch settings
- `synchronize` - Sync folder collection with disk

### Capture (PRO/Tethering)
- `capture` - Trigger camera capture
- `begin live view` - Start Live View
- `end live view` - Stop Live View
- `select camera` - Select camera by name/ID

---

## 📚 Main Classes

### Application
- `primary variant` - The primary selected variant (read-only)
- `app version` - Version string (read-only)
- `front document` - Current document

### Document
- `current collection` - Active collection
- `current recipe` - Currently selected recipe
- `variants` - All variants in current collection
- `images` - All images in current collection
- `collections` - Available collections
- `recipes` - Process recipes

### Variant (Most Important for Selection)
Full variant class with:
- Selection state (`selected`)
- File reference (`file`, `parent image`)
- Metadata (rating, color tag, IPTC fields)
- Adjustments and styles
- Crop information
- GPS coordinates

### Collection
- Organizational collections (albums, folders, smart albums)
- Can contain variants and images

### Recipe
- Process recipe settings
- Can be referenced by name for `process` command
- **Can READ all properties**: `root folder location`, `output format`, `JPEG quality`, `sharpening`, `watermark`, etc.
- **Cannot UPDATE properties directly**: Must delete and recreate recipe to change settings

---

## 🔄 Typical Workflows

### 1. Get Selected Images and Export Them
```applescript
tell application "Capture One 16"
    tell front document
        -- Get selected variants
        set selectedVariants to (get variants whose selected is true)
        
        -- Process each with a specific recipe
        repeat with v in selectedVariants
            set jobID to process v recipe "Export for Web"
        end repeat
    end tell
end tell
```

### 2. Get File Paths of Selected Images
```applescript
tell application "Capture One 16"
    tell front document
        set selectedVariants to (get variants whose selected is true)
        set filePaths to {}
        
        repeat with v in selectedVariants
            set parentImg to parent image of v
            set imgFile to file of parentImg
            set end of filePaths to POSIX path of imgFile
        end repeat
        
        return filePaths
    end tell
end tell
```

### 3. Get Metadata from Selection
```applescript
tell application "Capture One 16"
    tell front document
        set selectedVariants to (get variants whose selected is true)
        
        repeat with v in selectedVariants
            set variantRating to rating of v
            set variantTag to color tag of v
            set variantName to name of v
            set variantCrop to crop of v
            -- Access any metadata field...
        end repeat
    end tell
end tell
```

### 4. Apply Adjustments to Selection
```applescript
tell application "Capture One 16"
    tell front document
        -- Copy from primary variant
        set primaryV to primary variant of application "Capture One 16"
        copy adjustments primaryV
        
        -- Apply to all selected
        set selectedVariants to (get variants whose selected is true)
        repeat with v in selectedVariants
            apply adjustments v
        end repeat
    end tell
end tell
```

---

## 🎨 What You Can Do

### ✅ YES - Fully Supported
1. **Get selection count** - `count of (variants whose selected is true)`
2. **Get selected file paths** - Via `file` property of `parent image`
3. **Read all metadata** - Rating, color tag, IPTC, EXIF, GPS
4. **Process/Export selected images** - `process` command with recipe
5. **Apply adjustments** - Copy/paste adjustments between variants
6. **Rotate images** - 90° rotations
7. **Read crop information** - Full crop data available
8. **Trigger capture** - PRO version tethering support
9. **Manage collections** - Access and navigate collections
10. **Read EXIF data** - Camera, lens, settings from parent image

### ⚠️ LIMITED
1. **Real-time selection monitoring** - Must poll, no event notifications
2. **Recipe property updates** - Can READ all recipe properties including `root folder location`, but must delete and recreate to change settings (no direct property updates)

### ❌ NO - Not Available
1. **Direct file export with custom path** - Must use recipes (but can programmatically create/configure recipes)
2. **Event-based triggers** - No "on selection changed" events
3. **Undo/Redo control** - Not exposed via AppleScript

---

## 🚀 Integration Opportunities for Picflow

### Phase 2: Selection Reading
1. **Monitor selection changes** - Poll every 1-2 seconds when Capture One is active
2. **Display count in UI** - "X images selected in Capture One"
3. **Show file paths** - Preview what will be exported

### Phase 3: Export Automation
1. **Create dedicated export recipe** in Capture One (one-time setup)
   - Name: "Picflow Upload"
   - Format: JPEG/TIFF as needed
   - Destination: Temp folder
   - Quality settings
   
2. **Trigger export via AppleScript**
   ```applescript
   tell application "Capture One"
       tell document 1
           set selectedVariants to (get variants whose selected is true)
           repeat with v in selectedVariants
               process v recipe "Picflow Upload"
           end repeat
       end tell
   end tell
   ```
   
   **Note**: Must use `tell document 1` (or `front document`) to access variants

3. **Monitor export completion**
   - Watch temp folder for new files
   - Match by timestamp/naming pattern
   - Auto-upload when export completes

### Phase 4: Smart Integration
1. **Read metadata before upload**
   - Get rating/color tag for filtering
   - Extract IPTC data for asset metadata
   - Use GPS coordinates if available

2. **Batch operations**
   - Select in Capture One → Click "Upload" in Picflow → Done
   - No manual export step needed

---

## 📝 Notes

### Version Compatibility
- This documentation is for **Capture One 16** (`com.captureone.captureone16`)
- Most commands work across versions 15-23
- Always check `app version` property at runtime

### Performance
- AppleScript calls via osascript subprocess are synchronous but can be wrapped in Swift async
- Large selections may take time to process
- Simple selection count query is very fast (~50-100ms)
- Reading detailed metadata for many variants will be slower
- Recommend polling no faster than every 1-2 seconds

### Permissions Required
For AppleScript/JXA integration:
- **App Sandbox**: MUST be disabled (`com.apple.security.app-sandbox` = `false`)
- **Apple Events entitlement**: `com.apple.security.automation.apple-events` = `true`
- **NSAppleEventsUsageDescription**: User-facing permission text in Info.plist
- **User Approval**: macOS prompts user on first access, permission stored after approval
- **System Settings**: After approval, app appears in Privacy & Security → Automation

---

## 🎯 Implementation Status

### ✅ Completed
1. ~~Create Swift wrapper for AppleScript bridge~~ → **Done** (CaptureOneScriptBridge.swift)
2. ~~Implement selection monitoring~~ → **Done** (CaptureOneMonitor.swift)
3. ~~Handle permissions gracefully~~ → **Done** (UI prompt with "Grant Permission" button)

### 🔄 Next Steps
1. **Add detailed variant data** - Expand script to read file paths, EXIF, metadata
2. **Build export trigger** with recipe selection
3. **Add progress feedback** during export
4. **Integrate with Picflow upload pipeline**

## Common Error Codes

### Error -600: "Application isn't running"
**Meaning**: AppleScript can't communicate with the target app  
**Common Causes**:
- App sandbox is enabled (must be disabled)
- Using NSAppleScript instead of osascript subprocess
- Trying to access variants without `tell document 1`

### Error -1728: "Can't get [object]"
**Meaning**: Object doesn't exist or isn't accessible  
**Solution**: Check document is open, verify object path

### Error -2753: "Variable not defined"
**Meaning**: Trying to access variable in wrong scope  
**Solution**: Use `tell document 1` to access variants

### Error -1743: "No user interaction allowed"
**Meaning**: Operation requires user permission  
**Solution**: Ensure automation permission is granted

---

**This is a very comprehensive automation system** - Capture One has exposed nearly everything we need! 🚀

The main challenge is **not the AppleScript API** (which is excellent), but rather **macOS sandbox restrictions** which require disabling sandboxing for automation to work.

