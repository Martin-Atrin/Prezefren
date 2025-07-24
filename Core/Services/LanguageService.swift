import Foundation
import Translation

// Service types for language filtering and capabilities
enum TranscriptionServiceType {
    case whisper
    case appleSpeech  
    case assembly
}

enum TranslationServiceType {
    case geminiAPI
    case appleNative
}

// Language availability status
enum LanguageAvailabilityStatus {
    case available      // Language is supported and ready
    case downloadable   // Language is supported but needs download
    case notSupported   // Language is not supported by this service
}

// Comprehensive language support for Whisper input and various translation services
class LanguageService {
    
    // MARK: - Whisper Language Support (100+ languages)
    // Based on official Whisper language support - these are the language codes
    // that can be passed to Whisper for better recognition
    static let whisperLanguages = [
        ("af", "Afrikaans"),
        ("am", "Amharic"),
        ("ar", "Arabic"),
        ("as", "Assamese"),
        ("az", "Azerbaijani"),
        ("ba", "Bashkir"),
        ("be", "Belarusian"),
        ("bg", "Bulgarian"),
        ("bn", "Bengali"),
        ("bo", "Tibetan"),
        ("br", "Breton"),
        ("bs", "Bosnian"),
        ("ca", "Catalan"),
        ("cs", "Czech"),
        ("cy", "Welsh"),
        ("da", "Danish"),
        ("de", "German"),
        ("el", "Greek"),
        ("en", "English"),
        ("es", "Spanish"),
        ("et", "Estonian"),
        ("eu", "Basque"),
        ("fa", "Persian"),
        ("fi", "Finnish"),
        ("fo", "Faroese"),
        ("fr", "French"),
        ("gl", "Galician"),
        ("gu", "Gujarati"),
        ("ha", "Hausa"),
        ("haw", "Hawaiian"),
        ("he", "Hebrew"),
        ("hi", "Hindi"),
        ("hr", "Croatian"),
        ("ht", "Haitian Creole"),
        ("hu", "Hungarian"),
        ("hy", "Armenian"),
        ("id", "Indonesian"),
        ("is", "Icelandic"),
        ("it", "Italian"),
        ("ja", "Japanese"),
        ("jw", "Javanese"),
        ("ka", "Georgian"),
        ("kk", "Kazakh"),
        ("km", "Khmer"),
        ("kn", "Kannada"),
        ("ko", "Korean"),
        ("la", "Latin"),
        ("lb", "Luxembourgish"),
        ("ln", "Lingala"),
        ("lo", "Lao"),
        ("lt", "Lithuanian"),
        ("lv", "Latvian"),
        ("mg", "Malagasy"),
        ("mi", "Maori"),
        ("mk", "Macedonian"),
        ("ml", "Malayalam"),
        ("mn", "Mongolian"),
        ("mr", "Marathi"),
        ("ms", "Malay"),
        ("mt", "Maltese"),
        ("my", "Myanmar"),
        ("ne", "Nepali"),
        ("nl", "Dutch"),
        ("nn", "Norwegian Nynorsk"),
        ("no", "Norwegian"),
        ("oc", "Occitan"),
        ("pa", "Punjabi"),
        ("pl", "Polish"),
        ("ps", "Pashto"),
        ("pt", "Portuguese"),
        ("ro", "Romanian"),
        ("ru", "Russian"),
        ("sa", "Sanskrit"),
        ("sd", "Sindhi"),
        ("si", "Sinhala"),
        ("sk", "Slovak"),
        ("sl", "Slovenian"),
        ("sn", "Shona"),
        ("so", "Somali"),
        ("sq", "Albanian"),
        ("sr", "Serbian"),
        ("su", "Sundanese"),
        ("sv", "Swedish"),
        ("sw", "Swahili"),
        ("ta", "Tamil"),
        ("te", "Telugu"),
        ("tg", "Tajik"),
        ("th", "Thai"),
        ("tk", "Turkmen"),
        ("tl", "Tagalog"),
        ("tr", "Turkish"),
        ("tt", "Tatar"),
        ("uk", "Ukrainian"),
        ("ur", "Urdu"),
        ("uz", "Uzbek"),
        ("vi", "Vietnamese"),
        ("yi", "Yiddish"),
        ("yo", "Yoruba"),
        ("zh", "Chinese"),
        ("zu", "Zulu")
    ]
    
