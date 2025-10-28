# Endpoint Update Summary

## Changes Made

### 1. Updated Tenant Fetching Endpoint

**Previous Implementation:**
- Used `/v1/profile/current_user` to fetch tenants
- Returned incomplete list of tenants

**New Implementation:**
- Now uses `/v1/tenants` endpoint
- Returns complete list including both owned and shared tenants

### 2. Updated Tenant Model

**File:** `Picflow/Models/Tenant.swift`

**Changes:**
- Added `storageSize: String?` property
- Added `isShared: Bool` property (app-side only, not from API)
- Implemented custom `Codable` conformance to handle the `isShared` property
- **Removed unused properties:** `logoUrl`, `darkLogoUrl`, `logoPosition`, `contacts`, `socials`, `defaultTenant`
- Now uses `faviconUrl` for workspace icon display

**Purpose of `isShared`:**
- Distinguishes between owned workspaces and shared workspaces (where user is a guest)
- Set to `true` for tenants in the `shared_tenants` array from the API response
- Defaults to `false` for owned tenants

**Properties:**
```swift
let id: String
let name: String
let path: String
let faviconUrl: String?
let createdAt: Date?
let updatedAt: Date?
let deletedAt: Date?
let storageSize: String?
var isShared: Bool = false  // Set by app
```

### 3. Updated Authenticator

**File:** `Picflow/Services/Authenticator.swift`

**Method:** `fetchAvailableTenants()`

**Changes:**
- Changed endpoint from `/v1/profile/current_user` to `/v1/tenants`
- Updated response model to match new API structure:
  ```swift
  struct TenantsResponse: Codable {
      let tenants: [Tenant]
      let sharedTenants: [Tenant]
  }
  ```
- Combines both owned and shared tenants into a single list
- Marks shared tenants with `isShared = true`
- Enhanced logging to show counts of owned vs shared workspaces

### 4. Updated Workspace Selection UI

**File:** `Picflow/Views/Workspace/WorkspaceSelectionView.swift`

**Changes:**
- Added visual "Guest" badge for shared workspaces
- Badge appears next to workspace name for shared tenants
- Orange capsule badge with white text for clear visibility
- Updated to use `faviconUrl` instead of `logoUrl` for workspace icons

**File:** `Picflow/Views/Gallery/GallerySelectionView.swift`

**Changes:**
- Updated workspace indicator to use `faviconUrl` instead of `logoUrl`

## API Response Structure

### New `/v1/tenants` Response Format

```json
{
    "tenants": [
        {
            "id": "tnt_...",
            "name": "Workspace Name",
            "path": "workspace-path",
            "favicon_url": "https://assets.picflow.io/...",
            "storage_size": "12345678",
            "created_at": 1630427247,
            "updated_at": 1760992096,
            "deleted_at": null,
            // ... other fields (ignored by app)
        }
    ],
    "shared_tenants": [
        {
            "id": "tnt_...",
            "name": "Shared Workspace",
            "path": "shared-path",
            "favicon_url": "https://assets.picflow.io/...",
            // ... same structure as tenants
        }
    ]
}
```

**Properties Used by App:**
- `id` - Unique tenant identifier
- `name` - Workspace display name
- `path` - URL path (e.g., "workspace.picflow.com")
- `faviconUrl` - Workspace icon/favicon
- `storageSize` - Storage usage (optional)
- `createdAt`, `updatedAt`, `deletedAt` - Timestamps (optional)

Other properties in the API response are ignored by the app.

## Endpoint Usage Summary

### User/Profile Endpoints
- ✅ `/v1/profile` - Get basic user profile (still used for auth verification)
- ❌ `/v1/profile/current_user` - No longer used (replaced by `/v1/tenants`)

### Tenant Endpoints
- ✅ `/v1/tenants` - **NEW** - Get complete list of owned + shared tenants

### Gallery Endpoints
- ✅ `/v1/galleries` - Get galleries (unchanged)

### Asset Endpoints
- ✅ `/v1/assets` - Create asset for upload (unchanged)

## Headers Applied to All API Requests

All requests include:
- `Authorization: Bearer {token}` - JWT token from authentication
- `Content-Type: application/json`
- `Accept: application/json`
- `X-API-Version: 2023-01-01`
- `picflow-tenant: {tenant_id}` - Set after workspace selection

## User Flow

1. **Authentication** → JWT token obtained via OAuth
2. **Profile Verification** → `/v1/profile` to verify token
3. **Tenant List** → `/v1/tenants` to get all workspaces (owned + shared)
4. **Workspace Selection** → User picks workspace, sets `picflow-tenant` header
5. **Gallery Operations** → All subsequent API calls use tenant context

## Testing Recommendations

1. Test with user who has only owned workspaces
2. Test with user who has only shared workspaces (guest)
3. Test with user who has both owned and shared workspaces
4. Verify "Guest" badge appears correctly for shared workspaces
5. Verify all owned workspaces appear without badge

## Benefits of This Change

- ✅ Complete workspace list (no missing tenants)
- ✅ Clear distinction between owned and shared workspaces
- ✅ Better user experience with visual indicators
- ✅ Proper API endpoint usage as intended by backend

