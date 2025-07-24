import SwiftUI
import Translation

struct ModelsView: View {
    @State private var isDownloadingAppleLanguages = false
    @State private var downloadStatus = "Ready to download"
    @State private var downloadProgress = 0
    @State private var totalPairs = 12
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                headerSection
                
                // Apple Translation Section (our offline goal)
                if #available(macOS 15.0, *) {
                    appleTranslationCard
                }
                
                // Current Whisper Model (simplified)
                currentWhisperModelCard
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("AI Models")
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                    .font(.title)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Models")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Simplified model configuration - Apple Native + Whisper Base")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
    
    @available(macOS 15.0, *)
    private var appleTranslationCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "globe.desk")
                        .foregroundColor(.mint)
                        .font(.title2)
                    
                    Text("Apple Translation")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    if isDownloadingAppleLanguages {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("📥 Language Model Status")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Apple Translation downloads language models automatically when first needed. Check current status of supported language pairs.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button(action: {
                            Task {
                                isDownloadingAppleLanguages = true
                                downloadProgress = 0
                                downloadStatus = "Starting download..."
                                
                                defer { 
                                    isDownloadingAppleLanguages = false 
                                    downloadStatus = downloadProgress == totalPairs ? "✅ All downloads completed!" : "❌ Some downloads failed"
                                }
                                
                                if let appleService = appState.enhancedTranslationService.appleTranslationService {
                                    // Use new Apple Translation Service for downloads
                                    print("🍎 Starting downloads with new Apple Translation Service")
                                } else {
                                    downloadStatus = "❌ Apple Translation Service not available"
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                Text(isDownloadingAppleLanguages ? "Downloading..." : "Download Core Languages")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isDownloadingAppleLanguages)
                        
                        // Progress display
                        if isDownloadingAppleLanguages || downloadProgress > 0 {
                            VStack(spacing: 8) {
                                ProgressView(value: Double(downloadProgress), total: Double(totalPairs))
                                    .frame(maxWidth: 300)
                                
                                Text(downloadStatus)
                                    .font(.caption)
                                    .foregroundColor(downloadStatus.contains("❌") ? .red : downloadStatus.contains("✅") ? .green : .blue)
                                
                                Text("\(downloadProgress)/\(totalPairs) language pairs")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button(action: {
                            Task {
                                isDownloadingAppleLanguages = true
                                defer { isDownloadingAppleLanguages = false }
                                
                                if let appleService = appState.enhancedTranslationService.appleTranslationService {
                                    let supportedLangs = await appleService.checkSupportedLanguages()
                                    print("🍎 Supported languages: \(supportedLangs)")
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "list.bullet.clipboard")
                                Text("Check Status")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isDownloadingAppleLanguages)
                        
                        Spacer()
                    }
                    
                    Text("💡 Use 'Download Core Languages' to pre-download EN/ZH/TH/ES for offline use, or 'Check Status' to see current availability.")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                }
            }
        }
    }
    
    private var currentWhisperModelCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "brain.filled.head.profile")
                        .foregroundColor(.green)
                        .font(.title2)
                    
                    Text("Whisper Model")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("base.en (Multilingual)")
                        .font(.title3)
                        .fontWeight(.medium)
                    
                    Text("Fixed model - supports 100+ languages with good balance of speed and accuracy.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        MetricView(title: "Languages", value: "100+")
                        MetricView(title: "Speed", value: "Fast")
                        MetricView(title: "Quality", value: "Good")
                    }
                }
            }
        }
        .background {
            // Apple Translation integration - embed directly in ModelsView
            if #available(macOS 15.0, *) {
                if let appleService = appState.enhancedTranslationService.appleTranslationService {
                    AppleTranslationIntegrationView(service: appleService)
                        .onAppear {
                            print("🍎 ModelsView: AppleTranslationView embedded and ready")
                        }
                } else {
                    Text("DEBUG: appleNativeService is nil")
                        .onAppear {
                            print("❌ ModelsView: appleNativeService is nil!")
                        }
                }
            } else {
                Text("DEBUG: macOS 15.0+ not available")
                    .onAppear {
                        print("❌ ModelsView: macOS 15.0+ not available")
                    }
            }
        }
    }
    
    @available(macOS 15.0, *)
    private func downloadWithProgress(service: AppleTranslationService) async {
        // DISABLED: Download functionality needs proper Apple Translation API integration
        print("🍎 Download functionality disabled - needs Apple Translation API integration")
    }
    
}

struct MetricView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// Modern card component
