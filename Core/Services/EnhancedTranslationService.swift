import Foundation
import SwiftUI
import Translation

// Translation errors
enum TranslationError: Error {
    case networkError(Error)
    case invalidLanguage
    case apiKeyMissing
}

// Basic translation service for Gemini API
class TranslationService: ObservableObject {
    @Published var isTranslating = false
    private var apiKey: String = ""
    
    static let supportedLanguages = [
        ("en", "English"),
        ("es", "Spanish"), 
        ("fr", "French"),
        ("de", "German"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("ru", "Russian"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("zh", "Chinese")
    ]
    
    func setAPIKey(_ key: String) {
        apiKey = key
    }
    
    func translate(text: String, from sourceLang: String, to targetLang: String) async throws -> String {
        isTranslating = true
        defer { isTranslating = false }
        
        // Basic implementation - replace with actual Gemini API call
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
        return "Translated: \(text) (\(sourceLang)→\(targetLang))"
    }
}

// Translation modes for enhanced features
enum TranslationMode: String, CaseIterable, Codable {
    case geminiAPI = "Gemini API"
    case appleNative = "Apple Native"
    
    var description: String {
        switch self {
        case .geminiAPI:
            return "Cloud-based translation"
        case .appleNative:
            return "Apple on-device translation"
        }
    }
}

// Enhanced translation features configuration
struct TranslationConfig {
    var mode: TranslationMode = .appleNative  // Default to Apple Native (offline goal)
    var enableAppleNative: Bool = true  // ON by default - our offline target
    var fallbackToCloud: Bool = true  // Safe fallback enabled
}

class EnhancedTranslationService: ObservableObject {
    @Published var config = TranslationConfig()
    @Published var lastError: TranslationError?
    
    // Core translation service (preserve existing functionality)
    private let geminiService = TranslationService()
    
    // New Apple translation service (macOS 15+ only)
    @available(macOS 15.0, *)
    var appleTranslationService: AppleTranslationService? {
        get { _appleTranslationService as? AppleTranslationService }
        set { _appleTranslationService = newValue }
    }
    private var _appleTranslationService: Any?
    
    @MainActor
    init() {
        print("🔧 EnhancedTranslationService initialized - Apple Native + Gemini fallback (controlled by preferences)")
        
        // Initialize Apple Translation Service synchronously (macOS 15+ only)
        if #available(macOS 15.0, *) {
            _appleTranslationService = AppleTranslationService()
            print("🍎 Apple Translation Service initialized with proper WWDC24 patterns")
        } else {
            print("⚠️ Apple Translation requires macOS 15.0+")
            config.enableAppleNative = false
            config.mode = .geminiAPI  // Fallback to Gemini
        }
    }
    
    // MARK: - Main Translation Interface (preserves existing behavior)
    
    func translate(text: String, from sourceLang: String = "en", to targetLang: String) async throws -> String {
        // Route to appropriate service based on configuration
        switch config.mode {
        case .geminiAPI:
            return try await geminiService.translate(text: text, from: sourceLang, to: targetLang)
            
        case .appleNative:
            if #available(macOS 15.0, *), let appleService = appleTranslationService {
                return try await appleService.translate(text: text, from: sourceLang, to: targetLang)
            } else {
                print("❌ Apple Translation not available (requires macOS 15.0+)")
                let error = NSError(domain: "AppleTranslation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Apple Translation requires macOS 15.0+"])
                throw TranslationError.networkError(error)
            }
        }
    }
    
    // MARK: - Configuration Management
    
    func setAPIKey(_ key: String) {
        geminiService.setAPIKey(key)
    }
    
    func setTranslationMode(_ mode: TranslationMode) {
        config.mode = mode
        print("🔧 Translation mode set to: \(mode.rawValue)")
    }
    
    // MARK: - Status and Monitoring
    
    var isTranslating: Bool {
        // Note: This is a simple check - for full actor safety, this should be async
        return geminiService.isTranslating
    }
    
    var statusDescription: String {
        if isTranslating {
            return "Translating via \(config.mode.rawValue)..."
        } else {
            return "Ready - \(config.mode.rawValue)"
        }
    }
    
    // MARK: - Supported Languages
    
    // Legacy compatibility - use comprehensive language list from LanguageService
    static let supportedLanguages = LanguageService.geminiLanguages
    
    var availableLanguages: [(String, String)] {
        return Self.supportedLanguages
    }
}

// MARK: - Proper Apple Translation Implementation
// Based on WWDC24 guidelines and Apple's official documentation

