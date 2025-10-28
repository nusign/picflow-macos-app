# Analytics Integration

## Overview

Picflow uses **Customer.io CDP** for user analytics and event tracking via direct HTTP API calls. The implementation uses a provider-agnostic `AnalyticsManager` to enable easy switching between analytics providers if needed.

## Architecture Decision

### Why Direct HTTP API?

After evaluating multiple approaches, we chose direct HTTP API calls:

**❌ Rejected Approaches:**
1. **Customer.io iOS SDK** - Not compatible with macOS (iOS-only platform declaration)
2. **Segment SDK** - Events weren't reaching Customer.io (compatibility issues with HTTP API source)

**✅ Final Solution: Direct HTTP API**
- Simple, reliable HTTP calls
- Works immediately (same as terminal tests)
- Full visibility and control
- Retry logic with exponential backoff (3 attempts: 1s, 2s, 4s)
- **No dependencies required** - uses native URLSession

## Configuration

### Environment Variables

Located in: `Config/Environment.swift`

```swift
// Development
customerIOCdpApiKey: "de4da9a43b8f30a56d86"
customerIOCdpBaseURL: "https://cdp.picflow.com/v1"

// Production
customerIOCdpApiKey: "05498e8c1c5a1702938c"
customerIOCdpBaseURL: "https://cdp.picflow.com/v1"
```

**Note:** Both environments use the same custom domain (`cdp.picflow.com`) which is a CNAME to Customer.io's EU region (`cdp-eu.customer.io`).

### Customer.io Setup

**Source Type:** HTTP API Source (not JavaScript or iOS SDK)

**Endpoints Used:**
- `POST /v1/identify` - User identification with traits
- `POST /v1/track` - Event tracking with properties

**Authentication:** HTTP Basic Auth with writeKey as username (no password)

## Implementation

### AnalyticsManager

**Location:** `Services/AnalyticsManager.swift`

**Design Principles:**
- Provider-agnostic interface (can switch from Customer.io to Mixpanel, Amplitude, etc.)
- Singleton pattern (`AnalyticsManager.shared`)
- MainActor for thread safety
- Comprehensive error handling and logging

**Key Features:**
- ✅ Direct HTTP calls for reliability
- ✅ Retry logic with exponential backoff (3 attempts)
- ✅ Smart error handling (retries server errors, not client errors)
- ✅ 30-second timeout per request
- ✅ Detailed console logging for debugging

### Integration Points

#### 1. App Initialization (`PicflowApp.swift`)
```swift
Task { @MainActor in
    AnalyticsManager.shared.initialize()
}
```

#### 2. User Authentication (`Authenticator.swift`)
```swift
// On login
AnalyticsManager.shared.identifyUser(profile: profile, tenant: tenant)
AnalyticsManager.shared.trackLogin(method: "oauth")

// On logout
AnalyticsManager.shared.trackLogout()
AnalyticsManager.shared.clearIdentification()
```

#### 3. Workspace Selection (`Authenticator.swift`)
```swift
AnalyticsManager.shared.trackWorkspaceSelected(tenant: tenant)
```

#### 4. Gallery Selection (`GallerySelectionView.swift`)
```swift
AnalyticsManager.shared.trackGallerySelected(gallery: gallery)
```

#### 5. File Uploads (`Uploader.swift`)
```swift
// Upload lifecycle
AnalyticsManager.shared.trackUploadStarted(fileCount: count, galleryId: id)
AnalyticsManager.shared.trackFileUploaded(fileName: name, fileSize: size, galleryId: id)
AnalyticsManager.shared.trackUploadCompleted(fileCount: count, totalSize: size, duration: time, galleryId: id)
AnalyticsManager.shared.trackUploadFailed(fileName: name, error: message, galleryId: id)
```

## Events Tracked

### User Events
- `user_logged_in` - User authentication (properties: `method`, `platform`)
- `user_logged_out` - User logout (properties: `platform`)

### Workspace Events
- `workspace_selected` - Tenant/workspace selection (properties: `tenant_id`, `tenant_name`, `tenant_path`)

### Gallery Events
- `gallery_selected` - Gallery selection (properties: `gallery_id`, `gallery_name`, `gallery_display_name`)

### Upload Events
- `upload_started` - Upload initiated (properties: `file_count`, `gallery_id`)
- `file_uploaded` - Individual file uploaded (properties: `file_name`, `file_size`, `gallery_id`)
- `upload_completed` - All uploads finished (properties: `file_count`, `total_size`, `duration_seconds`, `average_speed_mbps`, `gallery_id`)
- `upload_failed` - Upload error (properties: `error`, `file_name`, `gallery_id`)

## User Identification

