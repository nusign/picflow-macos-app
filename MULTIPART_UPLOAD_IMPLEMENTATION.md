# Multi-Part Upload Implementation

## Overview

Implemented production-ready multi-part upload support for large files (>40MB), with automatic fallback to single-part upload for smaller files.

## Architecture

### Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    File Upload Request                      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│         Check File Size (threshold: 40MB)                   │
└─────────────────────────────────────────────────────────────┘
                            ↓
              ┌─────────────┴─────────────┐
              ↓                           ↓
    ┌──────────────────┐        ┌──────────────────┐
    │ Single-Part      │        │ Multi-Part       │
    │ (< 40MB)         │        │ (≥ 40MB)         │
    │                  │        │                  │
    │ • Load to memory │        │ • Stream from    │
    │ • POST with form │        │   disk           │
    │   data           │        │ • PUT binary     │
    │ • Single S3 URL  │        │   chunks         │
    └──────────────────┘        │ • 3 concurrent   │
                                │   uploads        │
                                │ • Collect ETags  │
                                │ • Complete API   │
                                └──────────────────┘
```

## Key Components

### 1. **MultiPartUploadConfig** (`Services/MultiPartUploadConfig.swift`)

Configuration and utilities for multi-part uploads:

```swift
// Configurable threshold (default: 40MB)
static let multipartThresholdMB: Int64 = 40

// Possible chunk sizes (backend-defined)
static let possibleChunkSizes = [10MB, 100MB, 250MB]

// Performance tuning
static let maxConcurrentUploads = 3
static let maxRetryAttempts = 3
```

**Chunk Size Calculator:**
- Reverse-engineers backend's chunk size from file size + part count
- Algorithm: `Math.floor(fileSize / chunkSize) + 1`
- Matches backend's TypeScript implementation exactly

### 2. **ChunkedFileReader** (`Services/ChunkedFileReader.swift`)

Memory-efficient file streaming:
- Reads file in chunks from disk (never loads entire file)
- Supports random access by chunk index
- Automatic cleanup on deinit
- Prevents memory pressure for large files

### 3. **Updated Models**

**CreateAssetRequest** (`Models/CreateAssetRequest.swift`):
```swift
enum UploadType: String {
    case post = "post"         // Single-part
    case multipart = "multipart"  // Multi-part
}
```

**CreateAssetResponse** (`Models/CreateAssetResponse.swift`):
```swift
struct VersionData {
    // Single-part fields
    let uploadUrl: String?
    let amzFields: [String: String]?
    
    // Multi-part fields
    let uploadUrls: [String]?
    let uploadId: String?
    let originalKey: String?
    
    var isMultiPart: Bool { ... }
}
```

**CompleteMultipartUploadRequest** (`Models/CompleteMultipartUploadRequest.swift`):
```swift
struct CompleteMultipartUploadRequest {
    let key: String
    let uploadId: String
    let parts: [Part]  // ETags + part numbers
}
```

### 4. **Uploader Service** (`Services/Uploader.swift`)

Enhanced upload logic:

**Detection & Routing:**
```swift
let uploadType = MultiPartUploadConfig.shouldUseMultipart(fileSize) 
    ? .multipart 
    : .post

if response.versionData.isMultiPart {
    try await uploadMultiPart(...)
} else {
    try await uploadSinglePart(...)
}
```

**Multi-Part Upload Process:**
1. **Initialize**: Calculate chunk size from backend response
2. **Stream**: Open file handle, read chunks on-demand
3. **Upload**: 3 concurrent chunk uploads with exponential backoff retry
4. **Collect**: Capture ETag from each chunk response
5. **Complete**: POST to `/v1/multipart_uploads/complete` with all ETags

**Error Handling:**
- Per-chunk retry (3 attempts with 2s, 4s, 8s delays)
- Comprehensive error types (missing ETag, invalid chunk, etc.)
- Sentry integration for production monitoring
- Analytics tracking for upload metrics

## Upload Flow Examples

### Example 1: Small File (10MB)
```
1. File size: 10MB
2. Threshold check: 10MB < 40MB → Single-part
3. POST /v1/assets (upload_type: "post")
4. Backend returns: { uploadUrl, amzFields }
5. POST to S3 with multipart/form-data
6. ✅ Complete
```

### Example 2: Large File (500MB)
```
1. File size: 500MB
2. Threshold check: 500MB > 40MB → Multi-part
3. POST /v1/assets (upload_type: "multipart")
4. Backend returns: { uploadUrls: [50 URLs], uploadId, originalKey }
5. Calculate chunk size: 500MB / 50 = 10MB ✓
6. Upload 50 chunks (3 concurrent):
   - PUT chunk 1 → ETag: "abc123..."
   - PUT chunk 2 → ETag: "def456..."
   - ...
7. POST /v1/multipart_uploads/complete
   Body: { key, upload_id, parts: [{ETag, PartNumber}] }
