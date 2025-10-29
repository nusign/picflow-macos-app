# GitHub Actions

## sync-release-to-s3.yml

Automatically syncs macOS release files from GitHub Releases to S3 for distribution.

### Trigger

Runs automatically when a new GitHub release is published.

### What It Does

1. **Downloads release assets** from GitHub:
   - `Picflow-X.Y.Z.dmg` (versioned)
   - `Picflow.dmg` (latest)
   - `appcast.xml` (Sparkle update feed)

2. **Uploads to S3:**
   - Location: `s3://picflow-webapp-prod/macos/`
   - Sets proper permissions (`public-read`)
   - Adds cache headers:
     - Versioned DMG: 1 year cache (immutable)
     - Latest DMG: 5 minute cache
     - appcast.xml: 1 hour cache

3. **Creates summary** with public URLs

### Required Secrets

Environment: `production`

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_DEFAULT_REGION`

### File Behavior

| File | S3 Path | Cache | Behavior |
|------|---------|-------|----------|
| `Picflow-X.Y.Z.dmg` | `macos/Picflow-X.Y.Z.dmg` | 1 year | Permanent, never overwritten |
| `Picflow.dmg` | `macos/Picflow.dmg` | 5 min | Overwritten each release |
| `appcast.xml` | `macos/appcast.xml` | 1 hour | Overwritten each release |

### Public URLs

After sync, files are available at:

- **Versioned:** `https://picflow.com/download/macos/Picflow-X.Y.Z.dmg`
- **Latest:** `https://picflow.com/download/macos/Picflow.dmg`
- **Updates:** `https://picflow.com/download/macos/appcast.xml`

### Usage

No manual action needed! Just publish a release and the action runs automatically.

### Testing

To test without publishing a real release:
1. Go to Actions tab in GitHub
2. Select "Sync Release to S3"
3. Click "Run workflow"
4. Select a tag to sync

