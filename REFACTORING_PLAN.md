# Upload Folder Refactoring Plan

## Current Structure Analysis

### Files:
1. **UploaderView.swift** - Main container (shown when gallery selected)
   - Contains tabs: Upload, Stream
   - Manages gallery menu (copy link, open, delete)
   - Coordinates status displays

2. **DropAreaView.swift** - Manual upload interface (drag & drop, file picker)

3. **LiveFolderView.swift** - Folder selection UI for streaming mode

4. **StreamingView.swift** - Contains `StreamCounterView` (decorative counter, appears unused)

5. **UploadStatusView.swift** - Status components:
   - `ManualUploadStatus` - For manual uploads & Capture One
   - `LiveFolderUploadStatus` - For live folder monitoring

6. **CaptureOneStatusView.swift** - Capture One integration status & controls

## Recommended Structure

### Naming Convention:
- **GalleryView** - Main container (renamed from UploaderView)
- **UploadTab** - Upload tab content (manual upload + Capture One)
- **StreamTab** - Stream tab content (folder monitoring)
- **Status Components** - Keep separate but clarify naming

### Proposed File Structure:

```
Picflow/Views/Gallery/
├── GalleryView.swift              # Main container (renamed from UploaderView)
│   └── GalleryMenuContent          # Gallery menu (copy link, open, delete)
│
└── Upload/                         # Upload-related components
    ├── UploadTabView.swift         # Upload tab content (NEW - combines DropArea + Capture One)
    │   ├── DropAreaView           # Manual upload interface
    │   └── CaptureOneStatusView   # Capture One integration
    │
    ├── StreamTabView.swift         # Stream tab content (NEW - combines LiveFolder + status)
    │   └── LiveFolderView         # Folder selection UI
    │
    ├── Status/
    │   ├── ManualUploadStatus.swift    # Status for manual/Capture One uploads
    │   ├── LiveFolderUploadStatus.swift # Status for live folder monitoring
    │   └── CaptureOneExportingStatus.swift # Capture One export status
    │
    └── Components/
        └── StreamingView.swift    # StreamCounterView (if still needed)
```

### Alternative: Keep Current Structure, Just Rename

If you prefer less restructuring:

```
Picflow/Views/Gallery/
├── GalleryView.swift              # Renamed from UploaderView.swift
│
└── Upload/                         # All upload-related views
    ├── DropAreaView.swift         # Manual upload interface
    ├── LiveFolderView.swift       # Folder selection for streaming
    ├── CaptureOneStatusView.swift # Capture One integration
    ├── UploadStatusView.swift     # Status components (ManualUploadStatus, LiveFolderUploadStatus)
    └── StreamingView.swift        # StreamCounterView (if needed)
```

## Recommended Changes

### Option 1: Minimal (Recommended)
1. Rename `UploaderView.swift` → `GalleryView.swift`
2. Rename enum `UploaderTab` → `GalleryTab`
3. Update `AppView.swift` to use `GalleryView`
4. Update `AppNavigationState.uploader` → `AppNavigationState.gallery` (optional)

### Option 2: Moderate Restructuring
1. Do Option 1
2. Create `UploadTabView.swift` that combines DropAreaView + CaptureOneStatusView
3. Create `StreamTabView.swift` that combines LiveFolderView + LiveFolderUploadStatus
4. Extract status components to separate files in `Status/` subfolder

### Option 3: Full Restructuring
1. Move `GalleryView.swift` to `Views/Gallery/` folder
2. Create tab view files (`UploadTabView.swift`, `StreamTabView.swift`)
3. Organize status components into `Status/` subfolder
4. Keep only reusable components in `Upload/` folder

## File Naming Conventions

- **View files**: `{Purpose}View.swift` (e.g., `GalleryView.swift`, `DropAreaView.swift`)
- **Status components**: `{Source}Status.swift` (e.g., `ManualUploadStatus.swift`, `LiveFolderUploadStatus.swift`)
- **Tab content**: `{Tab}TabView.swift` (e.g., `UploadTabView.swift`, `StreamTabView.swift`)
- **Menu components**: `{Context}MenuContent.swift` (e.g., `GalleryMenuContent.swift`)

## Questions to Consider

1. **StreamingView.swift**: Is `StreamCounterView` actually used? If not, can be removed.
2. **Status organization**: Should status components be in a `Status/` subfolder or kept flat?
3. **Folder location**: Should `GalleryView` live in `Views/Gallery/` or stay in `Views/Upload/`?

## Recommendation

**Start with Option 1 (Minimal)**:
- Rename `UploaderView` → `GalleryView`
- Rename `UploaderTab` → `GalleryTab`
- Update references in `AppView.swift`
- This is the least disruptive and aligns with the user's mental model

If needed later, we can do Option 2 (moderate restructuring) to better organize tab content.

