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
    
    enum CaptureOneError: Error {
        case notRunning
        case scriptExecutionFailed(String)
        case noDocument
        case parseError
        case permissionDenied
    }
    
    // Cache the detected app info
    private var detectedBundleId: String?
    private var detectedAppName: String?
    
    /// Detect the running Capture One app bundle identifier and name
    private func detectCaptureOneApp() -> (bundleId: String, appName: String)? {
        if let cachedId = detectedBundleId, let cachedName = detectedAppName {
            return (cachedId, cachedName)
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
        
        // Ready to access Capture One
        
        // AppleScript to get selection count and details
        // Using single-line format that works in Terminal
        let script = """
        tell application "\(appInfo.appName)" to tell document 1 to return (count of (variants whose selected is true))
        """
        
        // MORE COMPLEX VERSION WITH DATA (disabled for now)
        let complexScript = """
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
                        
                        // Check for permission errors (-600, -1743, -1728)
                        if errorMessage.contains("(-600)") || errorMessage.contains("(-1743)") || 
                           errorMessage.contains("(-1728)") || errorMessage.contains("not allowed") || 
                           errorMessage.contains("permission") {
                            continuation.resume(throwing: CaptureOneError.permissionDenied)
                        } else {
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
}