    // MARK: - AssemblyAI Language Support (Streaming)
    // Currently English only for streaming transcription (2025)
    static let assemblyAILanguages = [
        ("en", "English")
    ]
    
    // MARK: - Apple Speech Recognition Support  
    // Based on iOS/macOS Speech framework capabilities
    static let appleSpeechLanguages = [
        ("ar", "Arabic"),
        ("zh", "Chinese (Simplified)"),
        ("zh-Hant", "Chinese (Traditional)"),
        ("cs", "Czech"),
        ("da", "Danish"),
        ("nl", "Dutch"),
        ("en", "English"),
        ("fi", "Finnish"),
        ("fr", "French"),
        ("de", "German"),
        ("el", "Greek"),
        ("he", "Hebrew"),
        ("hi", "Hindi"),
        ("hu", "Hungarian"),
        ("id", "Indonesian"),
        ("it", "Italian"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("ms", "Malay"),
        ("no", "Norwegian"),
        ("pl", "Polish"),
        ("pt", "Portuguese"),
        ("ro", "Romanian"),
        ("ru", "Russian"),
        ("sk", "Slovak"),
        ("es", "Spanish"),
        ("sv", "Swedish"),
        ("th", "Thai"),
        ("tr", "Turkish"),
        ("uk", "Ukrainian"),
        ("vi", "Vietnamese")
        // Note: Actual availability depends on device and installed language packs
    ]
    
    // MARK: - Apple Native Translation Support (macOS Translation framework)
    // Complete list of 19 supported languages (2025)
    static let appleNativeLanguages = [
        ("ar", "Arabic"),
        ("zh", "Chinese (Simplified)"),
        ("nl", "Dutch"), 
        ("en", "English"),
        ("fr", "French"),
        ("de", "German"),
        ("hi", "Hindi"),
        ("id", "Indonesian"),
        ("it", "Italian"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("pl", "Polish"),
        ("pt", "Portuguese (Brazil)"),
        ("ru", "Russian"),
        ("es", "Spanish"),
        ("th", "Thai"),
        ("tr", "Turkish"),
        ("uk", "Ukrainian"),
        ("vi", "Vietnamese")
    ]
    
    // MARK: - Gemini API Language Support (100+ languages)
    // Based on Gemini 1.5 Flash extensive multilingual capabilities
    static let geminiLanguages = [
        ("af", "Afrikaans"),
        ("sq", "Albanian"),
        ("am", "Amharic"),
        ("ar", "Arabic"),
        ("hy", "Armenian"),
        ("as", "Assamese"),
        ("az", "Azerbaijani"),
        ("eu", "Basque"),
        ("be", "Belarusian"),
        ("bn", "Bengali"),
        ("bs", "Bosnian"),
        ("bg", "Bulgarian"),
        ("ca", "Catalan"),
        ("ceb", "Cebuano"),
        ("zh", "Chinese (Simplified)"),
        ("zh-Hant", "Chinese (Traditional)"),
        ("co", "Corsican"),
        ("hr", "Croatian"),
        ("cs", "Czech"),
        ("da", "Danish"),
        ("dv", "Dhivehi"),
        ("nl", "Dutch"),
        ("en", "English"),
        ("eo", "Esperanto"),
        ("et", "Estonian"),
        ("tl", "Filipino"),
        ("fi", "Finnish"),
        ("fr", "French"),
        ("fy", "Frisian"),
        ("gl", "Galician"),
        ("ka", "Georgian"),
        ("de", "German"),
        ("el", "Greek"),
        ("gu", "Gujarati"),
        ("ht", "Haitian Creole"),
        ("ha", "Hausa"),
        ("haw", "Hawaiian"),
        ("he", "Hebrew"),
        ("hi", "Hindi"),
        ("hmn", "Hmong"),
        ("hu", "Hungarian"),
        ("is", "Icelandic"),
        ("ig", "Igbo"),
        ("id", "Indonesian"),
        ("ga", "Irish"),
        ("it", "Italian"),
        ("ja", "Japanese"),
        ("jw", "Javanese"),
        ("kn", "Kannada"),
        ("kk", "Kazakh"),
        ("km", "Khmer"),
        ("ko", "Korean"),
        ("ku", "Kurdish"),
        ("ky", "Kyrgyz"),
        ("lo", "Lao"),
        ("la", "Latin"),
        ("lv", "Latvian"),
        ("lt", "Lithuanian"),
        ("lb", "Luxembourgish"),
        ("mk", "Macedonian"),
        ("mg", "Malagasy"),
        ("ms", "Malay"),
        ("ml", "Malayalam"),
        ("mt", "Maltese"),
        ("mi", "Maori"),
        ("mr", "Marathi"),
        ("mn", "Mongolian"),
        ("my", "Myanmar (Burmese)"),
        ("ne", "Nepali"),
        ("no", "Norwegian"),
        ("ps", "Pashto"),
        ("fa", "Persian"),
        ("pl", "Polish"),
        ("pt", "Portuguese"),
        ("pa", "Punjabi"),
        ("ro", "Romanian"),
        ("ru", "Russian"),
        ("sm", "Samoan"),
        ("gd", "Scots Gaelic"),
        ("sr", "Serbian"),
        ("st", "Sesotho"),
        ("sn", "Shona"),
        ("sd", "Sindhi"),
        ("si", "Sinhala"),
        ("sk", "Slovak"),
        ("sl", "Slovenian"),
        ("so", "Somali"),
        ("es", "Spanish"),
        ("su", "Sundanese"),
        ("sw", "Swahili"),
        ("sv", "Swedish"),
        ("tg", "Tajik"),
        ("ta", "Tamil"),
        ("te", "Telugu"),
        ("th", "Thai"),
        ("tr", "Turkish"),
        ("uk", "Ukrainian"),
        ("ur", "Urdu"),
        ("uz", "Uzbek"),
        ("vi", "Vietnamese"),
        ("cy", "Welsh"),
        ("xh", "Xhosa"),
        ("yi", "Yiddish"),
        ("yo", "Yoruba"),
        ("zu", "Zulu")
    ]
    
    // MARK: - Service-Specific Language Support
    
    // MARK: - Transcription Service Language Support
    
    static func getSupportedLanguages(for service: TranscriptionServiceType) -> [(String, String)] {
        switch service {
        case .whisper:
            return whisperLanguages
        case .appleSpeech:
            return appleSpeechLanguages
        case .assembly:
            return assemblyAILanguages
        }
    }
    
    // MARK: - Translation Service Language Support
    
    static func getSupportedLanguages(for service: TranslationServiceType) -> [(String, String)] {
        switch service {
        case .geminiAPI:
            return geminiLanguages
        case .appleNative:
            return appleNativeLanguages
        }
    }
    
    // MARK: - Dynamic Language Capabilities
    
    @available(macOS 15.0, *)
    static func getAvailableLanguages(for service: TranslationServiceType) async -> [(String, String)] {
        switch service {
        case .appleNative:
            // Check actual availability using Apple's LanguageAvailability API
            return await getAvailableAppleTranslationLanguages()
        case .geminiAPI:
            // Gemini languages are always available (cloud-based)
            return geminiLanguages
        }
    }
    
    @available(macOS 15.0, *)
    private static func getAvailableAppleTranslationLanguages() async -> [(String, String)] {
        let languageAvailability = LanguageAvailability()
        var availableLanguages: [(String, String)] = []
        
        let englishLanguage = Locale.Language(identifier: "en")
        
        for (code, name) in appleNativeLanguages {
            let targetLanguage = Locale.Language(identifier: code)
            let status = await languageAvailability.status(from: englishLanguage, to: targetLanguage)
            
            switch status {
            case .installed, .supported:
                availableLanguages.append((code, name))
            case .unsupported:
                continue
            @unknown default:
                continue
            }
        }
        
        return availableLanguages
    }
    
    // MARK: - Language Filtering and Search
    
    static func filterLanguages(for service: TranscriptionServiceType, searchText: String) -> [(String, String)] {
        let supportedLanguages = getSupportedLanguages(for: service)
        
        if searchText.isEmpty {
            return supportedLanguages
        }
        
        let lowercaseSearch = searchText.lowercased()
        return supportedLanguages.filter { code, name in
            name.lowercased().contains(lowercaseSearch) ||
            code.lowercased().contains(lowercaseSearch)
        }
    }
    
    static func filterLanguages(for service: TranslationServiceType, searchText: String) -> [(String, String)] {
        let supportedLanguages = getSupportedLanguages(for: service)
        
        if searchText.isEmpty {
            return supportedLanguages
        }
        
        let lowercaseSearch = searchText.lowercased()
        return supportedLanguages.filter { code, name in
            name.lowercased().contains(lowercaseSearch) ||
            code.lowercased().contains(lowercaseSearch)
        }
    }
    
    // MARK: - Language Code Conversion & Validation
    
    // Transcription service validation
    static func isLanguageSupported(_ code: String, for service: TranscriptionServiceType) -> Bool {
        return getSupportedLanguages(for: service).contains { $0.0 == code }
    }
    
    static func getLanguageName(forCode code: String, service: TranscriptionServiceType) -> String {
        return getSupportedLanguages(for: service).first { $0.0 == code }?.1 ?? "Unknown"
    }
    
    // Translation service validation  
    static func isLanguageSupported(_ code: String, for service: TranslationServiceType) -> Bool {
        return getSupportedLanguages(for: service).contains { $0.0 == code }
    }
    
    static func getLanguageName(forCode code: String, service: TranslationServiceType) -> String {
        return getSupportedLanguages(for: service).first { $0.0 == code }?.1 ?? "Unknown"
    }
    
    // Legacy compatibility methods
    static func getLanguageName(forWhisperCode code: String) -> String {
        return getLanguageName(forCode: code, service: .whisper)
    }
    
    static func isValidWhisperLanguage(_ code: String) -> Bool {
        return isLanguageSupported(code, for: .whisper)
    }
    
    // MARK: - Smart Language Capabilities
    
    static func getCompatibleInputLanguages(for transcriptionEngine: TranscriptionServiceType) -> [(String, String)] {
        return getSupportedLanguages(for: transcriptionEngine)
    }
    
    static func getCompatibleOutputLanguages(for translationEngine: TranslationServiceType, inputLanguage: String? = nil) -> [(String, String)] {
        let supportedLanguages = getSupportedLanguages(for: translationEngine)
        
        // For Apple Native, we could filter based on input language pairs if needed
        if translationEngine == .appleNative, let _ = inputLanguage {
            // Apple Translation supports bidirectional translation
            // For now, return all supported languages
            return supportedLanguages
        }
        
        return supportedLanguages
    }
    
    static func isValidConfiguration(input: String, transcriptionEngine: TranscriptionServiceType, output: String, translationEngine: TranslationServiceType) -> Bool {
        let inputValid = isLanguageSupported(input, for: transcriptionEngine)
        let outputValid = isLanguageSupported(output, for: translationEngine)
        
        return inputValid && outputValid
    }
    
    static func suggestAlternativeEngine(for languageCode: String, currentEngine: TranscriptionServiceType) -> TranscriptionServiceType? {
        // If current engine doesn't support the language, suggest one that does
        if isLanguageSupported(languageCode, for: currentEngine) {
            return nil // Current engine is fine
        }
        
        // Try other engines in order of preference
        let alternatives: [TranscriptionServiceType] = [.whisper, .appleSpeech, .assembly]
        
        for engine in alternatives {
            if engine != currentEngine && isLanguageSupported(languageCode, for: engine) {
                return engine
            }
        }
        
        return nil // No compatible engine found
    }
    
    // MARK: - Language Mapping
    
    // Convert between different language code standards if needed
    static func mapTranscriptionToTranslationCode(_ code: String, from transcriptionEngine: TranscriptionServiceType, to translationEngine: TranslationServiceType) -> String {
        // Most codes are compatible, but handle special cases
        switch (transcriptionEngine, translationEngine) {
        case (.whisper, .geminiAPI), (.whisper, .appleNative):
            // Handle specific mappings if needed
            return code
        case (.appleSpeech, .geminiAPI), (.appleSpeech, .appleNative):
            return code
        case (.assembly, .geminiAPI), (.assembly, .appleNative):
            return code
        }
    }
}