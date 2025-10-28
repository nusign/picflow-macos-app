#!/bin/bash
# Picflow Release Script
# Automates the entire release process: build, sign, notarize, upload to Cloudflare R2

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
DEVELOPER_ID="Developer ID Application: YOUR_NAME (YOUR_TEAM_ID)"  # TODO: Update this
NOTARIZATION_PROFILE="notarytool"  # Keychain profile name
SPARKLE_KEY_PATH="$HOME/.sparkle/private_key"
R2_BUCKET="picflow-updates"  # Your R2 bucket name
APPCAST_URL="https://updates.picflow.com/appcast.xml"  # Your R2 public URL

# Derived variables
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
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
    command -v sign_update >/dev/null 2>&1 || { print_error "Sparkle tools not found. Install with: brew install sparkle"; exit 1; }
    command -v create-dmg >/dev/null 2>&1 || { print_error "create-dmg not found. Install with: brew install create-dmg"; exit 1; }
    command -v rclone >/dev/null 2>&1 || { print_error "rclone not found. Install with: brew install rclone"; exit 1; }
    
    # Check for Sparkle private key
    if [ ! -f "$SPARKLE_KEY_PATH" ]; then
        print_error "Sparkle private key not found at $SPARKLE_KEY_PATH"
        echo "Generate keys with: generate_keys"
        exit 1
    fi
    
    # Check rclone config
    if ! rclone listremotes | grep -q "r2:"; then
        print_error "Cloudflare R2 not configured in rclone"
        echo "Run: rclone config"
        exit 1
    fi
    
    echo "✅ All requirements satisfied"
}

archive_app() {
    print_step "Archiving ${APP_NAME}..."
    
    # Clean build directory
    rm -rf build
    mkdir -p build
    
    # Archive the app
    xcodebuild archive \
        -project "Picflow/Picflow macOS.xcodeproj" \
        -scheme Picflow \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
        CODE_SIGN_STYLE=Manual \
        DEVELOPMENT_TEAM="YOUR_TEAM_ID" \
        | xcpretty || true
    
    echo "✅ Archive created"
}

export_app() {
    print_step "Exporting ${APP_NAME}.app..."
    
    # Create export options plist
    cat > build/ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
EOF
    
    # Export
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist build/ExportOptions.plist \
        | xcpretty || true
    
    echo "✅ App exported"
}

create_dmg() {
    print_step "Creating DMG..."
    
    # Remove old DMG if exists
    rm -f "build/${DMG_NAME}"
    
    # Create DMG
    create-dmg \
        --volname "$APP_NAME" \
        --volicon "Picflow/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 175 120 \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link 425 120 \
        --no-internet-enable \
        "build/${DMG_NAME}" \
        "$APP_PATH" \
        2>&1 | grep -v "^hdiutil" || true
    
    echo "✅ DMG created: build/${DMG_NAME}"
}

sign_dmg() {
    print_step "Signing DMG..."
    
    codesign --sign "$DEVELOPER_ID" \
        --force \
        --verbose \
        "build/${DMG_NAME}"
    
    # Verify signature
    codesign --verify --verbose "build/${DMG_NAME}"
    
    echo "✅ DMG signed"
}

notarize_dmg() {
    print_step "Notarizing DMG (this may take a few minutes)..."
    
    # Submit for notarization
    xcrun notarytool submit "build/${DMG_NAME}" \
        --keychain-profile "$NOTARIZATION_PROFILE" \
        --wait
    
    # Staple the ticket
    xcrun stapler staple "build/${DMG_NAME}"
    
    echo "✅ DMG notarized and stapled"
}

sign_with_sparkle() {
    print_step "Signing with Sparkle..."
    
    # Generate EdDSA signature
    SIGNATURE_OUTPUT=$(sign_update "build/${DMG_NAME}" --ed-key-file "$SPARKLE_KEY_PATH")
    SIGNATURE=$(echo "$SIGNATURE_OUTPUT" | grep "sparkle:edSignature" | sed 's/.*sparkle:edSignature="\([^"]*\)".*/\1/')
    LENGTH=$(stat -f%z "build/${DMG_NAME}")
    
    echo "   Signature: ${SIGNATURE}"
    echo "   Length: ${LENGTH} bytes"
    
    # Store in temporary file for later use
    echo "$SIGNATURE" > "build/signature.txt"
    echo "$LENGTH" > "build/length.txt"
    
    echo "✅ Sparkle signature generated"
}

upload_to_r2() {
    print_step "Uploading to Cloudflare R2..."
    
    # Upload DMG
    rclone copy "build/${DMG_NAME}" "r2:${R2_BUCKET}/" \
        --progress \
        --header "Cache-Control: public, max-age=31536000"
    
    echo "✅ DMG uploaded to R2"
}

update_appcast() {
    print_step "Updating appcast.xml..."
    
    # Read signature and length
    SIGNATURE=$(cat "build/signature.txt")
    LENGTH=$(cat "build/length.txt")
    DOWNLOAD_URL="https://updates.picflow.com/${DMG_NAME}"
    PUBDATE=$(date -u +"%a, %d %b %Y %H:%M:%S %z")
    
    # Download current appcast
    rclone copy "r2:${R2_BUCKET}/appcast.xml" "build/" 2>/dev/null || {
        # Create new appcast if doesn't exist
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
    }
    
    # Create new item
    NEW_ITEM=$(cat <<EOF
        <item>
            <title>Version ${VERSION}</title>
            <sparkle:version>${VERSION}</sparkle:version>
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
)
    
    # Insert new item after <language>en</language>
    sed -i '' "/<language>en<\/language>/a\\
$NEW_ITEM
" build/appcast.xml
    
    # Upload updated appcast
    rclone copy build/appcast.xml "r2:${R2_BUCKET}/" \
        --header "Cache-Control: public, max-age=3600, must-revalidate"
    
    echo "✅ appcast.xml updated and uploaded"
}

create_release_notes() {
    print_step "Creating release notes..."
    
    cat > "build/RELEASE-${VERSION}.md" << EOF
# Picflow ${VERSION}

**Release Date:** $(date +"%B %d, %Y")

## Download

- DMG: https://updates.picflow.com/${DMG_NAME}
- Size: $(echo "scale=2; $(cat build/length.txt)/1024/1024" | bc) MB

## Installation

1. Download the DMG
2. Open and drag Picflow to Applications
3. Launch Picflow

## Verification

- EdDSA Signature: \`$(cat build/signature.txt)\`
- Notarized by Apple: Yes

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
    sign_with_sparkle
    upload_to_r2
    update_appcast
    create_release_notes
    cleanup
    
    echo -e "\n${GREEN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   🎉 Release Complete!                ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
    echo ""
    echo "📦 DMG: build/${DMG_NAME}"
    echo "📄 Release Notes: build/RELEASE-${VERSION}.md"
    echo "🌐 Download URL: https://updates.picflow.com/${DMG_NAME}"
    echo "🔔 Users will receive update notification automatically"
    echo ""
    echo "Next steps:"
    echo "  1. Review build/RELEASE-${VERSION}.md"
    echo "  2. Update your changelog at https://picflow.com/changelog"
    echo "  3. Announce the release!"
}

# Run main function
main

