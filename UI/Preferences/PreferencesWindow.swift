import SwiftUI

// MARK: - Preferences Window
// Native macOS preferences window with unified design language

struct PreferencesWindow: View {
    @StateObject private var preferences = PreferencesManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
            TranslationPreferencesView()
                .tabItem {
                    Image(systemName: "globe")
                    Text("Translation")
                }
                .tag(0)
            
            AudioPreferencesView()
                .tabItem {
                    Image(systemName: "speaker.wave.2")
                    Text("Audio")
                }
                .tag(1)
            
            GeneralPreferencesView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("General")
                }
                .tag(2)
            }
            .frame(width: 700, height: 600)
            .navigationTitle("Prezefren Preferences")
            
            // Apple Translation integration (invisible but active)
            if #available(macOS 15.0, *) {
                PreferencesAppleTranslationView()
                    .allowsHitTesting(false)
                    .opacity(0)
            }
        }
    }
}

// MARK: - Modern Card Component for Preferences
struct PreferenceCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let content: Content
    
    init(title: String, icon: String, iconColor: Color = .blue, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card Header
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.title2)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            // Card Content
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Modern Button Style
struct PreferenceButtonStyle: ButtonStyle {
    let style: PreferenceButtonType
    
    enum PreferenceButtonType {
        case primary, secondary, action, link
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(backgroundColor(for: style, pressed: configuration.isPressed))
            .foregroundColor(foregroundColor(for: style))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
    
    private func backgroundColor(for style: PreferenceButtonType, pressed: Bool) -> Color {
        switch style {
        case .primary:
            return pressed ? .accentColor.opacity(0.8) : .accentColor
        case .secondary:
            return pressed ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2)
        case .action:
            return pressed ? .blue.opacity(0.8) : .blue
        case .link:
            return .clear
        }
    }
    
    private func foregroundColor(for style: PreferenceButtonType) -> Color {
        switch style {
        case .primary, .action:
            return .white
        case .secondary:
            return .primary
        case .link:
            return .accentColor
        }
    }
}

