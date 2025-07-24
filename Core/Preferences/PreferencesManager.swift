import Foundation
import SwiftUI
import Translation

// MARK: - Centralized Preferences Manager
// Single source of truth for all app settings, accessible from menu bar

@MainActor
class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()
    
    // MARK: - Translation Settings
    @Published var translationMode: TranslationMode = .appleNative
    @Published var enableAppleNative: Bool = true
    @Published var fallbackToGemini: Bool = false  // Disabled by default for pure Apple testing
    @Published var geminiApiKey: String = ""
    
    // MARK: - AssemblyAI Settings
    @Published var assemblyAIApiKey: String = ""
    
    // MARK: - Audio Settings  
    @Published var audioMode: AudioMode = .mono
    @Published var transcriptionEngine: TranscriptionEngine = .whisper
    @Published var selectedInputDevice: String = "default"
    @Published var selectedOutputDevice: String = "default"
    @Published var enablePassthrough: Bool = false
    
    
    // MARK: - UI Settings
    @Published var enableCompactMode: Bool = false
    @Published var showFloatingWindows: Bool = true
    @Published var enableAnimations: Bool = true   // Default ON for smooth animations
    @Published var wordStreamingSpeed: String? = "default"  // Word-by-word animation speed
    
    // MARK: - Debug Settings (v1.1.0)
    @Published var enableDebugMode: Bool = false
    
    // MARK: - Apple Translation Download Status
    @Published var appleTranslationDownloadStatus: String = "Ready to download"
    @Published var isDownloadingAppleLanguages: Bool = false
    @Published var selectedAppleLanguages: Set<String> = ["en", "es", "zh", "th"] // Default core languages
    
    private let userDefaults = UserDefaults.standard
    
    private init() {
        loadSettings()
        print("🔧 PreferencesManager initialized - centralized settings")
    }
    
    // MARK: - Settings Persistence
    
    private func loadSettings() {
        translationMode = TranslationMode(rawValue: userDefaults.string(forKey: "translationMode") ?? "") ?? .appleNative
        enableAppleNative = userDefaults.object(forKey: "enableAppleNative") as? Bool ?? true
        fallbackToGemini = userDefaults.object(forKey: "fallbackToGemini") as? Bool ?? false
        geminiApiKey = userDefaults.string(forKey: "geminiApiKey") ?? ""
        
        assemblyAIApiKey = userDefaults.string(forKey: "assemblyAIApiKey") ?? ""
        
        audioMode = AudioMode(rawValue: userDefaults.string(forKey: "audioMode") ?? "") ?? .mono
        transcriptionEngine = TranscriptionEngine(rawValue: userDefaults.string(forKey: "transcriptionEngine") ?? "") ?? .whisper
        selectedInputDevice = userDefaults.string(forKey: "selectedInputDevice") ?? "default"
        selectedOutputDevice = userDefaults.string(forKey: "selectedOutputDevice") ?? "default"
        enablePassthrough = userDefaults.bool(forKey: "enablePassthrough")
        
        
        enableCompactMode = userDefaults.bool(forKey: "enableCompactMode")
        showFloatingWindows = userDefaults.bool(forKey: "showFloatingWindows")
        enableAnimations = userDefaults.bool(forKey: "enableAnimations")
        wordStreamingSpeed = userDefaults.string(forKey: "wordStreamingSpeed") ?? "default"
        
        // Debug Settings
        enableDebugMode = userDefaults.bool(forKey: "enableDebugMode")
        
        // Load selected Apple languages
        if let savedLanguages = userDefaults.array(forKey: "selectedAppleLanguages") as? [String] {
            selectedAppleLanguages = Set(savedLanguages)
        }
        
        print("✅ Preferences loaded from UserDefaults")
    }
    
    func saveSettings() {
        userDefaults.set(translationMode.rawValue, forKey: "translationMode")
        userDefaults.set(enableAppleNative, forKey: "enableAppleNative")
        userDefaults.set(fallbackToGemini, forKey: "fallbackToGemini")
        userDefaults.set(geminiApiKey, forKey: "geminiApiKey")
        
        userDefaults.set(assemblyAIApiKey, forKey: "assemblyAIApiKey")
        
        userDefaults.set(audioMode.rawValue, forKey: "audioMode")
        userDefaults.set(transcriptionEngine.rawValue, forKey: "transcriptionEngine")
        userDefaults.set(selectedInputDevice, forKey: "selectedInputDevice")
        userDefaults.set(selectedOutputDevice, forKey: "selectedOutputDevice")
        userDefaults.set(enablePassthrough, forKey: "enablePassthrough")
        
        
        userDefaults.set(enableCompactMode, forKey: "enableCompactMode")
        userDefaults.set(showFloatingWindows, forKey: "showFloatingWindows")
        userDefaults.set(enableAnimations, forKey: "enableAnimations")
        userDefaults.set(wordStreamingSpeed, forKey: "wordStreamingSpeed")
        
        // Debug Settings
        userDefaults.set(enableDebugMode, forKey: "enableDebugMode")
        
        // Save selected Apple languages
        userDefaults.set(Array(selectedAppleLanguages), forKey: "selectedAppleLanguages")
        
        print("💾 Preferences saved to UserDefaults")
    }
    
    // MARK: - Apple Translation Integration
    
    func downloadAppleLanguages() async {
        guard enableAppleNative else {
            appleTranslationDownloadStatus = "Apple Translation disabled"
            return
        }
        
        guard !selectedAppleLanguages.isEmpty else {
            appleTranslationDownloadStatus = "❌ No languages selected"
            return
        }
        
        if #available(macOS 15.0, *) {
            print("🍎 Starting Apple Translation download for \(selectedAppleLanguages.count) languages...")
            
            // Trigger download via the AppleTranslationIntegration view
            // The actual download happens in the PreferencesAppleTranslationView using .translationTask
            print("🍎 Starting Apple Translation download from Preferences...")
            
            appleTranslationDownloadStatus = "Starting download for \(selectedAppleLanguages.count) languages..."
            
            // Set downloading flag - this triggers the AppleTranslationIntegration
            isDownloadingAppleLanguages = true
            
            print("🍎 Apple Translation download triggered from Preferences")
                
        } else {
            appleTranslationDownloadStatus = "❌ Requires macOS 15.0+"
        }
        
        print("🍎 Apple Translation download completed")
    }
    
    // MARK: - Settings Validation
    
    var isGeminiConfigured: Bool {
        !geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var isAssemblyAIConfigured: Bool {
        !assemblyAIApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var canUseAppleTranslation: Bool {
        if #available(macOS 15.0, *) {
            return enableAppleNative
        }
        return false
    }
    
    var effectiveTranslationMode: TranslationMode {
        if canUseAppleTranslation && translationMode == .appleNative {
            return .appleNative
        } else if isGeminiConfigured {
            return .geminiAPI
        } else {
            return .appleNative // Fallback, will show error in UI
        }
    }
    
    // MARK: - Apple Translation Service Access
    @available(macOS 15.0, *)
    func getAppleTranslationService() -> AppleTranslationService? {
        // Access the shared translation service from app state
        // This is a temporary solution - ideally we'd inject this dependency
        return nil // TODO: Get from app state or dependency injection
    }
}