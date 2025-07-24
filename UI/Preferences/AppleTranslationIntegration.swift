import SwiftUI
import Translation

// MARK: - Simplified Apple Translation Integration for Preferences
// Direct integration with Apple's Translation framework for downloads

@available(macOS 15.0, *)
struct PreferencesAppleTranslationView: View {
    @StateObject private var preferences = PreferencesManager.shared
    @State private var currentConfig: TranslationSession.Configuration?
    
    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onAppear {
                print("🍎 PreferencesAppleTranslationView ready for downloads")
            }
            .translationTask(currentConfig) { session in
                guard let config = currentConfig else {
                    print("🍎 TranslationTask triggered but no config")
                    return
                }
                
                print("🍎 TranslationTask started for \(config.source?.languageCode?.identifier ?? "auto") → \(config.target?.languageCode?.identifier ?? "unknown")")
                
                do {
                    // This triggers Apple's download dialog
                    try await session.prepareTranslation()
                    print("🍎 ✅ Language model download completed successfully")
                    
                    await MainActor.run {
                        preferences.appleTranslationDownloadStatus = "✅ Download completed successfully"
                        // Clear config to allow next download
                        currentConfig = nil
                        
                        // Trigger next download if needed
                        triggerNextDownload()
                    }
                    
                } catch {
                    print("🍎 ❌ Download failed: \(error)")
                    
                    await MainActor.run {
                        preferences.appleTranslationDownloadStatus = "❌ Download failed: \(error.localizedDescription)"
                        currentConfig = nil
                    }
                }
            }
            .onChange(of: preferences.isDownloadingAppleLanguages) { isDownloading in
                if isDownloading {
                    startDownloadSequence()
                }
            }
    }
    
    @State private var downloadQueue: [TranslationSession.Configuration] = []
    @State private var currentDownloadIndex = 0
    
    private func startDownloadSequence() {
        print("🍎 Starting Apple Translation download sequence")
        
        // Use selected languages from preferences instead of hardcoded ones
        let languages = Array(preferences.selectedAppleLanguages)
        downloadQueue.removeAll()
        
        print("🍎 Selected languages for download: \(languages)")
        
        for source in languages {
            for target in languages {
                guard source != target else { continue }
                
                let sourceLanguage = Locale.Language(identifier: source)
                let targetLanguage = Locale.Language(identifier: target)
                
                let config = TranslationSession.Configuration(
                    source: sourceLanguage,
                    target: targetLanguage
                )
                downloadQueue.append(config)
            }
        }
        
        currentDownloadIndex = 0
        preferences.appleTranslationDownloadStatus = "Starting downloads..."
        
        // Start first download
        triggerNextDownload()
    }
    
    private func triggerNextDownload() {
        guard currentDownloadIndex < downloadQueue.count else {
            // All downloads complete
            preferences.appleTranslationDownloadStatus = "✅ All language pairs downloaded!"
            preferences.isDownloadingAppleLanguages = false
            return
        }
        
        let config = downloadQueue[currentDownloadIndex]
        let source = config.source?.languageCode?.identifier ?? "auto"
        let target = config.target?.languageCode?.identifier ?? "unknown"
        
        preferences.appleTranslationDownloadStatus = "Downloading \(source.uppercased()) → \(target.uppercased())..."
        
        print("🍎 Triggering download \(currentDownloadIndex + 1)/\(downloadQueue.count): \(source) → \(target)")
        
        // Set the configuration to trigger translationTask
        currentConfig = config
        currentDownloadIndex += 1
    }
}