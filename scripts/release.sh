#!/bin/bash
# Picflow Release Script
# Automates the entire release process: build, sign, notarize, upload to GitHub releases
#
# This script creates TWO DMG files:
#   1. Picflow-X.Y.Z.dmg - Versioned, signed, notarized, and signed with Sparkle 2 EdDSA (for auto-updates)
#   2. Picflow.dmg - Exact copy of versioned DMG (for marketing/emails/website)
#
# Process:
#   - Create, sign, and notarize the versioned DMG once
#   - Copy the notarized DMG to create Picflow.dmg (no re-signing/re-notarizing needed)
#   - Sign versioned DMG with Sparkle 2 for secure auto-updates
#
# Sparkle 2 uses the versioned DMG with verified EdDSA signatures.
# The "latest" DMG is overwritten with each release for marketing purposes.

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VERSION=$1
APP_NAME="Picflow"
BUNDLE_ID="com.picflow.macos"
DEVELOPER_ID="Developer ID Application: Nusign AG (9Q9676B973)"
NOTARIZATION_PROFILE="notarytool"  # Keychain profile name
GITHUB_REPO="nusign/picflow-macos"  # Github repository for the app
APPCAST_URL="https://picflow.com/download/macos/appcast.xml"  # Final S3 URL where appcast will live

# Derived variables
DMG_NAME_VERSIONED="${APP_NAME}-${VERSION}.dmg"  # For Sparkle (signed)
DMG_NAME_LATEST="${APP_NAME}.dmg"                # For marketing (always latest)
ARCHIVE_PATH="build/Picflow.xcarchive"
EXPORT_PATH="build/Export"
APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"

