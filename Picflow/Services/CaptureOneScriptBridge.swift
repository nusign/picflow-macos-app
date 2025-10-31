//
//  CaptureOneScriptBridge.swift
//  Picflow
//
//  Created by Michel Luarasi on 17.10.2025.
//

import Foundation
import AppKit

/// Bridge to communicate with Capture One via AppleScript
class CaptureOneScriptBridge {
    
    enum CaptureOneError: Error, LocalizedError {
        case notRunning
        case scriptExecutionFailed(String)
        case noDocument
        case parseError
        case permissionDenied
        
        var errorDescription: String? {
            switch self {
            case .notRunning:
                return "Capture One is not running"
            case .scriptExecutionFailed(let message):
                return message
            case .noDocument:
                return "No document is open in Capture One"
            case .parseError:
                return "Failed to parse response from Capture One"
            case .permissionDenied:
                return "Permission required: Please grant Picflow access to control Capture One in System Settings → Privacy & Security → Automation"
            }
        }
    }
    
    // Cache the detected app info
    private var detectedBundleId: String?
    private var detectedAppName: String?
    
    /// Detect the running Capture One app bundle identifier and name
    private func detectCaptureOneApp() -> (bundleId: String, appName: String)? {
        // If we have a cached ID, verify it's still running
        if let cachedId = detectedBundleId, let cachedName = detectedAppName {
            let stillRunning = NSWorkspace.shared.runningApplications.contains { app in
                app.bundleIdentifier == cachedId
            }
            if stillRunning {
                print("🔍 Using cached: '\(cachedName)' (bundle ID: \(cachedId))")
                return (cachedId, cachedName)
            } else {
                // App quit, clear cache
                detectedBundleId = nil
                detectedAppName = nil
                print("🔍 Cache cleared - app is no longer running")
            }
        }
        
        let runningApps = NSWorkspace.shared.runningApplications
        
        print("🔍 Searching for Capture One in \(runningApps.count) running apps...")
        
        // Try to find Capture One by bundle identifier
        let captureOneApp = runningApps.first { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            return bundleId.contains("captureone") || bundleId.contains("phaseone")
        }
        
        guard let app = captureOneApp,
              let bundleId = app.bundleIdentifier,
              let appName = app.localizedName else {
            print("❌ Capture One not found in running apps")
            return nil
        }
        
        detectedBundleId = bundleId
        detectedAppName = appName
        print("✅ Detected Capture One:")
        print("   App Name: '\(appName)'")
        print("   Bundle ID: \(bundleId)")
        return (bundleId, appName)
    }
    
    /// Get the current selection and document name from Capture One
    func getSelection() async throws -> CaptureOneSelection {
        // Detect which Capture One is running
        guard let appInfo = detectCaptureOneApp() else {
            throw CaptureOneError.notRunning
        }
        
        // CRITICAL: Double-check the app is actually running before executing AppleScript
        // AppleScript's "tell application" will LAUNCH the app if it's not running!
        let isStillRunning = NSWorkspace.shared.runningApplications.contains { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            return bundleId == appInfo.bundleId
        }
        
        guard isStillRunning else {
            // App quit between detection and this check
            detectedBundleId = nil  // Clear cache
            detectedAppName = nil
            throw CaptureOneError.notRunning
        }
        
        // Ready to access Capture One
        
        // AppleScript to get selection count and document name from the active catalog window
        // Use 'current document' to get the currently frontmost document
        let script = """
        tell application "\(appInfo.appName)"
            try
                tell current document
                    set selCount to count of (variants whose selected is true)
                    set docName to name
                    return (selCount as text) & "|" & docName
                end tell
            on error errMsg number errNum
                return "ERROR:" & errMsg & " (code: " & errNum & ")"
            end try
        end tell
        """
        
        let result = try await executeAppleScript(script)
        
        // Check for errors
        if result.hasPrefix("ERROR:") {
            // Error -1728 means "Can't get current document" - no document is open
            if result.contains("(code: -1728)") {
                throw CaptureOneError.noDocument
            }
            throw CaptureOneError.scriptExecutionFailed(result)
        }
        
        // Parse result - format is "count|documentName"
        let parts = result.split(separator: "|", maxSplits: 1)
        guard parts.count == 2,
              let count = Int(parts[0]) else {
            throw CaptureOneError.scriptExecutionFailed("Invalid response format: \(result)")
        }
        
        // Remove file extension from document name
        let fullName = String(parts[1])
        let documentName = (fullName as NSString).deletingPathExtension
        
        return CaptureOneSelection(count: count, variants: [], documentName: documentName)
    }
    
