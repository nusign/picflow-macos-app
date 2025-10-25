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
                return (cachedId, cachedName)
            } else {
                // App quit, clear cache
                detectedBundleId = nil
                detectedAppName = nil
            }
        }
        
        let runningApps = NSWorkspace.shared.runningApplications
        
        // Try to find Capture One by bundle identifier
        let captureOneApp = runningApps.first { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            return bundleId.contains("captureone") || bundleId.contains("phaseone")
        }
        
        guard let app = captureOneApp,
              let bundleId = app.bundleIdentifier,
              let appName = app.localizedName else {
            return nil
        }
        
        detectedBundleId = bundleId
        detectedAppName = appName
        print("✅ Found: '\(appName)' (bundle ID: \(bundleId))")
        return (bundleId, appName)
    }
    
    /// Get the current selection from Capture One
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
        
        // AppleScript to get selection count and details
        // Using single-line format that works in Terminal
        let script = """
        tell application "\(appInfo.appName)" to tell document 1 to return (count of (variants whose selected is true))
        """
        
        // MORE COMPLEX VERSION WITH DATA (disabled for now)
        let _ = """
        tell application "\(appInfo.appName)"
            try
                set selectedVariants to (get variants whose selected is true)
                set selectionCount to count of selectedVariants
                
                if selectionCount is 0 then
                    return "0"
                end if
                
                -- Build result with selection data
                set resultList to {}
                
                repeat with v in selectedVariants
                    set variantData to {}
                    
                    -- Basic info
                    try
                        set end of variantData to "NAME:" & (name of v as text)
                    on error
                        set end of variantData to "NAME:Unknown"
                    end try
                    
                    try
                        set end of variantData to "ID:" & (id of v as text)
                    on error
                        set end of variantData to "ID:unknown"
                    end try
                    
                    -- Rating
                    try
                        set end of variantData to "RATING:" & (rating of v as text)
                    on error
                        set end of variantData to "RATING:-1"
                    end try
                    
                    -- Color tag
                    try
                        set end of variantData to "COLORTAG:" & (color tag of v as text)
                    on error
                        set end of variantData to "COLORTAG:-1"
                    end try
                    
                    -- File path (from parent image)
                    try
                        set parentImg to parent image of v
                        set imgFile to file of parentImg
                        set end of variantData to "FILE:" & (POSIX path of imgFile)
                    on error
                        set end of variantData to "FILE:"
                    end try
                    
                    -- Crop dimensions
                    try
                        set end of variantData to "CROPWIDTH:" & (crop width of v as text)
                    on error
                        set end of variantData to "CROPWIDTH:-1"
                    end try
                    
                    try
                        set end of variantData to "CROPHEIGHT:" & (crop height of v as text)
                    on error
                        set end of variantData to "CROPHEIGHT:-1"
                    end try
                    
                    -- EXIF from parent image
                    try
                        set parentImg to parent image of v
                        set end of variantData to "CAMERAMAKE:" & (EXIF camera make of parentImg as text)
                    on error
                        set end of variantData to "CAMERAMAKE:"
                    end try
                    
                    try
                        set parentImg to parent image of v
                        set end of variantData to "CAMERAMODEL:" & (EXIF camera model of parentImg as text)
                    on error
                        set end of variantData to "CAMERAMODEL:"
                    end try
                    
                    try
                        set parentImg to parent image of v
                        set end of variantData to "ISO:" & (EXIF ISO of parentImg as text)
                    on error
                        set end of variantData to "ISO:"
                    end try
                    
                    try
                        set parentImg to parent image of v
                        set end of variantData to "SHUTTER:" & (EXIF shutter speed of parentImg as text)
                    on error
                        set end of variantData to "SHUTTER:"
                    end try
                    
                    try
                        set parentImg to parent image of v
                        set end of variantData to "APERTURE:" & (EXIF aperture of parentImg as text)
                    on error
                        set end of variantData to "APERTURE:"
                    end try
                    
                    try
                        set parentImg to parent image of v
                        set end of variantData to "FOCAL:" & (EXIF focal length of parentImg as text)
                    on error
                        set end of variantData to "FOCAL:"
                    end try
                    
                    -- Join variant data with delimiter
                    set variantString to my joinList(variantData, "|")
                    set end of resultList to variantString
                end repeat
                
                -- Join all variants with double delimiter
                return my joinList(resultList, "||")
            on error errMsg number errNum
                -- Check if it's because there's no document/session open
                if errNum is -1728 or errMsg contains "document" or errMsg contains "object" then
                    return "NO_DOCUMENT"
                else
                    return "ERROR_IN_SCRIPT:" & errMsg & ":" & errNum
                end if
            end try
        end tell
        
        on joinList(theList, theDelimiter)
            set oldDelimiters to AppleScript's text item delimiters
            set AppleScript's text item delimiters to theDelimiter
            set theString to theList as string
            set AppleScript's text item delimiters to oldDelimiters
            return theString
        end joinList
        """
        
        // Execute AppleScript
        let result = try await executeAppleScript(script)
        
        // Parse result - should be just a number
        if let count = Int(result) {
            return CaptureOneSelection(count: count, variants: [])
        }
        
        // If not a number, it's an error or unexpected
        throw CaptureOneError.scriptExecutionFailed(result)
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
    
    /// Parse the variant data string into CaptureOneVariant objects
    private func parseVariantData(_ data: String) throws -> [CaptureOneVariant] {
        let variantStrings = data.components(separatedBy: "||")
        var variants: [CaptureOneVariant] = []
        
        for variantString in variantStrings {
            guard !variantString.isEmpty else { continue }
            
            let fields = variantString.components(separatedBy: "|")
            var fieldDict: [String: String] = [:]
            
            for field in fields {
                let parts = field.components(separatedBy: ":")
                if parts.count >= 2 {
                    let key = parts[0]
                    let value = parts.dropFirst().joined(separator: ":")
                    fieldDict[key] = value
                }
            }
            
            let variant = CaptureOneVariant(
                id: fieldDict["ID"] ?? UUID().uuidString,
                name: fieldDict["NAME"] ?? "Unknown",
                rating: Int(fieldDict["RATING"] ?? "-1").flatMap { $0 >= 0 ? $0 : nil },
                colorTag: Int(fieldDict["COLORTAG"] ?? "-1").flatMap { $0 >= 0 ? $0 : nil },
                filePath: fieldDict["FILE"]?.isEmpty == false ? fieldDict["FILE"] : nil,
                cropWidth: Int(fieldDict["CROPWIDTH"] ?? "-1").flatMap { $0 >= 0 ? $0 : nil },
                cropHeight: Int(fieldDict["CROPHEIGHT"] ?? "-1").flatMap { $0 >= 0 ? $0 : nil },
                cameraMake: fieldDict["CAMERAMAKE"]?.isEmpty == false ? fieldDict["CAMERAMAKE"] : nil,
                cameraModel: fieldDict["CAMERAMODEL"]?.isEmpty == false ? fieldDict["CAMERAMODEL"] : nil,
                iso: fieldDict["ISO"]?.isEmpty == false ? fieldDict["ISO"] : nil,
                shutterSpeed: fieldDict["SHUTTER"]?.isEmpty == false ? fieldDict["SHUTTER"] : nil,
                aperture: fieldDict["APERTURE"]?.isEmpty == false ? fieldDict["APERTURE"] : nil,
                focalLength: fieldDict["FOCAL"]?.isEmpty == false ? fieldDict["FOCAL"] : nil,
                captureDate: nil // Would need date parsing
            )
            
            variants.append(variant)
        }
        
        return variants
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
        
        // Delete existing recipe
        let deleteScript = """
        tell application "\(appInfo.appName)"
            try
                tell document 1
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
        
        // Create new recipe with correct settings
        let createScript = """
        tell application "\(appInfo.appName)"
            try
                tell document 1
                    -- Create new recipe
                    set newRecipe to make new recipe with properties {name:"\(recipeName)"}
                    
                    -- Convert path to alias (required for custom location to work)
                    set exportPath to POSIX file "\(outputFolder.path)" as alias
                    
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
        
        let createResult = try await executeAppleScript(createScript)
        
        if createResult.hasPrefix("ERROR:") {
            let errorMsg = String(createResult.dropFirst(6))
            throw CaptureOneError.scriptExecutionFailed("Failed to create recipe: \(errorMsg)")
        } else if createResult == "SUCCESS" {
            print("✅ Created recipe '\(recipeName)' with output: \(outputFolder.path)")
            print("ℹ️  You can customize quality, watermarks, and metadata in Capture One")
        }
    }
    
    /// Ensures recipe exists - only creates if missing (respects user customization)
    /// We cannot read or update existing recipe settings due to AppleScript limitations
    /// - Parameters:
    ///   - recipeName: Name of the recipe
    ///   - outputFolder: Desired output folder
    /// - Throws: CaptureOneError if creation fails
    private func createOrRecreateRecipe(recipeName: String, outputFolder: URL) async throws {
        guard let appInfo = detectCaptureOneApp() else {
            throw CaptureOneError.notRunning
        }
        
        // Check if recipe already exists
        let checkScript = """
        tell application "\(appInfo.appName)"
            try
                tell document 1
                    if (exists recipe "\(recipeName)") then
                        return "EXISTS"
                    else
                        return "NOT_EXISTS"
                    end if
                end tell
            on error errMsg number errNum
                return "ERROR:" & errMsg & " (code: " & errNum & ")"
            end try
        end tell
        """
        
        let checkResult = try await executeAppleScript(checkScript)
        
        if checkResult == "EXISTS" {
            print("✅ Recipe '\(recipeName)' already exists (using existing settings)")
            print("ℹ️  If export fails, please check the recipe's output location in Capture One:")
            print("    Expected: \(outputFolder.path)")
            return // Don't recreate - respect user's custom settings
        } else if checkResult == "NOT_EXISTS" {
            print("ℹ️  Recipe '\(recipeName)' doesn't exist, creating...")
        } else if checkResult.hasPrefix("ERROR:") {
            print("⚠️  Could not check recipe: \(checkResult)")
            // Continue anyway - try to create it
        }
        
        // Create new recipe with default settings
        let createScript = """
        tell application "\(appInfo.appName)"
            try
                tell document 1
                    -- Create new recipe
                    set newRecipe to make new recipe with properties {name:"\(recipeName)"}
                    
                    -- Convert path to alias (required for custom location to work)
                    set exportPath to POSIX file "\(outputFolder.path)" as alias
                    
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
        
        let createResult = try await executeAppleScript(createScript)
        
        if createResult.hasPrefix("ERROR:") {
            let errorMsg = String(createResult.dropFirst(6))
            throw CaptureOneError.scriptExecutionFailed("Failed to create recipe: \(errorMsg)")
        } else if createResult == "SUCCESS" {
            print("✅ Created recipe '\(recipeName)' with output: \(outputFolder.path)")
            print("ℹ️  You can customize quality, watermarks, and metadata in Capture One")
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
        
        // AppleScript to get file paths of selected variants
        let script = """
        tell application "\(appInfo.appName)"
            try
                tell document 1
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
        
        // Try to create/recreate the recipe with correct settings
        // Note: We can't read or update existing recipes due to AppleScript limitations
        print("📋 Setting up recipe '\(recipeName)'...")
        do {
            try await createOrRecreateRecipe(recipeName: recipeName, outputFolder: outputFolder)
            print("✅ Recipe is ready with output: \(outputFolder.path)")
        } catch {
            print("⚠️ Could not setup recipe automatically: \(error)")
            print("⚠️ Please manually check the '\(recipeName)' recipe in Capture One")
            print("⚠️ Make sure its output location is set to: \(outputFolder.path)")
            // Continue anyway - maybe the recipe is already correct
        }
        
        // AppleScript to process (export) selected variants using the recipe
        let script = """
        tell application "\(appInfo.appName)"
            try
                tell document 1
                    set selectedVariants to (variants whose selected is true)
                    set variantCount to count of selectedVariants
                    
                    if variantCount is 0 then
                        return "ERROR:No variants selected"
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
        
        print("🎬 Exporting using '\(recipeName)' recipe to: \(outputFolder.path)")
        
        do {
            let result = try await executeAppleScript(script)
            print("📋 Export result: \(result)")
            
            if result.hasPrefix("ERROR:") {
                let errorMessage = String(result.dropFirst(6))
                print("❌ Export script error: \(errorMessage)")
                throw CaptureOneError.scriptExecutionFailed(errorMessage)
            } else if result.hasPrefix("SUCCESS:") {
                let countString = String(result.dropFirst(8))
                let exportedCount = Int(countString) ?? 0
                print("✅ Export command completed successfully - exported \(exportedCount) variants")
                return (folder: outputFolder, count: exportedCount)
            } else if result == "SUCCESS" {
                // Backwards compatibility - assume 1 variant if no count provided
                print("✅ Export command completed successfully")
                return (folder: outputFolder, count: 1)
            } else {
                print("⚠️ Unexpected export response: \(result)")
                throw CaptureOneError.scriptExecutionFailed("Unexpected response: \(result)")
            }
        } catch let error as CaptureOneError {
            print("❌ CaptureOne error during export: \(error)")
            throw error
        } catch {
            print("❌ Unexpected error during export: \(error)")
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

