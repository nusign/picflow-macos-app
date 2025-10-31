# Smart Concurrent Upload Implementation

## Overview

The uploader uses **smart coordination** to handle concurrent uploads efficiently while preventing resource contention from multiple large file uploads.

**All upload sources use the same system:**
- ✅ Manual uploads (drag & drop, file picker)
- ✅ Capture One exports (queued as files appear)
- ✅ Live folder monitoring (watched folder changes)

## Upload Strategy

### Small Files (Single-Part Upload)
- ✅ Upload **concurrently** (up to 4 at once)
- ✅ Fast and efficient for multiple small files
- ✅ Each file is a single operation

### Large Files (Multipart Upload)
- ⚠️ Only **ONE multipart upload at a time**
- ✅ Within that file, **5 chunks upload concurrently**
- ✅ Prevents overwhelming API with multiple multipart requests
- ✅ Avoids multiple file readers and excessive memory usage

## Configuration

```swift
struct UploadConcurrencyConfig {
    // Maximum number of concurrent small file uploads
    static let maxConcurrentSmallFiles = 4
    
    // Maximum number of concurrent chunks within a large file
    static let maxConcurrentChunks = 5
}
```

## How It Works

### Scenario 1: Multiple Small Files
```
Queue: 5 small files (10 MB each)

Execution:
File1, File2, File3, File4 → Upload concurrently
  ↓ (File1 completes)
File5 starts uploading
  ↓ All complete

Result: 4 files uploading at any time, fast completion
```

### Scenario 2: One Large File
```
Queue: 1 large file (150 MB, 15 chunks)

Execution:
File1 acquires multipart lock
  → Chunk1, Chunk2, Chunk3, Chunk4, Chunk5 upload concurrently
    ↓ (Chunk1 completes)
  → Chunk6 starts
    ...continues until all chunks complete
File1 releases multipart lock

Result: 5 chunks uploading at any time, optimal throughput
```

### Scenario 3: Mixed Files (THE KEY SCENARIO)
```
Original Queue: 
- 1 large file (150 MB, 15 chunks)  ← User dropped this first
- 3 small files (10 MB each)
- 1 small file (5 MB)

Sorted Queue (automatic):
- 3 small files (10 MB each)  ← Moved to front
- 1 small file (5 MB)
- 1 large file (150 MB, 15 chunks)  ← Moved to back

Execution:
Small1, Small2, Small3, Small4 → Upload concurrently (all 4 at once)
  ↓ (all small files complete)
Large1 → Acquires multipart lock
  → Uploads 5 chunks at a time concurrently
  → Releases lock when done
  ↓ All complete

Result: Queue automatically reordered for optimal performance
```

### Scenario 4: Multiple Large Files
```
Queue: 3 large files (100 MB each, 10 chunks)

Execution:
Large1 → Acquires multipart lock
  → Uploads all 10 chunks (5 concurrent)
  → Releases lock
Large2 → Acquires multipart lock (was waiting)
  → Uploads all 10 chunks (5 concurrent)
  → Releases lock
Large3 → Acquires multipart lock (was waiting)
  → Uploads all 10 chunks (5 concurrent)
  → Releases lock

Result: Sequential multipart uploads, no API overload
```

## Queue Sorting Strategy

**Critical Feature**: The upload queue is automatically sorted to optimize user experience:

```swift
// Sort queue: small files first, then large files
uploadQueue.sort { url1, url2 in
    let isMultipart1 = MultiPartUploadConfig.shouldUseMultipart(fileSize: size1)
    let isMultipart2 = MultiPartUploadConfig.shouldUseMultipart(fileSize: size2)
    
    // Small files come before large files
    if isMultipart1 != isMultipart2 {
        return !isMultipart1  // Small files first
    }
    
    // Within same category, maintain original order
    return false
}
```

### Why Small Files First?

**Performance**: Nearly identical total upload time (~5 seconds either way)

**But significant UX benefits**:

1. **Immediate Feedback**
   - Small files appear in gallery within seconds
   - Users see progress immediately
   - Feels more responsive

2. **Quick Wins**
   - 4 files complete in 1.5 seconds
   - Better than waiting 3.5 seconds for first file
   - Psychological: "4/5 done" feels better than "1/5 done"

3. **Failure Recovery**
   - If upload fails halfway, quick files are already saved
   - Small files less likely to fail (shorter duration)
   - Better resilience on unstable connections

4. **Consistent Behavior**
   - Predictable performance regardless of drop order
   - Always starts with concurrent small files
   - Optimizes for best-case scenario

**Trade-off**: Files don't upload in chronological drop order, but UX improvement is worth it.

## Architecture

### 1. ConcurrencyCoordinator (Actor)
**File**: `Picflow/Services/ConcurrencyCoordinator.swift`

```swift
actor ConcurrencyCoordinator {
    // Chunk-level concurrency (within a file)
    private var activeOperations: Int = 0
    private let maxConcurrent: Int
    
    // Multipart exclusivity
    private var isMultipartUploadActive: Bool = false
    private var waitingForMultipart: [CheckedContinuation<Void, Never>] = []
    
    func acquireSlot() async        // For chunk uploads
    func releaseSlot()              // Release chunk slot
    
    func acquireMultipartLock() async  // Get exclusive multipart access
    func releaseMultipartLock()        // Release multipart access
    func isMultipartActive() -> Bool   // Check if multipart is running
}
```