    /// Execute AppleScript and return result using osascript subprocess
    /// This bypasses NSAppleScript sandboxing issues
    private func executeAppleScript(_ script: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", script]
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    if process.terminationStatus != 0 {
                        let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        
                        print("🔍 AppleScript error output: \(errorMessage)")
                        print("🔍 Termination status: \(process.terminationStatus)")
                        
                        // Check for permission errors (-600, -1743, -1728)
                        if errorMessage.contains("(-600)") || errorMessage.contains("(-1743)") || 
                           errorMessage.contains("(-1728)") || errorMessage.contains("not allowed") || 
                           errorMessage.contains("permission") {
                            print("🚫 Detected as permission error")
                            continuation.resume(throwing: CaptureOneError.permissionDenied)
                        } else {
                            print("❌ Detected as script execution error")
                            continuation.resume(throwing: CaptureOneError.scriptExecutionFailed(errorMessage))
                        }
                        return
                    }
                    
                    let result = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    continuation.resume(returning: result)
                    
                } catch {
                    continuation.resume(throwing: CaptureOneError.scriptExecutionFailed(error.localizedDescription))
                }
            }
        }
    }
    
    /// Generate AppleScript to create a recipe with the specified settings
    private func recipeCreationScript(appName: String, recipeName: String, outputFolder: URL) -> String {
        return """
        tell application "\(appName)"
            try
                tell front document
                    -- Create new recipe
                    set newRecipe to make new recipe with properties {name:"\(recipeName)"}
                    
                    -- Convert path to alias (required for custom location to work)
                    try
                        set exportPath to POSIX file "\(outputFolder.path)" as alias
                    on error pathErr number pathErrNum
                        return "ERROR:Cannot convert path to alias: " & pathErr & " (code: " & pathErrNum & "). Folder may not exist: \(outputFolder.path)"
                    end try
                    
                    -- CRITICAL: Set location BEFORE type, and use alias not string
                    tell newRecipe
                        set root folder location to exportPath
                        set root folder type to custom location
                    end tell
                    
                    -- Set basic format defaults (users can customize later)
                    set output format of newRecipe to JPEG
                    set JPEG quality of newRecipe to 90
                    
                    return "SUCCESS"
                end tell
            on error errMsg number errNum
                return "ERROR:" & errMsg & " (code: " & errNum & ")"
            end try
        end tell
        """
    }
    
    /// Force delete and recreate a recipe with the correct output location
    /// Use this when you know the recipe has the wrong settings
    /// - Parameters:
    ///   - recipeName: Name of the recipe
    ///   - outputFolder: Desired output folder
    /// - Throws: CaptureOneError if creation fails
    func forceRecreateRecipe(recipeName: String, outputFolder: URL) async throws {
        guard let appInfo = detectCaptureOneApp() else {
            throw CaptureOneError.notRunning
        }
        
        print("🔄 Force recreating recipe '\(recipeName)'...")
        
        // Delete existing recipe from the active catalog
        let deleteScript = """
        tell application "\(appInfo.appName)"
            try
                tell front document
                    if (exists recipe "\(recipeName)") then
                        delete recipe "\(recipeName)"
                        return "DELETED"
                    else
                        return "NOT_EXISTS"
                    end if
                end tell
            on error errMsg number errNum
                return "ERROR:" & errMsg & " (code: " & errNum & ")"
            end try
        end tell
        """
        
        let deleteResult = try await executeAppleScript(deleteScript)
        
        if deleteResult == "DELETED" {
            print("🗑️  Deleted existing recipe '\(recipeName)'")
        } else if deleteResult == "NOT_EXISTS" {
            print("ℹ️  Recipe '\(recipeName)' didn't exist")
        } else if deleteResult.hasPrefix("ERROR:") {
            print("⚠️  Could not delete recipe: \(deleteResult)")
            // Continue anyway - try to create it
        }
        
        // Create new recipe using shared script generator
        print("📋 Force creating recipe with app: '\(appInfo.appName)'")
        print("📁 Recipe output folder: \(outputFolder.path)")
        
        let createScript = recipeCreationScript(appName: appInfo.appName, recipeName: recipeName, outputFolder: outputFolder)
        let createResult = try await executeAppleScript(createScript)
        
        if createResult.hasPrefix("ERROR:") {
            let errorMsg = String(createResult.dropFirst(6))
            throw CaptureOneError.scriptExecutionFailed("Failed to create recipe: \(errorMsg)")
        } else if createResult == "SUCCESS" {
            print("✅ Created recipe '\(recipeName)' with output: \(outputFolder.path)")
            print("ℹ️  You can customize quality, watermarks, and metadata in Capture One")
        }
    }
    
    /// Ensures recipe exists with correct and valid output folder
    /// - If recipe exists with correct path: Refreshes alias by setting location+type (preserves quality/watermark)
    /// - If recipe exists with wrong path: Deletes and recreates
    /// - If recipe doesn't exist: Creates new recipe
    /// - Parameters:
    ///   - recipeName: Name of the recipe
    ///   - outputFolder: Desired output folder
    /// - Throws: CaptureOneError if creation fails
    /// - Note: Sets both location AND type (in that order) to properly refresh stale aliases
    private func createOrRecreateRecipe(recipeName: String, outputFolder: URL) async throws {
        guard let appInfo = detectCaptureOneApp() else {
            throw CaptureOneError.notRunning
        }
        
        // Check if recipe exists and read its output location
        let checkScript = """
        tell application "\(appInfo.appName)"
            try
                tell front document
                    if (exists recipe "\(recipeName)") then
                        -- Recipe exists, get its output path
                        set recipeLoc to root folder location of recipe "\(recipeName)"
                        return "EXISTS:" & (POSIX path of recipeLoc)
                    else
                        return "NOT_EXISTS"
                    end if
                end tell
            on error errMsg number errNum
                return "ERROR:" & errMsg & " (code: " & errNum & ")"
            end try
        end tell
        """
        
        print("📋 Checking if recipe '\(recipeName)' exists...")
        let checkResult = try await executeAppleScript(checkScript)
        print("📋 Result: '\(checkResult)'")
        
        if checkResult.hasPrefix("EXISTS:") {
            let existingPath = String(checkResult.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
            let expectedPath = outputFolder.path.hasSuffix("/") ? outputFolder.path : outputFolder.path + "/"
            let normalizedExistingPath = existingPath.hasSuffix("/") ? existingPath : existingPath + "/"
            
            print("📊 Path comparison:")
            print("   Raw existing path from recipe: '\(existingPath)'")
            print("   Normalized existing path:      '\(normalizedExistingPath)'")
            print("   Expected path:                 '\(expectedPath)'")
            print("   Paths match: \(normalizedExistingPath == expectedPath)")
            
            if normalizedExistingPath == expectedPath {
                print("✅ Recipe '\(recipeName)' exists with correct output path (as string)")
                print("🔄 Refreshing alias by resetting location AND type (preserves quality settings)...")
                
                // Alias might be stale. Set location THEN type (order matters per API docs)
                let updateScript = """
                tell application "\(appInfo.appName)"
                    try
                        tell front document
                            set targetRecipe to recipe "\(recipeName)"
                            set newPath to POSIX file "\(outputFolder.path)" as alias
                            tell targetRecipe
                                set root folder location to newPath
                                set root folder type to custom location
                            end tell
                            return "UPDATED"
                        end tell
                    on error errMsg number errNum
                        return "ERROR:" & errMsg & " (code: " & errNum & ")"
                    end try
                end tell
                """
                
                let updateResult = try await executeAppleScript(updateScript)
                print("📋 Update result: '\(updateResult)'")
                
                if updateResult == "UPDATED" {
                    print("✅ Recipe alias refreshed (location + type set)")
                    return // Recipe is now ready
                } else {
                    print("⚠️  Update failed: \(updateResult)")
                    print("🔄 Will delete and recreate instead...")
                }
            }
            
            // If we reach here, either path was wrong or update failed - delete and recreate
            if checkResult.hasPrefix("EXISTS:") {
                print("🔄 Deleting existing recipe to recreate with fresh settings...")
                let deleteScript = """
                tell application "\(appInfo.appName)"
                    try
                        tell front document
                            delete recipe "\(recipeName)"
                            return "DELETED"
                        end tell
                    on error errMsg number errNum
                        return "ERROR:" & errMsg & " (code: " & errNum & ")"
                    end try
                end tell
                """
                
                let deleteResult = try await executeAppleScript(deleteScript)
                print("📋 Delete result: '\(deleteResult)'")
            }
        } else if checkResult == "NOT_EXISTS" {
            print("ℹ️  Recipe '\(recipeName)' doesn't exist, creating new recipe...")
        } else if checkResult.hasPrefix("ERROR:") {
            print("⚠️  Could not check recipe: \(checkResult)")
            print("⚠️  Will attempt to create recipe anyway...")
        }
        
        // Create new recipe using shared script generator
        print("🔨 Creating recipe '\(recipeName)' with output: \(outputFolder.path)")
        
        let createScript = recipeCreationScript(appName: appInfo.appName, recipeName: recipeName, outputFolder: outputFolder)
        let createResult = try await executeAppleScript(createScript)
        print("📋 Result: '\(createResult)'")
        
        if createResult.hasPrefix("ERROR:") {
            let errorMsg = String(createResult.dropFirst(6))
            print("❌ Recipe creation failed: \(errorMsg)")
            throw CaptureOneError.scriptExecutionFailed("Failed to create recipe: \(errorMsg)")
        } else if createResult == "SUCCESS" {
            print("✅ Created recipe '\(recipeName)' with output: \(outputFolder.path)")
            print("ℹ️  You can customize quality, watermarks, and metadata in Capture One")
        } else {
            print("⚠️  Unexpected create result: '\(createResult)'")
        }
    }
    
    /// Export selected variants using the "Picflow Upload" recipe to a temporary folder
    /// Get file paths of selected variants (original files)
    func getSelectedVariantPaths() async throws -> [URL] {
        // Detect which Capture One is running
        guard let appInfo = detectCaptureOneApp() else {
            throw CaptureOneError.notRunning
        }
        
        // Double-check app is running
        let isStillRunning = NSWorkspace.shared.runningApplications.contains { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            return bundleId == appInfo.bundleId
        }
        
        guard isStillRunning else {
            detectedBundleId = nil
            detectedAppName = nil
            throw CaptureOneError.notRunning
        }
        
        // AppleScript to get file paths of selected variants from the active catalog
        let script = """
        tell application "\(appInfo.appName)"
            try
                tell front document
                    set selectedVariants to (variants whose selected is true)
                    set variantCount to count of selectedVariants
                    
                    if variantCount is 0 then
                        return ""
                    end if
                    
                    set filePaths to {}
                    
                    repeat with v in selectedVariants
                        try
                            set parentImg to parent image of v
                            set imgFile to file of parentImg
                            set end of filePaths to POSIX path of imgFile
                        on error
                            -- Skip variants without files
                        end try
                    end repeat
                    
                    -- Join paths with newline
                    set AppleScript's text item delimiters to linefeed
                    set pathString to filePaths as string
                    set AppleScript's text item delimiters to ""
                    
                    return pathString
                end tell
            on error errMsg number errNum
                return "ERROR:" & errMsg & " (code: " & errNum & ")"
            end try
        end tell
        """
        
        print("📂 Getting file paths of selected variants...")
        
        let result = try await executeAppleScript(script)
        
        // Check for errors
        if result.hasPrefix("ERROR:") {
            let errorMsg = result.replacingOccurrences(of: "ERROR:", with: "")
            throw CaptureOneError.scriptExecutionFailed(errorMsg)
        }
        
        // Parse paths
        let paths = result
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: $0) }
        
        print("✅ Found \(paths.count) file paths")
        
        return paths
    }
    
    /// Returns the export folder path and the count of variants being exported
    func exportSelectedVariants(recipeName: String = "Picflow Upload", outputFolder: URL) async throws -> (folder: URL, count: Int) {
        // Detect which Capture One is running
        guard let appInfo = detectCaptureOneApp() else {
            throw CaptureOneError.notRunning
        }
        
        // Double-check app is running
        let isStillRunning = NSWorkspace.shared.runningApplications.contains { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            return bundleId == appInfo.bundleId
        }
        
        guard isStillRunning else {
            detectedBundleId = nil
            detectedAppName = nil
            throw CaptureOneError.notRunning
        }
        
        // Ensure output folder exists
        try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
        
        // CRITICAL: Set document-level output property (required for catalogs)
        // Sessions have this implicitly set, but catalogs need it explicitly configured
        // This is the "default output location" for the catalog that all recipes validate against
        print("📁 Setting document-level output property...")
        let setOutputScript = """
        tell application "\(appInfo.appName)"
            try
                tell front document
                    set output to POSIX file "\(outputFolder.path)" as alias
                    return "OUTPUT_SET"
                end tell
            on error errMsg number errNum
                return "ERROR:" & errMsg & " (code: " & errNum & ")"
            end try
        end tell
        """
        
        let outputResult = try await executeAppleScript(setOutputScript)
        if outputResult == "OUTPUT_SET" {
            print("✅ Document output location set successfully")
        } else {
            print("⚠️ Could not set document output: \(outputResult)")
            // Continue anyway - sessions might not need/allow this
        }
        
        // Ensure recipe exists with correct output path
        // Only recreates if missing or has wrong path (preserves user customizations)
        print("📋 Setting up recipe '\(recipeName)'...")
        do {
            try await createOrRecreateRecipe(recipeName: recipeName, outputFolder: outputFolder)
            print("✅ Recipe is ready with output: \(outputFolder.path)")
        } catch {
            print("⚠️ Could not setup recipe automatically: \(error)")
            print("⚠️ Please manually check the '\(recipeName)' recipe in Capture One")
            print("⚠️ Make sure its output location is set to: \(outputFolder.path)")
            throw error // Don't continue if recipe setup failed
        }
        
        // AppleScript to process (export) selected variants using the recipe from the active catalog
        let script = """
        tell application "\(appInfo.appName)"
            try
                tell front document
                    set selectedVariants to (variants whose selected is true)
                    set variantCount to count of selectedVariants
                    
                    if variantCount is 0 then
                        return "ERROR:No variants selected"
                    end if
                    
                    -- Verify recipe exists before trying to use it
                    if not (exists recipe "\(recipeName)") then
                        return "ERROR:Recipe '\(recipeName)' not found. Please check if it was created correctly."
                    end if
                    
                    -- Process using recipe (Capture One's standard export command)
                    repeat with v in selectedVariants
                        process v recipe "\(recipeName)"
                    end repeat
                    
                    return "SUCCESS:" & variantCount
                end tell
            on error errMsg number errNum
                return "ERROR:" & errMsg & " (code: " & errNum & ")"
            end try
        end tell
        """
        
        print("🎬 Exporting with '\(appInfo.appName)' using recipe '\(recipeName)'")
        print("📁 Export destination: \(outputFolder.path)")
        
        do {
            let result = try await executeAppleScript(script)
            print("📋 Export script result: '\(result)'")
            print("📋 Export initiated for output: \(outputFolder.path)")
            
            if result.hasPrefix("ERROR:") {
                let errorMessage = String(result.dropFirst(6))
                print("❌ Export script returned error: \(errorMessage)")
                throw CaptureOneError.scriptExecutionFailed(errorMessage)
            } else if result.hasPrefix("SUCCESS:") {
                let countString = String(result.dropFirst(8))
                let exportedCount = Int(countString) ?? 0
                print("✅ Export command completed successfully")
                print("   - Variants exported: \(exportedCount)")
                print("   - Expected output folder: \(outputFolder.path)")
                print("   - App used: '\(appInfo.appName)'")
                return (folder: outputFolder, count: exportedCount)
            } else if result == "SUCCESS" {
                // Backwards compatibility - assume 1 variant if no count provided
                print("✅ Export command completed successfully (no count)")
                print("   - Expected output folder: \(outputFolder.path)")
                print("   - App used: '\(appInfo.appName)'")
                return (folder: outputFolder, count: 1)
            } else {
                print("⚠️ Unexpected export response: '\(result)'")
                print("⚠️ This might indicate an AppleScript version mismatch")
                throw CaptureOneError.scriptExecutionFailed("Unexpected response: \(result)")
            }
        } catch let error as CaptureOneError {
            print("❌ CaptureOne error during export: \(error)")
            print("   - App: '\(appInfo.appName)'")
            print("   - Bundle ID: \(appInfo.bundleId)")
            print("   - Output folder: \(outputFolder.path)")
            throw error
        } catch {
            print("❌ Unexpected error during export: \(error)")
            print("❌ Error type: \(type(of: error))")
            print("❌ Error details: \(error.localizedDescription)")
            throw CaptureOneError.scriptExecutionFailed("Export failed: \(error.localizedDescription)")
        }
    }
    
    /// Get the temporary export folder for Picflow
    static func getExportFolder() throws -> URL {
        // Use Application Support folder (hidden from user but accessible)
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CaptureOneError.scriptExecutionFailed("Could not access Application Support directory")
        }
        
        // Create Picflow subfolder
        let picflowFolder = appSupport.appendingPathComponent("Picflow", isDirectory: true)
        let exportsFolder = picflowFolder.appendingPathComponent("CaptureOneExports", isDirectory: true)
        
        // Create if doesn't exist
        try fileManager.createDirectory(at: exportsFolder, withIntermediateDirectories: true)
        
        return exportsFolder
    }
}