8. ✅ Complete
```

## Configuration Options

### Adjustable Parameters

**File Size Threshold:**
```swift
// In MultiPartUploadConfig.swift
static let multipartThresholdMB: Int64 = 40  // Change this value
```

**Concurrency:**
```swift
static let maxConcurrentUploads = 3  // 1-5 recommended
```

**Retry Strategy:**
```swift
static let maxRetryAttempts = 3
static func retryDelay(for attempt: Int) -> TimeInterval {
    return pow(2.0, Double(attempt))  // Exponential backoff
}
```

## Performance Characteristics

### Memory Usage
- **Single-part**: Full file loaded into memory
- **Multi-part**: Only 3 × chunk_size in memory (max ~30MB for 10MB chunks)

### Upload Speed
- **Concurrency**: 3 parallel chunk uploads
- **Retry**: Automatic retry without restarting entire upload
- **Progress**: Granular progress updates per chunk

### Network Resilience
- Chunk-level retry with exponential backoff
- Failed chunks don't impact successfully uploaded chunks
- Future-ready for pause/resume functionality

## Future Enhancements (Phase 2)

### 1. Pause/Resume Support
```swift
class UploadTask {
    @Published var state: State  // .paused, .uploading, .cancelled
    var uploadedChunks: Set<Int>  // Track completed chunks
    
    func pause() { ... }
    func resume() { ... }  // Skip already uploaded chunks
}
```

### 2. Persistent Upload State
- Save progress to disk/UserDefaults
- Resume after app restart
- Handle file changes (hash verification)

### 3. Adaptive Concurrency
- Adjust concurrent uploads based on network speed
- Throttle on slow connections
- Increase on fast connections

### 4. Background Uploads
- Continue uploads when app is backgrounded
- Use URLSession background configuration
- Post notifications on completion

## Testing Strategy

### Unit Tests
- [x] Chunk size calculator with various file sizes
  - 10MB, 100MB, 250MB, 500MB, 1GB, 5GB
- [ ] ChunkedFileReader edge cases
  - Last chunk smaller than chunk size
  - Single chunk files
  - Exact chunk size boundaries

### Integration Tests
- [ ] End-to-end upload flow
  - 5MB file → single-part
  - 50MB file → multi-part
  - 500MB file → multi-part
- [ ] Network failure scenarios
  - Mid-upload disconnect
  - Single chunk failure
  - Complete endpoint failure

### Load Tests
- [ ] Multiple concurrent file uploads
- [ ] Very large files (5GB+)
- [ ] Memory pressure monitoring

## Known Limitations

1. **No pause/resume**: Canceling an upload requires restarting from scratch
2. **No background uploads**: Uploads stop when app is quit
3. **Fixed concurrency**: Doesn't adapt to network conditions
4. **No progress persistence**: Progress lost on app restart

## Backend API Requirements

### Create Asset (Multipart)
```
POST /v1/assets
{
  "gallery": "gal_xxx",
  "section": "sec_xxx",  // Optional
  "asset_name": "file.zip",
  "content_length": 476764001,
  "upload_type": "multipart",  // or "post"
  "accelerated": true
}

Response:
{
  "versionData": {
    "uploadUrls": ["https://s3...?partNumber=1", ...],
    "uploadId": "xxx",
    "originalKey": "non_preview/..."
  }
}
```

### Complete Multipart Upload
```
POST /v1/multipart_uploads/complete
{
  "key": "non_preview/zip/xxx/xxx-original.zip",
  "upload_id": "xxx",
  "parts": [
    { "ETag": "abc123", "PartNumber": 1 },
    { "ETag": "def456", "PartNumber": 2 },
    ...
  ]
}

Response:
{
  "success": true,
  "message": "Upload completed"
}
```

## Error Handling

### New Error Cases
```swift
enum UploadError {
    case invalidChunkIndex
    case chunkReadFailed
    case missingETag
    case multipartCompletionFailed
    case missingUploadId
    case missingOriginalKey
}
```

### Retry Logic
- Chunk upload failures trigger exponential backoff retry
- Up to 3 attempts per chunk
- Other chunks continue uploading
- Entire upload fails only if a chunk fails all retries

## Analytics & Monitoring

### Tracked Events
- `upload_started`: File count, gallery ID
- `file_uploaded`: File name, size, upload type
- `upload_completed`: Total size, duration
- `upload_failed`: Error details, chunk index

### Sentry Integration
- Breadcrumbs for each major step
- Error capture with full context
- Performance monitoring for chunk uploads

## Migration Notes

### Breaking Changes
**None** - Fully backward compatible with existing uploads.

### Opt-in Migration
Files < 40MB continue using single-part upload (existing behavior).
Files ≥ 40MB automatically use multi-part upload (new behavior).

### Rollback Plan
1. Set `multipartThresholdMB = 999999` (effectively disable)
2. Or keep backend `upload_type: "post"` for all requests