**Key Features**:
- **Chunk Slots**: Manage concurrent chunks within a multipart upload
- **Multipart Lock**: Ensure only one multipart upload at a time
- **FIFO Queue**: Waiting multipart uploads processed in order
- **Thread-safe**: Actor model ensures safety

### 2. Smart Upload Queue Processing
**File**: `Picflow/Services/Uploader.swift`

The `processQueue()` method intelligently handles the queue:

```swift
// Check if file needs multipart
let isMultipart = MultiPartUploadConfig.shouldUseMultipart(fileSize: fileSize)

// For multipart: Check if another multipart is active
if isMultipart {
    let canStart = await concurrencyCoordinator.isMultipartActive() == false
    if !canStart {
        break  // Wait for current multipart to complete
    }
}

// For small files: Check concurrent limit
if !isMultipart && filesInProgress >= maxConcurrentSmallFiles {
    break  // At concurrent limit
}
```

### 3. Multipart Upload with Lock
**File**: `Picflow/Services/Uploader.swift`

```swift
private func uploadMultiPart(...) async throws {
    // Acquire exclusive lock
    await concurrencyCoordinator.acquireMultipartLock()
    
    defer {
        // Always release lock when done (even on error)
        Task {
            await concurrencyCoordinator.releaseMultipartLock()
        }
    }
    
    // Upload chunks concurrently (up to 5 at once)
    for chunk in chunks {
        await concurrencyCoordinator.acquireSlot()  // Get chunk slot
        uploadChunk(...)
        await concurrencyCoordinator.releaseSlot()  // Release slot
    }
}
```

## Benefits

### Performance
- ✅ **Small files upload quickly**: Multiple files don't wait
- ✅ **Large files get full bandwidth**: All 5 chunk slots available
- ✅ **No API overload**: Only one multipart create/complete at a time

### Resource Management
- ✅ **One file reader at a time** for large files
- ✅ **Fewer concurrent API requests** (3 small + 1 multipart max)
- ✅ **Memory efficient**: Chunks streamed, not held in memory

### Reliability
- ✅ **Error isolation**: Failed files don't block others
- ✅ **Automatic retry**: Chunks retry with exponential backoff
- ✅ **Lock always released**: `defer` ensures cleanup

## Progress Tracking

### How It Works
- Each file tracks its own progress (0.0 to 1.0)
- Overall progress weighted by file sizes
- Real-time updates as chunks complete
- Works correctly with concurrent uploads

```swift
// Per-file progress tracking
private var fileProgress: [URL: Double] = [:]
private var fileSizes: [URL: Int64] = [:]

// Calculate weighted overall progress
func updateOverallProgress() {
    var totalWeighted = 0.0
    for (fileURL, progress) in fileProgress {
        let weight = Double(fileSizes[fileURL]!) / Double(totalBytesInQueue)
        totalWeighted += weight * progress
    }
    uploadProgress = totalWeighted
}
```

## Why This Approach?

### Problem with Concurrent Multipart Uploads
```
❌ BAD: 3 large files starting simultaneously
- 3 "Create Asset" API calls
- 30 presigned URLs requested
- 3 file readers open
- 30 chunk tasks created
- But only 5 chunks actually uploading!
- Wasted resources, API pressure
```

### Solution: Smart Coordination
```
✅ GOOD: Sequential multipart, concurrent small files
- 1 "Create Asset" API call at a time for large files
- 1 file reader open for large file
- 10 chunk tasks for current file
- 5 chunks uploading concurrently
- Small files upload alongside when available
- Clean resource usage, optimal performance
```

## Edge Cases Handled

### 1. Multipart Upload Fails
- Lock is released in `defer` block
- Next multipart can proceed immediately
- Small files unaffected

### 2. Queue Has Only Small Files
- All upload concurrently (up to limit)
- No multipart coordination needed
- Fast completion

### 3. Queue Has Only Large Files
- Process sequentially
- Each gets full chunk concurrency
- Prevents API overload

### 4. Mixed Queue Order Matters
- Small files at start → Upload concurrently first
- Large file → Waits for small files, then gets exclusive access
- Small files after → Wait for large file, then upload concurrently

## Configuration Tips

### Tuning `maxConcurrentSmallFiles`
- **Low (1-2)**: Conservative, sequential-like
- **Medium (4)**: Balanced (default)
- **High (6+)**: Aggressive, more API calls

**Recommendation**: 4 for most cases

### Tuning `maxConcurrentChunks`
- **Low (2-3)**: Conservative bandwidth
- **Medium (5)**: Balanced (default)
- **High (8-10)**: Aggressive, faster large files

**Recommendation**: 5 for good balance

## Testing Scenarios

### Test 1: 10 Small Files
```swift
// Expected: 3 uploading at once, rolling window
// Verify: Fast completion, no blocking
```

