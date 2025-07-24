import Foundation
import SwiftUI
import AppKit

class WindowConfigurationManager: ObservableObject {
    private let userDefaults = UserDefaults.standard
    private let windowConfigsKey = "PrezefrenWindowConfigurations"
    private let quickTemplatesKey = "PrezefrenQuickTemplates"
    
    static let shared = WindowConfigurationManager()
    
    private init() {}
    
    // MARK: - Window Configuration Persistence
    
    func saveWindowConfigurations(_ windows: [SubtitleWindow]) {
        do {
            let data = try JSONEncoder().encode(windows)
            userDefaults.set(data, forKey: windowConfigsKey)
            print("💾 Saved \(windows.count) window configurations")
        } catch {
            print("❌ Failed to save window configurations: \(error)")
        }
    }
    
    func loadWindowConfigurations() -> [SubtitleWindow] {
        guard let data = userDefaults.data(forKey: windowConfigsKey) else {
            print("📂 No saved window configurations found")
            return []
        }
        
        do {
            let windows = try JSONDecoder().decode([SubtitleWindow].self, from: data)
            print("📂 Loaded \(windows.count) window configurations")
            return windows
        } catch {
            print("❌ Failed to load window configurations: \(error)")
            return []
        }
    }
    
    // MARK: - Quick Template Presets
    
    func createQuickTemplate(name: String, windows: [SubtitleWindow]) {
        var templates = loadQuickTemplates()
        templates[name] = windows
        saveQuickTemplates(templates)
    }
    
    func loadQuickTemplate(name: String) -> [SubtitleWindow]? {
        let templates = loadQuickTemplates()
        return templates[name]
    }
    
    func getAvailableTemplates() -> [String] {
        return Array(loadQuickTemplates().keys).sorted()
    }
    
    func deleteQuickTemplate(name: String) {
        var templates = loadQuickTemplates()
        templates.removeValue(forKey: name)
        saveQuickTemplates(templates)
    }
    
    private func saveQuickTemplates(_ templates: [String: [SubtitleWindow]]) {
        do {
            let data = try JSONEncoder().encode(templates)
            userDefaults.set(data, forKey: quickTemplatesKey)
        } catch {
            print("❌ Failed to save quick templates: \(error)")
        }
    }
    
    private func loadQuickTemplates() -> [String: [SubtitleWindow]] {
        guard let data = userDefaults.data(forKey: quickTemplatesKey) else {
            return [:]
        }
        
        do {
            return try JSONDecoder().decode([String: [SubtitleWindow]].self, from: data)
        } catch {
            print("❌ Failed to load quick templates: \(error)")
            return [:]
        }
    }
    
    // MARK: - Built-in Template Presets
    
    func createBuiltInTemplates() -> [String: [SubtitleWindow]] {
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        
        return [
            "Presentation Mode": [
                SubtitleWindow(name: "Main Subtitles", isAdditive: false, template: .centerStage, screenSize: screenSize)
            ],
            "Multi-Language Setup": [
                SubtitleWindow(name: "English", isAdditive: true, template: .topBanner, screenSize: screenSize),
                SubtitleWindow(name: "Spanish", isAdditive: true, template: .sidePanel, screenSize: screenSize)
            ],
            "Picture-in-Picture": [
                SubtitleWindow(name: "Compact View", isAdditive: false, template: .pictureInPicture, screenSize: screenSize)
            ],
            "Full Coverage": [
                SubtitleWindow(name: "Top Banner", isAdditive: true, template: .topBanner, screenSize: screenSize),
                SubtitleWindow(name: "Side Panel", isAdditive: false, template: .sidePanel, screenSize: screenSize),
                SubtitleWindow(name: "PiP Corner", isAdditive: false, template: .pictureInPicture, screenSize: screenSize)
            ]
        ]
    }
    
    // MARK: - Window Position Utilities
    
    func adjustWindowPositionsForScreen(_ windows: [SubtitleWindow]) -> [SubtitleWindow] {
        guard let screenSize = NSScreen.main?.frame.size else { return windows }
        
        return windows.map { window in
            var adjustedWindow = window
            
            // Ensure window is within screen bounds
            let maxX = screenSize.width - window.size.width
            let maxY = screenSize.height - window.size.height
            
            adjustedWindow.position.x = max(0, min(window.position.x, maxX))
            adjustedWindow.position.y = max(0, min(window.position.y, maxY))
            
            return adjustedWindow
        }
    }
    
    // MARK: - Batch Operations
    
    func showAllWindows(_ windows: inout [SubtitleWindow]) {
        for i in windows.indices {
            windows[i].isVisible = true
        }
    }
    
    func hideAllWindows(_ windows: inout [SubtitleWindow]) {
        for i in windows.indices {
            windows[i].isVisible = false
        }
    }
    
    func resetWindowPositions(_ windows: inout [SubtitleWindow]) {
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        
        for i in windows.indices {
            let template = windows[i].template
            let defaultFrame = template.defaultFrame(for: screenSize)
            windows[i].position = defaultFrame.origin
            windows[i].size = defaultFrame.size
        }
    }
    
    func applyTemplateToWindows(_ windows: inout [SubtitleWindow], template: WindowTemplate) {
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        
        for i in windows.indices {
            windows[i].template = template
            let defaultFrame = template.defaultFrame(for: screenSize)
            windows[i].position = defaultFrame.origin
            windows[i].size = defaultFrame.size
            windows[i].opacity = template.defaultOpacity
            windows[i].fontSize = template.defaultFontSize
        }
    }
    
    // MARK: - Export/Import
    
    func exportConfiguration(_ windows: [SubtitleWindow]) -> String? {
        do {
            let data = try JSONEncoder().encode(windows)
            return data.base64EncodedString()
        } catch {
            print("❌ Failed to export configuration: \(error)")
            return nil
        }
    }
    
    func importConfiguration(from base64String: String) -> [SubtitleWindow]? {
        guard let data = Data(base64Encoded: base64String) else {
            print("❌ Invalid base64 configuration string")
            return nil
        }
        
        do {
            return try JSONDecoder().decode([SubtitleWindow].self, from: data)
        } catch {
            print("❌ Failed to import configuration: \(error)")
            return nil
        }
    }
}