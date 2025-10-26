//
//  SettingsManager.swift
//  Picflow
//
//  Manages app-wide settings and preferences
//

import Foundation
import ServiceManagement
import AppKit

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // MARK: - Settings Keys
    
    private enum Keys {
        static let showMenuBarIcon = "showMenuBarIcon"
        static let launchAtLogin = "launchAtLogin"
        static let autoUpdate = "autoUpdate"
    }
    
    // MARK: - Published Settings
    
    @Published var showMenuBarIcon: Bool {
        didSet {
            UserDefaults.standard.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon)
            menuBarIconDidChange(showMenuBarIcon)
        }
    }
    
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            setLaunchAtLogin(launchAtLogin)
        }
    }
    
    @Published var autoUpdate: Bool {
        didSet {
            UserDefaults.standard.set(autoUpdate, forKey: Keys.autoUpdate)
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load saved settings or use defaults
        self.showMenuBarIcon = UserDefaults.standard.object(forKey: Keys.showMenuBarIcon) as? Bool ?? true
        self.launchAtLogin = UserDefaults.standard.object(forKey: Keys.launchAtLogin) as? Bool ?? true
        self.autoUpdate = UserDefaults.standard.object(forKey: Keys.autoUpdate) as? Bool ?? true
    }
    
    // MARK: - Menu Bar Icon Management
    
    private var menuBarIconChangeHandler: ((Bool) -> Void)?
    
    func setMenuBarIconChangeHandler(_ handler: @escaping (Bool) -> Void) {
        self.menuBarIconChangeHandler = handler
    }
    
    private func menuBarIconDidChange(_ show: Bool) {
        menuBarIconChangeHandler?(show)
    }
    
    // MARK: - Launch at Login
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        // Requires macOS 13.0+
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            }
        } else {
            print("Launch at login requires macOS 13.0 or later")
        }
    }
    
    // MARK: - Logs Management
    
    static var logsDirectoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let picflowDir = appSupport.appendingPathComponent("Picflow", isDirectory: true)
        let logsDir = picflowDir.appendingPathComponent("Logs", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        
        return logsDir
    }
    
    func openLogsFolder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: Self.logsDirectoryURL.path)
    }
    
    func cleanOldLogs() {
        let logsDir = Self.logsDirectoryURL
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: logsDir, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }
        
        for file in files {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                  let creationDate = attributes[.creationDate] as? Date else {
                continue
            }
            
            if creationDate < sevenDaysAgo {
                try? FileManager.default.removeItem(at: file)
                print("🗑️ Deleted old log file: \(file.lastPathComponent)")
            }
        }
    }
}