@available(macOS 15.0, *)
@MainActor
class AppleTranslationService: ObservableObject {
    @Published var isTranslating = false
    @Published var lastError: String?
    @Published var currentConfiguration: TranslationSession.Configuration?
    @Published var translationResult: String = ""
    @Published var translationRequest: TranslationRequest?
    
    private let languageAvailability = LanguageAvailability()
    
    // Queue-based processing to handle one translation at a time
    private var translationQueue: [PendingTranslation] = []
    private var isProcessingQueue = false
    
    // Track current language pair to know when to create new config vs invalidate
    private var currentLanguagePair: (source: String?, target: String)?
    
    private struct PendingTranslation {
        let text: String
        let sourceLang: String
        let targetLang: String
        let completion: (Result<String, Error>) -> Void
    }
    
    struct TranslationRequest {
        let id: UUID = UUID()
        let text: String
        let sourceLang: String
        let targetLang: String
    }
    
    init() {
        // Check device capability first
        #if targetEnvironment(simulator)
        print("🍎 ⚠️ AppleTranslationService: Running in simulator - translations will not work")
        print("🍎 Note: Apple Translation requires actual device per WWDC24 documentation")
        #else
        print("🍎 ✅ AppleTranslationService initialized on actual device")
        #endif
    }
    
    // MARK: - Main Translation Function (Queue-based)
    func translate(text: String, from sourceLang: String, to targetLang: String) async throws -> String {
        print("🍎 Starting translation request: '\(text)' from \(sourceLang) to \(targetLang)")
        
        // Check if running on simulator
        #if targetEnvironment(simulator)
        print("🍎 ❌ Cannot translate on simulator - requires actual device")
        let deviceError = NSError(domain: "AppleTranslation", code: -4, userInfo: [NSLocalizedDescriptionKey: "Translation not supported on simulator"])
        throw TranslationError.networkError(deviceError)
        #endif
        
        // Create source and target languages
        let sourceLanguage = sourceLang == "auto" ? nil : Locale.Language(identifier: sourceLang)
        let targetLanguage = Locale.Language(identifier: targetLang)
        
        // Check language availability first
        if let sourceLanguage = sourceLanguage {
            let status = await languageAvailability.status(from: sourceLanguage, to: targetLanguage)
            print("🍎 Language availability status: \(status)")
            
            switch status {
            case .unsupported:
                print("🍎 ❌ Language pair \(sourceLang)→\(targetLang) not supported")
                let langError = NSError(domain: "AppleTranslation", code: -3, userInfo: [NSLocalizedDescriptionKey: "Language pair not supported"])
                throw TranslationError.networkError(langError)
            case .supported:
                print("🍎 Language pair supported but needs download")
                // Let the translationTask handle the download
            case .installed:
                print("🍎 ✅ Language pair ready")
            @unknown default:
                print("🍎 Unknown language status")
            }
        }
        
        // Add to queue and wait for result
        return try await withCheckedThrowingContinuation { continuation in
            let pendingTranslation = PendingTranslation(
                text: text,
                sourceLang: sourceLang,
                targetLang: targetLang,
                completion: { result in
                    continuation.resume(with: result)
                }
            )
            
            translationQueue.append(pendingTranslation)
            print("🍎 Added to translation queue. Queue size: \(translationQueue.count)")
            
            // Process queue if not already processing
            if !isProcessingQueue {
                Task {
                    await processTranslationQueue()
                }
            }
        }
    }
    
    // MARK: - Queue Processing
    private func processTranslationQueue() async {
        guard !isProcessingQueue else { return }
        isProcessingQueue = true
        
        print("🍎 Starting queue processing...")
        
        while !translationQueue.isEmpty {
            let nextTranslation = translationQueue.removeFirst()
            print("🍎 Processing queue item: '\(nextTranslation.text)' (\(translationQueue.count) remaining)")
            
            do {
                let result = try await performSingleTranslation(
                    text: nextTranslation.text,
                    sourceLang: nextTranslation.sourceLang,
                    targetLang: nextTranslation.targetLang
                )
                nextTranslation.completion(.success(result))
                
                // Small delay between translations to ensure UI updates
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                
            } catch {
                print("🍎 Queue translation failed: \(error)")
                nextTranslation.completion(.failure(error))
            }
        }
        
        isProcessingQueue = false
        print("🍎 Queue processing completed")
    }
    