// MARK: - Translation Preferences Tab
struct TranslationPreferencesView: View {
    @StateObject private var preferences = PreferencesManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Translation Mode Card
                PreferenceCard(title: "Translation Mode", icon: "globe", iconColor: .blue) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Default Translation Service", selection: $preferences.translationMode) {
                            ForEach(TranslationMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .onChange(of: preferences.translationMode) { _ in
                            preferences.saveSettings()
                        }
                        
                        Text(preferences.translationMode.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                // Apple Translation Card
                PreferenceCard(title: "Apple Translation", icon: "apple.logo", iconColor: .black) {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle("Enable Apple On-Device Translation", isOn: $preferences.enableAppleNative)
                            .onChange(of: preferences.enableAppleNative) { _ in
                                preferences.saveSettings()
                            }
                        
                        // System Settings Link
                        HStack(spacing: 12) {
                            Image(systemName: "gear")
                                .foregroundColor(.blue)
                                .font(.caption)
                            
                            Text("Also enable in")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("System Settings") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension?translation") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(PreferenceButtonStyle(style: .link))
                            .font(.caption)
                        }
                        
                        // Warning Box
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Required: Check \"On device translation\" in System Settings")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Text("This enables Apple's Translation framework for offline translation")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        
                        // Language Models Section
                        if #available(macOS 15.0, *) {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Language Models")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text("Select languages to download for offline translation")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                
                                // Language Selection Grid
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                                    ForEach(LanguageService.appleNativeLanguages, id: \.0) { code, name in
                                        HStack(spacing: 6) {
                                            Image(systemName: preferences.selectedAppleLanguages.contains(code) ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(preferences.selectedAppleLanguages.contains(code) ? .green : .gray)
                                                .font(.caption)
                                            
                                            Text(name)
                                                .font(.caption)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(preferences.selectedAppleLanguages.contains(code) ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                                        )
                                        .onTapGesture {
                                            if preferences.selectedAppleLanguages.contains(code) {
                                                preferences.selectedAppleLanguages.remove(code)
                                            } else {
                                                preferences.selectedAppleLanguages.insert(code)
                                            }
                                            preferences.saveSettings()
                                        }
                                    }
                                }
                                
                                // Download Controls
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(preferences.selectedAppleLanguages.count) languages selected")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        if preferences.selectedAppleLanguages.count > 0 {
                                            Text("Will download \(preferences.selectedAppleLanguages.count * (preferences.selectedAppleLanguages.count - 1)) translation pairs")
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 8) {
                                        Button("Select All") {
                                            preferences.selectedAppleLanguages = Set(LanguageService.appleNativeLanguages.map { $0.0 })
                                            preferences.saveSettings()
                                        }
                                        .buttonStyle(PreferenceButtonStyle(style: .secondary))
                                        .disabled(preferences.isDownloadingAppleLanguages)
                                        
                                        Button("Clear") {
                                            preferences.selectedAppleLanguages.removeAll()
                                            preferences.saveSettings()
                                        }
                                        .buttonStyle(PreferenceButtonStyle(style: .secondary))
                                        .disabled(preferences.isDownloadingAppleLanguages)
                                        
                                        if preferences.isDownloadingAppleLanguages {
                                            ProgressView()
                                                .controlSize(.small)
                                        }
                                        
                                        Button(action: {
                                            Task {
                                                await preferences.downloadAppleLanguages()
                                            }
                                        }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "arrow.down.circle.fill")
                                                Text(preferences.isDownloadingAppleLanguages ? "Downloading..." : "Download Selected")
                                            }
                                        }
                                        .buttonStyle(PreferenceButtonStyle(style: .primary))
                                        .disabled(preferences.isDownloadingAppleLanguages || !preferences.enableAppleNative || preferences.selectedAppleLanguages.isEmpty)
                                    }
                                }
                                
                                // Status Display
                                if !preferences.appleTranslationDownloadStatus.isEmpty && preferences.appleTranslationDownloadStatus != "Ready to download" {
                                    HStack(spacing: 8) {
                                        Image(systemName: preferences.appleTranslationDownloadStatus.contains("✅") ? "checkmark.circle.fill" : 
                                              preferences.appleTranslationDownloadStatus.contains("❌") ? "xmark.circle.fill" : "info.circle.fill")
                                            .foregroundColor(preferences.appleTranslationDownloadStatus.contains("✅") ? .green : 
                                                           preferences.appleTranslationDownloadStatus.contains("❌") ? .red : .blue)
                                        
                                        Text(preferences.appleTranslationDownloadStatus)
                                            .font(.caption)
                                            .foregroundColor(preferences.appleTranslationDownloadStatus.contains("✅") ? .green : 
                                                           preferences.appleTranslationDownloadStatus.contains("❌") ? .red : .blue)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(preferences.appleTranslationDownloadStatus.contains("✅") ? Color.green.opacity(0.1) : 
                                                 preferences.appleTranslationDownloadStatus.contains("❌") ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                                    )
                                }
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Apple Translation requires macOS 15.0+")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                
                // Gemini API Card
                PreferenceCard(title: "Gemini API (Fallback)", icon: "cloud", iconColor: .purple) {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle("Enable Gemini API Fallback", isOn: $preferences.fallbackToGemini)
                            .onChange(of: preferences.fallbackToGemini) { _ in
                                preferences.saveSettings()
                            }
                        
                        if !preferences.fallbackToGemini {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                
                                Text("Fallback disabled - Pure Apple Translation testing mode")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("API Key")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                SecureField("Enter Gemini API Key", text: $preferences.geminiApiKey)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: preferences.geminiApiKey) { _ in
                                        preferences.saveSettings()
                                    }
                                
                                HStack(spacing: 8) {
                                    Image(systemName: preferences.isGeminiConfigured ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundColor(preferences.isGeminiConfigured ? .green : .orange)
                                    
                                    Text(preferences.isGeminiConfigured ? "API Key configured" : "API Key required for fallback")
                                        .font(.caption)
                                        .foregroundColor(preferences.isGeminiConfigured ? .green : .orange)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Audio Preferences Tab
struct AudioPreferencesView: View {
    @StateObject private var preferences = PreferencesManager.shared
    @StateObject private var audioDeviceManager = AudioDeviceManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Transcription Engine Card
                PreferenceCard(title: "Transcription Engine", icon: "waveform.and.mic", iconColor: .purple) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Transcription Engine", selection: $preferences.transcriptionEngine) {
                            ForEach(TranscriptionEngine.allCases, id: \.self) { engine in
                                Text(engine.rawValue).tag(engine)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .onChange(of: preferences.transcriptionEngine) { _ in
                            preferences.saveSettings()
                        }
                        
                        Text(preferences.transcriptionEngine.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                // AssemblyAI API Key Card (show only when AssemblyAI is selected)
                if preferences.transcriptionEngine == .assembly {
                    PreferenceCard(title: "AssemblyAI Configuration", icon: "cloud.fill", iconColor: .blue) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("API Key")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 8) {
                                SecureField("Enter AssemblyAI API Key", text: $preferences.assemblyAIApiKey)
                                    .textFieldStyle(.roundedBorder)
                                
                                Button("Save") {
                                    preferences.saveSettings()
                                    // TODO: Add connection test like assembly version
                                }
                                .buttonStyle(PreferenceButtonStyle(style: .primary))
                                .disabled(preferences.assemblyAIApiKey.isEmpty)
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: preferences.isAssemblyAIConfigured ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(preferences.isAssemblyAIConfigured ? .green : .orange)
                                
                                Text(preferences.isAssemblyAIConfigured ? "API Key configured" : "API Key required for real-time streaming")
                                    .font(.caption)
                                    .foregroundColor(preferences.isAssemblyAIConfigured ? .green : .orange)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            // Additional info
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Real-time cloud transcription with sub-500ms latency")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Get your API key from assemblyai.com")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                // Audio Mode Card
                PreferenceCard(title: "Audio Mode", icon: "speaker.wave.2", iconColor: .green) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Input Mode", selection: $preferences.audioMode) {
                            ForEach(AudioMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .onChange(of: preferences.audioMode) { _ in
                            preferences.saveSettings()
                        }
                        
                        Text(preferences.audioMode.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                // Device Selection Card
                PreferenceCard(title: "Device Selection", icon: "headphones", iconColor: .orange) {
                    VStack(spacing: 16) {
                        // Input Device Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Input Device")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Menu {
                                ForEach(audioDeviceManager.inputDevices) { device in
                                    Button(action: {
                                        audioDeviceManager.selectInputDevice(device)
                                        preferences.selectedInputDevice = device.name
                                        preferences.saveSettings()
                                    }) {
                                        HStack {
                                            Text(device.name)
                                            if device.isDefault {
                                                Text("(Default)")
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Text("\(device.channelCount)ch")
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                            if audioDeviceManager.selectedInputDevice?.id == device.id {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(audioDeviceManager.selectedInputDevice?.name ?? "Select Input Device")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if let selectedDevice = audioDeviceManager.selectedInputDevice {
                                Text("📱 \(selectedDevice.channelCount) channel\(selectedDevice.channelCount == 1 ? "" : "s") • \(selectedDevice.isDefault ? "System Default" : "Custom")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Output Device Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Output Device")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Menu {
                                ForEach(audioDeviceManager.outputDevices) { device in
                                    Button(action: {
                                        audioDeviceManager.selectOutputDevice(device)
                                        preferences.selectedOutputDevice = device.name
                                        preferences.saveSettings()
                                    }) {
                                        HStack {
                                            Text(device.name)
                                            if device.isDefault {
                                                Text("(Default)")
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            if audioDeviceManager.selectedOutputDevice?.id == device.id {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(audioDeviceManager.selectedOutputDevice?.name ?? "Select Output Device")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(NSColor.controlBackgroundColor))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if let selectedDevice = audioDeviceManager.selectedOutputDevice {
                                Text("🔊 \(selectedDevice.isDefault ? "System Default" : "Custom Selection")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Device Status Information
                        if audioDeviceManager.inputDevices.isEmpty || audioDeviceManager.outputDevices.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                
                                Text("No audio devices detected. Please check your system settings.")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                
                                Text("Found \(audioDeviceManager.inputDevices.count) input device\(audioDeviceManager.inputDevices.count == 1 ? "" : "s") and \(audioDeviceManager.outputDevices.count) output device\(audioDeviceManager.outputDevices.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                
            }
            .padding(20)
        }
    }
}

// MARK: - General Preferences Tab
struct GeneralPreferencesView: View {
    @StateObject private var preferences = PreferencesManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Interface Card
                PreferenceCard(title: "Interface", icon: "rectangle.3.group", iconColor: .indigo) {
                    VStack(spacing: 12) {
                        Toggle("Show Floating Windows", isOn: $preferences.showFloatingWindows)
                            .onChange(of: preferences.showFloatingWindows) { _ in
                                preferences.saveSettings()
                            }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Word-by-Word Animations", isOn: $preferences.enableAnimations)
                                .onChange(of: preferences.enableAnimations) { _ in
                                    preferences.saveSettings()
                                }
                            
                            Text("Enable smooth word-by-word text appearance with language-aware segmentation")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            // Animation speed control
                            if preferences.enableAnimations {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Animation Speed:")
                                            .font(.subheadline)
                                        Spacer()
                                        Picker("Speed", selection: Binding(
                                            get: { getSpeedPreset() },
                                            set: { setSpeedPreset($0) }
                                        )) {
                                            Text("Fast").tag("fast")
                                            Text("Normal").tag("default")
                                            Text("Slow").tag("slow")
                                            Text("Instant").tag("instant")
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                        .frame(width: 100)
                                    }
                                    
                                    Text("Adjust how quickly words appear during transcription")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                .padding(.leading, 20)
                            }
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Debug Console", isOn: $preferences.enableDebugMode)
                                .onChange(of: preferences.enableDebugMode) { _ in
                                    preferences.saveSettings()
                                }
                            
                            Text("Shows real-time debug output in the right panel for troubleshooting")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                
                // Current Configuration Card
                PreferenceCard(title: "Current Configuration", icon: "info.circle", iconColor: .teal) {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Effective Translation Mode:")
                                .font(.subheadline)
                            Spacer()
                            Text(preferences.effectiveTranslationMode.rawValue)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                        
                        HStack {
                            Text("Audio Mode:")
                                .font(.subheadline)
                            Spacer()
                            Text(preferences.audioMode.rawValue)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                        
                        HStack {
                            Text("Apple Translation Available:")
                                .font(.subheadline)
                            Spacer()
                            HStack(spacing: 6) {
                                Image(systemName: preferences.canUseAppleTranslation ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(preferences.canUseAppleTranslation ? .green : .red)
                                Text(preferences.canUseAppleTranslation ? "Available" : "Not Available")
                                    .font(.caption)
                                    .foregroundColor(preferences.canUseAppleTranslation ? .green : .red)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((preferences.canUseAppleTranslation ? Color.green : Color.red).opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Word Streaming Helper Functions
    
    private func getSpeedPreset() -> String {
        // Get the current config from AppState would be ideal, but since we're in PreferencesWindow
        // we'll use PreferencesManager to store the speed preference
        return preferences.wordStreamingSpeed ?? "default"
    }
    
    private func setSpeedPreset(_ speed: String) {
        preferences.wordStreamingSpeed = speed
        preferences.saveSettings()
        
        // Note: AppState will automatically read from preferences when UI components are updated
    }
}