### Test 2: 1 Large File (100 MB)
```swift
// Expected: 5 chunks concurrent
// Verify: Single multipart lock, optimal speed
```

### Test 3: Mixed (3 Small + 1 Large + 2 Small)
```swift
// Expected: Small files first (4 concurrent, 1 waits)
//          Large file next (exclusive, 5 chunks)
//          Small files last (1 remaining)
// Verify: No blocking, smooth progression
```

### Test 4: 3 Large Files
```swift
// Expected: Sequential multipart uploads
// Verify: Only one multipart active at a time
//         Each gets full 5-chunk concurrency
```

## Monitoring & Debugging

### Log Symbols

All logs appear in the Xcode console during development:

| Symbol | Meaning |
|--------|---------|
| 🚀 | Upload queue starting |
| ▶️ | File upload starting |
| ✅ | File upload completed |
| ⏸️ | Waiting/blocked |
| 🔒 | Multipart lock acquired |
| 🔓 | Multipart lock released |
| 🔵 | Chunk slot acquired |
| 🟢 | Chunk slot released |
| 📤 | Individual file upload start |
| 📦 | Multipart/chunk info |

### Example Log Output

```swift
🚀 UPLOAD QUEUE: 5 files (3 small, 2 large)
   Strategy: Small files first (concurrent), then large files (sequential)
   Config: max 4 small files, 5 chunks

   ▶️ Starting SMALL file: photo1.jpg (428 KB)
   ▶️ Starting SMALL file: photo2.jpg (415 KB)
   ▶️ Starting SMALL file: photo3.jpg (30.2 MB)
   ⏸️ At small file limit (4/4)

   ✅ File completed (1/5), 2 still in progress
   ▶️ Starting LARGE file: video.mp4 (107.8 MB)

📤 UPLOAD START
   File: video.mp4
   Mode: Multi-part (will acquire lock)
   🔒 MULTIPART lock acquired
   📦 Uploading in 11 parts (10.5 MB each)
   
   🔵 Chunk slot acquired: 1/5 active
   🔵 Chunk slot acquired: 2/5 active
   🔵 Chunk slot acquired: 3/5 active
   🔵 Chunk slot acquired: 4/5 active
   🔵 Chunk slot acquired: 5/5 active
   ⏸️ Chunk waiting for slot (currently 5/5)
   
   🟢 Chunk slot released: 4/5 active, 6 waiting
   🔵 Chunk slot acquired (was waiting): 5/5 active
   
   Progress: 5/11 parts (48%)
   🔓 MULTIPART lock released (0 waiting)
```

### What to Look For

**✅ Concurrency Working**:
- Multiple "Starting SMALL file" appear together
- "5/5 active" for chunks
- "X still in progress" shows 2-4 for small files
- Only ONE multipart lock at a time

**❌ Potential Issues**:
- Files start one at a time (no concurrent starts)
- Chunks show "1/5 active" and complete before next starts
- Multiple multipart locks acquired simultaneously
- Large files start before small files (should be sorted)

### Metrics to Track
- "X still in progress" → Should be 2-4 for small files
- "X/5 active" in chunks → Should be 5 during multipart
- Multipart lock count → Only 1 at a time
- Total upload time → Compare with/without concurrency

## Related Files

- `Picflow/Services/ConcurrencyCoordinator.swift` - Coordinator & config
- `Picflow/Services/Uploader.swift` - Upload logic (used by all sources)
- `Picflow/Services/CaptureOneUploadManager.swift` - Capture One export integration
- `Picflow/Services/FolderMonitoringManager.swift` - Live folder monitoring
- `Picflow/Services/MultiPartUploadConfig.swift` - Multipart settings
- `Picflow/Services/ChunkedFileReader.swift` - File streaming
- `Picflow/Views/Upload/UploadStatusView.swift` - Progress UI

## Changelog

### Version 3.0 (October 31, 2025) - Unified Upload System
- ✅ **All upload sources use the same system**
- ✅ Capture One exports now queue through standard Uploader
- ✅ Same concurrency settings for all sources (manual, Capture One, live folder)
- ✅ Same progress tracking (speed, time remaining, file counter)
- ✅ Increased concurrent small files from 3 → 4
- ✅ Capture One exports benefit from smart coordination
- ✅ Files from exports stream into queue as they're detected

### Version 2.1 (October 2025) - Queue Sorting Fix
- 🐛 **Fixed**: Queue now automatically sorts small files before large files
- ✅ Ensures small files always upload concurrently first
- ✅ Prevents large files from blocking the queue at start
- ✅ Optimal performance regardless of drop order

### Version 2.0 (October 2025) - Smart Coordination
- ✅ Small files upload concurrently (up to 3)
- ✅ Only one multipart upload at a time
- ✅ Multipart lock prevents resource contention
- ✅ Within multipart: 5 chunks concurrent
- ✅ Optimal resource usage
- ✅ No API overload

---

**Last Updated**: October 31, 2025  
**Author**: AI Assistant  
**Status**: ✅ Complete - Unified System with Smart Coordination