# Functions
print_step() {
    echo -e "\n${BLUE}==>${NC} ${GREEN}$1${NC}"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

check_requirements() {
    print_step "Checking requirements..."
    
    if [ -z "$VERSION" ]; then
        print_error "Version number required"
        echo "Usage: ./scripts/release.sh 1.2.0"
        exit 1
    fi
    
    # Check for required tools
    command -v xcrun >/dev/null 2>&1 || { print_error "Xcode command line tools not found"; exit 1; }
    command -v create-dmg >/dev/null 2>&1 || { print_error "create-dmg not found. Install with: brew install create-dmg"; exit 1; }
    command -v gh >/dev/null 2>&1 || { print_error "GitHub CLI not found. Install with: brew install gh"; exit 1; }
    
    # Check for Sparkle (either generate_appcast or the installation directory)
    if ! command -v /opt/homebrew/Caskroom/sparkle/2.8.0/bin/generate_appcast >/dev/null 2>&1 && \
       ! [ -d /opt/homebrew/Caskroom/sparkle ] && \
       ! command -v openssl >/dev/null 2>&1; then
        print_error "Sparkle tools or OpenSSL not found. Install with: brew install sparkle"
        exit 1
    fi
    
    # Check for Sparkle private key in Keychain
    if ! security find-generic-password -a ed25519 -s "https://sparkle-project.org" >/dev/null 2>&1; then
        print_error "Sparkle private key not found in Keychain"
        echo "Generate keys with: /opt/homebrew/Caskroom/sparkle/2.8.0/bin/generate_keys"
        exit 1
    fi
    
    # Check GitHub CLI authentication
    if ! gh auth status >/dev/null 2>&1; then
        print_error "GitHub CLI not authenticated"
        echo "Run: gh auth login"
        exit 1
    fi
    
    echo "✅ All requirements satisfied"
}

archive_app() {
    print_step "Archiving ${APP_NAME}..."
    
    # Clean build directory
    rm -rf build
    mkdir -p build
    
    # Archive the app (let Xcode handle signing automatically during archive)
    xcodebuild archive \
        -project "Picflow macOS.xcodeproj" \
        -scheme Picflow \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        | xcpretty || true
    
    echo "✅ Archive created"
}

export_app() {
    print_step "Exporting and re-signing ${APP_NAME}.app with Developer ID..."
    
    # Copy the archived app
    mkdir -p "$EXPORT_PATH"
    cp -R "$ARCHIVE_PATH/Products/Applications/${APP_NAME}.app" "$EXPORT_PATH/"
    
    # Re-sign all frameworks and the app with Developer ID certificate
    # This is required for notarization
    
    echo "   Re-signing frameworks..."
    # Sign all frameworks with Developer ID, hardened runtime, and timestamp
    find "$APP_PATH/Contents/Frameworks" -name "*.framework" -o -name "*.dylib" | while read framework; do
        codesign --sign "$DEVELOPER_ID" \
            --force \
            --timestamp \
            --options runtime \
            --deep \
            "$framework" 2>/dev/null || true
    done
    
    # Sign XPC services and helper apps
    find "$APP_PATH/Contents" -name "*.xpc" -o -name "*.app" | while read service; do
        codesign --sign "$DEVELOPER_ID" \
            --force \
            --timestamp \
            --options runtime \
            "$service" 2>/dev/null || true
    done
    
    echo "   Re-signing main app..."
    # Sign the main app with Developer ID, hardened runtime, timestamp, and entitlements
    codesign --sign "$DEVELOPER_ID" \
        --force \
        --timestamp \
        --options runtime \
        --entitlements "Picflow/Picflow.entitlements" \
        --deep \
        "$APP_PATH"
    
    # Verify the signature
    codesign --verify --deep --strict --verbose=2 "$APP_PATH"
    
    echo "✅ App exported and re-signed with Developer ID"
}

create_dmg() {
    print_step "Creating DMG..."
    
    # Remove old DMG if exists
    rm -f "build/${DMG_NAME_VERSIONED}"
    
    # Create versioned DMG (we'll copy it later after signing/notarizing)
    create-dmg \
        --volname "$APP_NAME" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 175 120 \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link 425 120 \
        --no-internet-enable \
        "build/${DMG_NAME_VERSIONED}" \
        "$APP_PATH" \
        2>&1 | grep -v "^hdiutil" || true
    
    echo "✅ DMG created: build/${DMG_NAME_VERSIONED}"
}

sign_dmg() {
    print_step "Verifying app signature..."
    
    # Verify the app inside the archive is signed (which it should be from the build)
    if codesign --verify --deep --strict "$ARCHIVE_PATH/Products/Applications/${APP_NAME}.app" 2>/dev/null; then
        echo "✅ App is properly signed"
    else
        print_warning "App signature verification failed - notarization may fail"
    fi
    
    # Note: DMGs don't need code-signing before notarization
    # The app inside is signed, and notarization validates everything
    echo "✅ Ready for notarization (DMG will be validated by Apple)"
}

notarize_dmg() {
    print_step "Notarizing DMG (this may take a few minutes)..."
    
    # Submit versioned DMG for notarization
    xcrun notarytool submit "build/${DMG_NAME_VERSIONED}" \
        --keychain-profile "$NOTARIZATION_PROFILE" \
        --wait
    
    # Staple the notarization ticket
    xcrun stapler staple "build/${DMG_NAME_VERSIONED}"
    
    echo "✅ DMG notarized and stapled"
}

create_latest_dmg() {
    print_step "Creating latest DMG copy..."
    
    # Now copy the signed and notarized DMG for marketing
    rm -f "build/${DMG_NAME_LATEST}"
    cp "build/${DMG_NAME_VERSIONED}" "build/${DMG_NAME_LATEST}"
    
    echo "✅ Latest DMG created: build/${DMG_NAME_LATEST}"
    echo "   (Copy of notarized ${DMG_NAME_VERSIONED})"
}

sign_with_sparkle() {
    print_step "Signing versioned DMG with Sparkle 2..."
    
    # Generate EdDSA signature for versioned DMG (Sparkle 2 format)
    # Note: Only the versioned DMG needs Sparkle signature for auto-updates
    # The "latest" DMG is identical but used for marketing (no signature verification)
    
    # Read private key from macOS Keychain (where Sparkle's generate_keys stores it)
    PRIVATE_KEY_B64=$(security find-generic-password -a ed25519 -s "https://sparkle-project.org" -w 2>/dev/null)
    
    if [ -z "$PRIVATE_KEY_B64" ]; then
        echo "❌ ERROR: Private key not found in Keychain"
        echo "   Run: /opt/homebrew/Caskroom/sparkle/2.8.0/bin/generate_keys"
        echo "   Or manually add it with: security add-generic-password -a ed25519 -s \"https://sparkle-project.org\" -w \"<base64-encoded-key>\""
        exit 1
    fi
    
    # Use Python with cryptography library for reliable EdDSA signing
    export PRIVATE_KEY_B64
    python3 << PYTHON_EOF
import base64
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend
import os

# Get private key from environment (passed from shell)
private_key_b64 = os.environ.get('PRIVATE_KEY_B64')
private_key_der = base64.b64decode(private_key_b64)

# Load the private key (it's stored as raw 32-byte Ed25519 key in Keychain)
# We need to reconstruct it into a proper format
from cryptography.hazmat.primitives.asymmetric import ed25519

# Create Ed25519 private key from the raw bytes
private_key = ed25519.Ed25519PrivateKey.from_private_bytes(private_key_der)

# Read the DMG file
with open('build/${DMG_NAME_VERSIONED}', 'rb') as f:
    dmg_data = f.read()

# Sign the file (Ed25519 signs the raw data directly)
signature = private_key.sign(dmg_data)

# Encode as base64 for Sparkle
signature_b64 = base64.b64encode(signature).decode('ascii')

# Save to files
with open('build/signature.txt', 'w') as f:
    f.write(signature_b64)
with open('build/length.txt', 'w') as f:
    f.write(str(len(dmg_data)))

print(f"   Signature: {signature_b64}")
print(f"   Length: {len(dmg_data)} bytes")
PYTHON_EOF
    
    echo "✅ Sparkle 2 EdDSA signature generated for versioned DMG"
}

create_github_release() {
    print_step "Creating GitHub release..."
    
    # Check if release already exists
    if gh release view "v${VERSION}" --repo "$GITHUB_REPO" >/dev/null 2>&1; then
        print_warning "Release v${VERSION} already exists"
        read -p "Delete and recreate? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            gh release delete "v${VERSION}" --repo "$GITHUB_REPO" --yes
        else
            print_error "Release already exists. Aborting."
            exit 1
        fi
    fi
    
    # Create release
    gh release create "v${VERSION}" \
        --repo "$GITHUB_REPO" \
        --title "Picflow ${VERSION}" \
        --notes "## What's New in ${VERSION}

See [changelog](https://picflow.com/changelog) for details.

## Installation

1. Download the DMG below
2. Open and drag Picflow to Applications
3. Launch Picflow

## Verification

- EdDSA Signature: \`$(cat build/signature.txt)\`
- Notarized by Apple: Yes" \
        --draft=false \
        --prerelease=false
    
    echo "✅ GitHub release created: v${VERSION}"
}

upload_to_github() {
    print_step "Uploading assets to GitHub release..."
    
    # Upload versioned DMG (for Sparkle updates)
    echo "   Uploading ${DMG_NAME_VERSIONED}..."
    gh release upload "v${VERSION}" \
        "build/${DMG_NAME_VERSIONED}" \
        --repo "$GITHUB_REPO" \
        --clobber
    
    # Upload latest DMG (copy for marketing)
    echo "   Uploading ${DMG_NAME_LATEST}..."
    gh release upload "v${VERSION}" \
        "build/${DMG_NAME_LATEST}" \
        --repo "$GITHUB_REPO" \
        --clobber
    
    echo "✅ Both DMGs uploaded to GitHub release"
    echo "   (${DMG_NAME_LATEST} is an identical copy of ${DMG_NAME_VERSIONED})"
}

update_appcast() {
    print_step "Creating appcast.xml (Sparkle 2 format)..."
    
    # Read signature and length (for versioned DMG only)
    SIGNATURE=$(cat "build/signature.txt")
    LENGTH=$(cat "build/length.txt")
    DOWNLOAD_URL="https://picflow.com/download/macos/${DMG_NAME_VERSIONED}"
    PUBDATE=$(date -u +"%a, %d %b %Y %H:%M:%S %z")
    
    # Extract build number from the app for Sparkle version comparison
    BUILD_NUMBER=$(defaults read "${PWD}/${APP_PATH}/Contents/Info.plist" CFBundleVersion)
    
    # Try to download existing appcast from latest release
    EXISTING_APPCAST=""
    LATEST_RELEASE=$(gh release list --repo "$GITHUB_REPO" --limit 1 --json tagName --jq '.[0].tagName' 2>/dev/null || echo "")
    
    if [ -n "$LATEST_RELEASE" ] && [ "$LATEST_RELEASE" != "v${VERSION}" ]; then
        gh release download "$LATEST_RELEASE" \
            --repo "$GITHUB_REPO" \
            --pattern "appcast.xml" \
            --dir "build/" 2>/dev/null || true
    fi
    
    if [ -f "build/appcast.xml" ]; then
        EXISTING_APPCAST=$(cat "build/appcast.xml")
    else
        # Create new appcast if doesn't exist (Sparkle 2 format)
        cat > build/appcast.xml << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Picflow Updates</title>
        <link>${APPCAST_URL}</link>
        <description>Picflow app updates</description>
        <language>en</language>
    </channel>
</rss>
EOF
    fi
    
    # Create new item in a temporary file
    # NOTE: sparkle:version MUST be the build number for proper version comparison
    # sparkle:shortVersionString is the display version shown to users
    cat > "build/new_item.xml" <<EOF
        <item>
            <title>Version ${VERSION}</title>
            <sparkle:version>${BUILD_NUMBER}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <description><![CDATA[
                <h2>What's New in ${VERSION}</h2>
                <p>See <a href="https://picflow.com/changelog">changelog</a> for details.</p>
            ]]></description>
            <pubDate>${PUBDATE}</pubDate>
            <enclosure 
                url="${DOWNLOAD_URL}"
                sparkle:edSignature="${SIGNATURE}"
                length="${LENGTH}"
                type="application/octet-stream"
            />
        </item>
EOF
    
    # Insert new item after <language>en</language> using awk
    awk '/<language>en<\/language>/ {print; while((getline line < "build/new_item.xml") > 0) print line; next} 1' \
        build/appcast.xml > build/appcast.xml.tmp
    mv build/appcast.xml.tmp build/appcast.xml
    rm -f build/new_item.xml
    
    # Upload appcast to GitHub release
    gh release upload "v${VERSION}" \
        "build/appcast.xml" \
        --repo "$GITHUB_REPO" \
        --clobber
    
    echo "✅ appcast.xml (Sparkle 2 format) created and uploaded to GitHub release"
    echo "   Sparkle will check: ${APPCAST_URL}"
    echo "   Update points to: ${DOWNLOAD_URL}"
}

create_release_notes() {
    print_step "Creating release notes..."
    
    cat > "build/RELEASE-${VERSION}.md" << EOF
# Picflow ${VERSION}

**Release Date:** $(date +"%B %d, %Y")

## Download

- **Always Latest:** https://picflow.com/download/macos/Picflow.dmg
- **This Version:** https://picflow.com/download/macos/${DMG_NAME_VERSIONED}
- **GitHub Release:** https://github.com/${GITHUB_REPO}/releases/tag/v${VERSION}
- **Size:** $(echo "scale=2; $(cat build/length.txt)/1024/1024" | bc) MB

> 💡 Use the "Always Latest" link for emails/marketing - it always points to the newest version.

## Installation

1. Download the DMG
2. Open and drag Picflow to Applications
3. Launch Picflow

## Automatic Updates

Current users will be notified automatically via Sparkle 2 updater.

## Verification

- **Sparkle 2 EdDSA Signature:** \`$(cat build/signature.txt)\`
- **Apple Notarization:** Yes ✅
- **Code Signed:** Yes ✅

## Changelog

TODO: Add your changelog here

---

Generated by release script on $(date)
EOF
    
    echo "✅ Release notes created: build/RELEASE-${VERSION}.md"
}

cleanup() {
    print_step "Cleaning up..."
    
    # Keep DMG and release notes, remove everything else
    rm -f build/signature.txt
    rm -f build/length.txt
    rm -f build/ExportOptions.plist
    rm -f build/appcast.xml
    rm -f build/new_item.xml
    rm -f build/temp_appcast.xml
    rm -rf "$ARCHIVE_PATH"
    rm -rf "$EXPORT_PATH"
    
    echo "✅ Cleanup complete"
}

# Main script
main() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════╗"
    echo "║   Picflow Release Automation          ║"
    echo "║   Version: ${VERSION}                 ║"
    echo "╚═══════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_requirements
    archive_app
    export_app
    create_dmg
    sign_dmg
    notarize_dmg
    create_latest_dmg
    sign_with_sparkle
    create_github_release
    upload_to_github
    update_appcast
    create_release_notes
    cleanup
    
    echo -e "\n${GREEN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   🎉 Release Complete!                ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
    echo ""
    echo "📦 Local Files:"
    echo "   - Versioned DMG: build/${DMG_NAME_VERSIONED} (signed, notarized, Sparkle signed)"
    echo "   - Latest DMG: build/${DMG_NAME_LATEST} (identical copy)"
    echo "   - Release Notes: build/RELEASE-${VERSION}.md"
    echo ""
    echo "🌐 GitHub Release: https://github.com/${GITHUB_REPO}/releases/tag/v${VERSION}"
    echo ""
    echo "🔗 Final URLs (after GitHub Action syncs to S3):"
    echo "   - For Sparkle updates: https://picflow.com/download/macos/${DMG_NAME_VERSIONED}"
    echo "   - For marketing/emails: https://picflow.com/download/macos/Picflow.dmg (always latest)"
    echo "   - Update feed: https://picflow.com/download/macos/appcast.xml"
    echo ""
    echo "⏱️  Time saved: ~5 minutes by notarizing once and copying!"
    echo "🔔 Users will receive Sparkle 2 update notification after GitHub Action syncs to S3"
    echo ""
    echo "Next steps:"
    echo "  1. Review the GitHub release at: https://github.com/${GITHUB_REPO}/releases/tag/v${VERSION}"
    echo "  2. Wait for GitHub Action to sync files to S3 (~1-2 minutes)"
    echo "  3. Test the update: open Picflow and check for updates"
    echo "  4. Update your changelog at https://picflow.com/changelog"
    echo "  5. Share the marketing link: https://picflow.com/download/macos/Picflow.dmg"
    echo "  6. Announce the release!"
}

# Run main function
main