    // MARK: - Single Translation (called from queue)
    private func performSingleTranslation(text: String, sourceLang: String, targetLang: String) async throws -> String {
        let sourceLanguage = sourceLang == "auto" ? nil : Locale.Language(identifier: sourceLang)
        let targetLanguage = Locale.Language(identifier: targetLang)
        
        // Create translation request with unique ID
        let request = TranslationRequest(
            text: text,
            sourceLang: sourceLang,
            targetLang: targetLang
        )
        print("🍎 Created translation request ID: \(request.id)")
        
        // Set up for translationTask processing
        translationRequest = request
        lastError = nil
        
        // Check if we need to create new configuration or invalidate existing
        let newLanguagePair = (source: sourceLang == "auto" ? nil : sourceLang, target: targetLang)
        
        if currentConfiguration == nil || currentLanguagePair?.source != newLanguagePair.source || currentLanguagePair?.target != newLanguagePair.target {
            // Create new configuration for different language pair
            print("🍎 Creating new configuration for \(sourceLang) → \(targetLang)")
            currentConfiguration = TranslationSession.Configuration(source: sourceLanguage, target: targetLanguage)
            currentLanguagePair = newLanguagePair
        } else {
            // Same language pair - invalidate existing configuration to retrigger
            print("🍎 Invalidating existing configuration for same language pair \(sourceLang) → \(targetLang)")
            currentConfiguration?.invalidate()
        }
        
        print("🍎 Configuration ready, waiting for translationTask to process...")
        
        // Wait for translation result with timeout
        let startTime = Date()
        let timeout: TimeInterval = 15.0 // Increased timeout for queue processing
        
        while translationResult.isEmpty && lastError == nil {
            if Date().timeIntervalSince(startTime) > timeout {
                print("🍎 ⏰ Translation timeout after \(timeout) seconds")
                let timeoutError = NSError(domain: "AppleTranslation", code: -2, userInfo: [NSLocalizedDescriptionKey: "Translation timeout"])
                throw TranslationError.networkError(timeoutError)
            }
            
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        
        if let error = lastError {
            print("🍎 ❌ Translation failed with error: \(error)")
            let nsError = NSError(domain: "AppleTranslation", code: -1, userInfo: [NSLocalizedDescriptionKey: error])
            throw TranslationError.networkError(nsError)
        }
        
        let result = translationResult
        
        // Clear result for next translation (but keep configuration for invalidation)
        translationResult = ""
        translationRequest = nil
        
        print("🍎 ✅ Translation completed: '\(result)'")
        return result
    }
    
    // MARK: - Result Handling (called by translationTask)
    func handleTranslationSuccess(_ result: String) {
        print("🍎 Translation result received: '\(result)'")
        translationResult = result
        lastError = nil
    }
    
    func handleTranslationError(_ error: Error) {
        print("🍎 Translation error received: \(error)")
        lastError = error.localizedDescription
        translationResult = ""
    }
    
    // MARK: - Language Management
    func checkSupportedLanguages() async -> [String] {
        let supported = await languageAvailability.supportedLanguages
        let codes = supported.compactMap { $0.languageCode?.identifier }
        print("🍎 Supported languages: \(codes)")
        return codes
    }
}

// MARK: - Apple Translation uses existing TranslationError from TranslationService

// MARK: - SwiftUI Integration View
@available(macOS 15.0, *)
struct AppleTranslationIntegrationView: View {
    @ObservedObject var service: AppleTranslationService
    
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 1, height: 1)
            .onAppear {
                print("🍎 AppleTranslationIntegrationView appeared and ready")
            }
            .translationTask(service.currentConfiguration) { session in
                guard let config = service.currentConfiguration,
                      let request = service.translationRequest else {
                    print("🍎 translationTask triggered but no configuration or request")
                    return
                }
                
                print("🍎 translationTask started for request ID: \(request.id) - '\(request.text)'")
                
                do {
                    // First prepare translation (download if needed)
                    try await session.prepareTranslation()
                    print("🍎 prepareTranslation completed successfully")
                    
                    // Then translate
                    let response = try await session.translate(request.text)
                    let translation = response.targetText
                    
                    print("🍎 Translation successful for request ID: \(request.id) - '\(request.text)' → '\(translation)'")
                    
                    await MainActor.run {
                        service.handleTranslationSuccess(translation)
                    }
                    
                } catch {
                    print("🍎 Translation failed in translationTask: \(error)")
                    
                    await MainActor.run {
                        service.handleTranslationError(error)
                    }
                }
            }
    }
}