Users are identified by **email address** with these traits:
- `id` - User ID (e.g., usr_PVE7Kpt21c98J5Tx)
- `email` - User's email (also used as userId)
- `first_name` - First name
- `last_name` - Last name
- `name` - Full name
- `avatar_url` - Profile picture URL (optional)
- `tenant_id` - Current workspace ID (optional)
- `tenant_name` - Current workspace name (optional)
- `tenant_path` - Current workspace path (optional)

## Retry Logic

**Strategy:** Exponential backoff with 3 attempts

**Retry Delays:**
- Attempt 1 → Attempt 2: 1 second
- Attempt 2 → Attempt 3: 2 seconds
- Total max time: ~3 seconds

**Retry Conditions:**
- ✅ **Network errors** (timeout, no connection)
- ✅ **Server errors** (5xx status codes)
- ❌ **Client errors** (4xx status codes) - No retry

**Success Criteria:**
- HTTP 200 status code
- `{"success": true}` response

## Console Logging

### Successful Request (First Attempt)
```
📤 Sending track event: user_logged_in for user: user@example.com
🌐 Sending user_logged_in to: https://cdp.picflow.com/v1/track
   Payload: {...}
✅ user_logged_in - HTTP 200 - {"success":true}
```

### Successful Request (After Retry)
```
⚠️ user_logged_in - Attempt 1/3 - Network error: Connection timeout
   ⏳ Retrying in 1.0s...
✅ user_logged_in - HTTP 200 (succeeded on attempt 2) - {"success":true}
```

### Failed Request
```
⚠️ user_logged_in - Attempt 1/3 - HTTP 503: Service Unavailable
   ⏳ Retrying in 1.0s...
⚠️ user_logged_in - Attempt 2/3 - HTTP 503: Service Unavailable
   ⏳ Retrying in 2.0s...
⚠️ user_logged_in - Attempt 3/3 - HTTP 503: Service Unavailable
❌ user_logged_in - Failed after 3 attempts
```

### Client Error (No Retry)
```
❌ user_logged_in - HTTP 401 (client error, not retrying): Unauthorized
```

## Testing

### Verify in Customer.io Dashboard

1. Go to **Data & Integrations → Sources**
2. Select **HTTP API Source** (dev or prod)
3. Click **Activity** or **Debugger**
4. Look for:
   - User identifications
   - Event tracking
   - Properties and traits

### Manual Testing with curl

```bash
# Identify user
curl -X POST "https://cdp.picflow.com/v1/identify" \
  -H "Content-Type: application/json" \
  -u "YOUR_API_KEY:" \
  -d '{
    "userId": "test@example.com",
    "traits": {"email": "test@example.com", "name": "Test User"}
  }'

# Track event
curl -X POST "https://cdp.picflow.com/v1/track" \
  -H "Content-Type: application/json" \
  -u "YOUR_API_KEY:" \
  -d '{
    "userId": "test@example.com",
    "name": "test_event",
    "properties": {"platform": "macos"}
  }'
```

## Troubleshooting

### Events not appearing in dashboard
1. Check console for success messages (`✅ HTTP 200`)
2. Verify correct API key in `Environment.swift`
3. Confirm user is identified before tracking events
4. Check Customer.io dashboard for the correct environment (dev vs prod)
5. Wait 1-2 minutes for events to process

### Network errors
1. Verify internet connectivity
2. Check firewall settings
3. Ensure `cdp.picflow.com` is reachable
4. Events will auto-retry with exponential backoff

### Authentication errors
1. Verify API key format (no trailing colon in config)
2. Confirm source is active in Customer.io dashboard
3. Check Basic Auth header construction

## Future Enhancements

**Potential additions if needed:**
- Offline queue (store events when offline, send when back online)
- Batching (group multiple events into single request)
- Local storage persistence (survive app restarts)
- Rate limiting (prevent API throttling)

**Current approach works well for:**
- Online-only usage patterns
- Immediate event delivery requirements
- Simple, debuggable implementation

## Migration History

1. **Customer.io iOS SDK** → ❌ macOS incompatibility
2. **Segment SDK + JavaScript Source** → ❌ Events not delivered
3. **Segment SDK + HTTP API Source** → ❌ Events not delivered
4. **Direct HTTP API** → ✅ **Working solution**

## References

- [Customer.io HTTP API Documentation](https://customer.io/docs/api/track/)
- [Customer.io CDP Sources](https://customer.io/docs/cdp/sources/)
- Custom Domain: `cdp.picflow.com` (CNAME → `cdp-eu.customer.io`)

---

**Last Updated:** January 28, 2025  
**Implementation:** Direct HTTP API with retry logic  
**Provider:** Customer.io CDP (EU Region)  
**Deployment Target:** macOS 14.0+

