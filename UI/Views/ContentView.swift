import SwiftUI
import CoreAudio
import Translation


struct ContentView: View {
    @StateObject private var appState = AppState()
    @StateObject private var audioDeviceManager = AudioDeviceManager.shared
    @EnvironmentObject var panelManager: FloatingPanelManager
    @State private var selectedTab = 0
    @State private var showingTemplateSelector = false
    @State private var apiKeyInput = ""
    @State private var monoLanguage = "en"  // Default to English for mono mode
    @State private var leftChannelLanguage = "en"  // Left channel language for stereo mode
    @State private var rightChannelLanguage = "en" // Right channel language for stereo mode
    
    // MARK: - Word Streaming Helper Functions
    
    private func getWordStreamingConfig() -> WordStreamingConfig {
        let preferences = PreferencesManager.shared
        
        // If animations are disabled, use instant mode
        guard preferences.enableAnimations else {
            return .instant
        }
        
        // Map preference speed to config
        switch preferences.wordStreamingSpeed ?? "default" {
        case "fast":
            return .fast
        case "slow":
            return .slow
        case "instant":
            return .instant
        default:
            return .default
        }
    }
    
    private func getFastWordStreamingConfig() -> WordStreamingConfig {
        let preferences = PreferencesManager.shared
        
        // If animations are disabled, use instant mode
        guard preferences.enableAnimations else {
            return .instant
        }
        
        // Always use fast config for historical text, regardless of user setting
        return .fast
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Modern header with status
                headerSection
                
                tabView
            }
            .prezefrenBackground()
            
            // Right panel - conditionally show debug console or placeholder
            Group {
                if PreferencesManager.shared.enableDebugMode {
                    DebugConsoleView()
                        .prezefrenBackground()
                } else {
                    VStack {
                        Spacer()
                        
                        VStack(spacing: 16) {
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.prezefrenPrimary)
                            
                            Text("More functions coming soon,")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.prezefrenForeground)
                            
                            Text("stay tuned!")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.prezefrenForeground)
                            
                            Text("Future features will include advanced audio processing, AI-powered transcription enhancements, and workflow automation tools.")
                                .font(.body)
                                .foregroundColor(.prezefrenMutedForeground)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .prezefrenBackground()
                }
            }
        }
        .frame(minWidth: 600, minHeight: 700)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            print("🛑 App terminating - stopping recording")
            Task {
                if appState.isRecording {
                    await appState.stopRecording()
                }
            }
        }
        .onAppear {
            print("🎧 UI initialized")
            
            // Set up callbacks for device and passthrough changes from preferences
            audioDeviceManager.audioEngineUpdateCallback = { device in
                await appState.audioEngine.setOutputDevice(device)
            }
            
            audioDeviceManager.passthroughUpdateCallback = { enabled in
                await appState.audioEngine.setPassthroughEnabled(enabled)
            }
        }
        .onReceive(PreferencesManager.shared.$transcriptionEngine) { newEngine in
            // Sync transcription engine changes from preferences to app state
            if appState.transcriptionEngine != newEngine {
                appState.transcriptionEngine = newEngine
                print("🔄 Transcription engine updated to: \(newEngine.rawValue)")
            }
        }
        .onReceive(PreferencesManager.shared.$audioMode) { newMode in
            // Sync audio mode changes from preferences to app state
            if appState.audioMode != newMode {
                appState.setAudioMode(newMode)
                print("🔄 Audio mode updated to: \(newMode.rawValue)")
            }
        }
        .onReceive(PreferencesManager.shared.$enableDebugMode) { enabled in
            // Sync debug mode with DebugLogger
            DebugLogger.shared.setEnabled(enabled)
        }
        .overlay(alignment: .topLeading) {
            // Apple Translation integration (invisible but active)
            if #available(macOS 15.0, *) {
                if let appleService = appState.enhancedTranslationService.appleTranslationService {
                    AppleTranslationIntegrationView(service: appleService)
                        .allowsHitTesting(false)
                        .opacity(0)
                } else {
                    Text("")
                        .onAppear {
                            print("❌ ContentView: appleTranslationService is nil - initialization issue!")
                        }
                }
            } else {
                Text("")
                    .onAppear {
                        print("❌ ContentView: macOS 15.0+ not available")
                    }
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            // App icon with gradient (inspired by SubmAIvoice)
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [.prezefrenPrimary, .prezefrenAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "waveform.circle")
                    .foregroundColor(.white)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Prezefren")
                    .font(.title)
                    .fontWeight(.bold)
                
                HStack(spacing: 8) {
                    // Status indicator
                    Circle()
                        .frame(width: 8, height: 8)
                        .prezefrenStatusDot(isActive: appState.isRecording)
                    
                    Text(getStatusText())
                        .font(.caption)
                        .foregroundColor(.prezefrenMutedForeground)
                    
                    // Audio mode indicator badge
                    HStack(spacing: 4) {
                        Image(systemName: getModeIcon(appState.audioMode))
                            .foregroundColor(getModeColor(appState.audioMode))
                            .font(.caption2)
                        Text(appState.audioMode.rawValue)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(getModeColor(appState.audioMode))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(getModeColor(appState.audioMode).opacity(0.1))
                    )
                    
                    // Memory monitoring indicator
                    if appState.memoryPressure != "Normal" {
                        HStack(spacing: 4) {
                            Image(systemName: "memorychip")
                                .foregroundColor(appState.memoryPressure == "Critical" ? .red : .orange)
                                .font(.caption)
                            Text("\(String(format: "%.0f", appState.memoryUsageMB))MB")
                                .font(.caption2)
                                .foregroundColor(appState.memoryPressure == "Critical" ? .red : .orange)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .prezefrenCard()
    }
    
    private func getStatusText() -> String {
        if appState.isRecording {
            let windowsActive = appState.subtitleWindows.filter(\.isVisible).count
            let modeStatus = appState.audioMode.rawValue
            return "Recording (\(modeStatus)) - \(windowsActive) windows active"
        } else {
            return "Ready - \(appState.subtitleWindows.count) windows configured"
        }
    }
    
    private var tabView: some View {
        TabView(selection: $selectedTab) {
            preparationTab
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Preparation")
                }
                .tag(0)
            
            windowManagementTab
                .tabItem {
                    Image(systemName: "macwindow.on.rectangle")
                    Text("Windows")
                }
                .tag(1)
        }
        .tabViewStyle(.automatic)
    }
    
    
    // MARK: - Tab Content
    
    // MARK: - Preparation Tab (merged Record + Audio)
    
    private var preparationTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Recording section - keep as-is, it's quite nice
                recordingControlsCard
                
                // Live Transcription - keep as-is it is a good gauge of "if" its working
                transcriptionPreviewCard
                
                // Audio Device selection section - Keep as-is - make sure it's functional
                audioDeviceSelectionCard
                
                // Enable audio passthrough - Simple toggle, no need for supporting text
                simplePassthroughCard
                
                // Audio recording to file - New feature toggle
                audioRecordingCard
                
                // Current Configuration - Keep only "EDIT IN PREFERENCES" and move to the bottom
                currentConfigurationCard
            }
            .padding()
        }
    }
    
    
    private var windowManagementTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                windowTemplateCard
                windowListCard
                windowBatchControlsCard
            }
            .padding()
        }
    }
    
    
    // MARK: - Card Components (inspired by SubmAIvoice Flutter UI)
    
    private var transcriptionPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "waveform.badge.mic")
                        .foregroundColor(.prezefrenPrimary)
                        .font(.title2)
                    
                    Text("Live Transcription")
                        .prezefrenHeading()
                    
                    Spacer()
                    
                    // Audio level indicator
                    HStack(spacing: 2) {
                        ForEach(0..<5) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(appState.isRecording && i < 3 ? .green : .gray.opacity(0.3))
                                .frame(width: 3, height: CGFloat(8 + i * 2))
                                .animation(.easeInOut(duration: 0.3), value: appState.isRecording)
                        }
                    }
                }
                
                // Current transcription display
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current:")
                        .font(.caption)
                        .foregroundColor(.prezefrenMutedForeground)
                    
                    ScrollView {
                        ProgressiveTextView(
                            fullText: appState.currentTranscription.isEmpty ? "Waiting for audio..." : appState.currentTranscription,
                            config: getWordStreamingConfig(),
                            fontSize: 14,
                            fontWeight: .regular,
                            textColor: .primary,
                            alignment: .leading
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(.body, design: .monospaced))
                    }
                    .frame(height: 60)
                    .prezefrenTranscriptionArea()
                }
                
                // Historical transcription 
                VStack(alignment: .leading, spacing: 6) {
                    Text("History:")
                        .font(.caption)
                        .foregroundColor(.prezefrenMutedForeground)
                    
                    ScrollView {
                        ProgressiveTextView(
                            fullText: appState.historicalTranscription.isEmpty ? "No history yet..." : appState.historicalTranscription,
                            config: getFastWordStreamingConfig(),
                            fontSize: 12,
                            fontWeight: .regular,
                            textColor: .primary,
                            alignment: .leading
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(.caption, design: .monospaced))
                    }
                    .frame(height: 80)
                    .prezefrenTranscriptionArea()
                }
            }
        .prezefrenCard()
    }
    
    private var audioModeCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "speaker.wave.2")
                        .foregroundColor(.prezefrenAccent)
                        .font(.title2)
                    
                    Text("Audio Mode")
                        .prezefrenHeading()
                    
                    Spacer()
                }
                
                VStack(spacing: 12) {
                    ForEach(AudioMode.allCases, id: \.self) { mode in
                        HStack {
                            Button(action: {
                                if mode == .goobero && !audioDeviceManager.supportsStereoMode() {
                                    // Don't allow goobero mode if hardware doesn't support it
                                    return
                                }
                                appState.setAudioMode(mode)
                            }) {
                                HStack {
                                    let isSelected = appState.audioMode == mode
                                    let isDisabled = mode == .goobero && !audioDeviceManager.supportsStereoMode()
                                    
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(isDisabled ? .prezefrenError : (isSelected ? .prezefrenPrimary : .prezefrenMutedForeground))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mode.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Text(mode.description)
                                            .font(.caption)
                                            .foregroundColor(.prezefrenMutedForeground)
                                    }
                                    
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Hardware capability status
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.prezefrenPrimary)
                            .font(.caption)
                        
                        Text("Input Device Capability:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.prezefrenMutedForeground)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text(audioDeviceManager.getInputCapabilityStatus())
                            .font(.caption)
                            .foregroundColor(audioDeviceManager.supportsStereoMode() ? .green : .orange)
                        
                        Spacer()
                    }
                    
                    if !audioDeviceManager.supportsStereoMode() && appState.audioMode == .goobero {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.prezefrenWarning)
                                    .font(.caption2)
                                
                                Text("Hardware Limitation Warning")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.prezefrenWarning)
                            }
                            
                            Text("Your current input device only supports mono audio. Stereo mode requires a device with 2+ channels. Consider using:")
                                .font(.caption2)
                                .foregroundColor(.prezefrenMutedForeground)
                            
                            Text("• USB audio interfaces with dual microphones")
                                .font(.caption2)
                                .foregroundColor(.prezefrenMutedForeground)
                            
                            Text("• Professional lavaliere mic systems")
                                .font(.caption2)
                                .foregroundColor(.prezefrenMutedForeground)
                        }
                        .padding(.top, 4)
                    }
                    
                    // Show Bluetooth-specific guidance
                    let bluetoothGuidance = audioDeviceManager.getBluetoothGuidance()
                    if !bluetoothGuidance.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.prezefrenPrimary)
                                    .font(.caption2)
                                
                                Text("Bluetooth Device Info")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.prezefrenPrimary)
                            }
                            
                            Text(bluetoothGuidance)
                                .font(.caption2)
                                .foregroundColor(.prezefrenMutedForeground)
                        }
                        .padding(.top, 4)
                    }
                }
                
                // CRITICAL: Real-time processing mode indicator for debugging
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(appState.isRecording ? .green : .gray)
                            .font(.caption)
                        
                        Text("Actual Processing Mode:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.prezefrenMutedForeground)
                        
                        Spacer()
                    }
                    
                    HStack {
                        let actualMode = appState.isRecording ? getActualProcessingMode() : "Not Recording"
                        let isCorrectMode = actualMode.lowercased().contains(appState.audioMode.rawValue.lowercased())
                        
                        Circle()
                            .frame(width: 6, height: 6)
                            .prezefrenStatusDot(isActive: isCorrectMode)
                        
                        Text(actualMode)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(isCorrectMode ? .green : .red)
                        
                        if !isCorrectMode && appState.isRecording {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.prezefrenError)
                                .font(.caption2)
                        }
                        
                        Spacer()
                    }
                    
                    if appState.isRecording && !getActualProcessingMode().lowercased().contains(appState.audioMode.rawValue.lowercased()) {
                        Text("⚠️ Mode mismatch detected! Selected \(appState.audioMode.rawValue) but processing as \(getActualProcessingMode())")
                            .font(.caption2)
                            .foregroundColor(.prezefrenError)
                            .padding(.top, 2)
                    }
                }
                
                // UNIVERSAL LANGUAGE SELECTION - Available in ALL modes
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.prezefrenSuccess)
                            .font(.caption)
                        
                        Text("Language Selection:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.prezefrenMutedForeground)
                        
                        Spacer()
                    }
                    
                    if appState.audioMode == .mono {
                        // Mono mode: Dynamic language selection based on transcription engine
                        HStack {
                            SearchableLanguagePicker.transcriptionPicker(
                                title: "Speech Recognition Language",
                                transcriptionEngine: appState.transcriptionEngine,
                                selectedLanguage: Binding(
                                    get: { monoLanguage },
                                    set: { newLanguage in
                                        monoLanguage = newLanguage
                                        updateMonoLanguage(newLanguage)
                                    }
                                )
                            )
                            .frame(minWidth: 200, maxWidth: 280)
                            
                            Spacer()
                        }
                        
                        Text("💡 Select the language you'll speak for better recognition")
                            .font(.caption2)
                            .foregroundColor(.prezefrenPrimary)
                            .padding(.top, 2)
                    } else if appState.audioMode == .goobero {
                        // Goobero mode: Left/Right channel languages (existing logic)
                        Text("📻 Configure individual channel languages below")
                            .font(.caption2)
                            .foregroundColor(.prezefrenAccent)
                    }
                }
                
                if appState.audioMode == .goobero {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Channel Language Assignment")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.prezefrenMutedForeground)
                        
                        // Left channel language assignment
                        HStack {
                            SearchableLanguagePicker.transcriptionPicker(
                                title: "Left Channel Language", 
                                transcriptionEngine: appState.transcriptionEngine,
                                selectedLanguage: Binding(
                                    get: { appState.leftChannelLanguage },
                                    set: { appState.setLeftChannelLanguage($0) }
                                )
                            )
                            .frame(minWidth: 200, maxWidth: 280)
                            
                            Text("(Left earbud)")
                                .font(.caption2)
                                .foregroundColor(.prezefrenMutedForeground)
                            
                            Spacer()
                        }
                        
                        // Right channel language assignment  
                        HStack {
                            SearchableLanguagePicker.transcriptionPicker(
                                title: "Right Channel Language",
                                transcriptionEngine: appState.transcriptionEngine,
                                selectedLanguage: Binding(
                                    get: { appState.rightChannelLanguage },
                                    set: { appState.setRightChannelLanguage($0) }
                                )
                            )
                            .frame(minWidth: 200, maxWidth: 280)
                            
                            Text("(Right earbud)")
                                .font(.caption2)
                                .foregroundColor(.prezefrenMutedForeground)
                            
                            Spacer()
                        }
                        
                        Text("💡 Tip: Assign languages to help improve transcription accuracy for each audio channel")
                            .font(.caption2)
                            .foregroundColor(.prezefrenPrimary)
                            .padding(.top, 4)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
    
    private var recordingControlCard: some View {
        ModernCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "mic")
                        .foregroundColor(.prezefrenWarning)
                        .font(.title2)
                    
                    Text("Recording Controls")
                        .prezefrenHeading()
                    
                    Spacer()
                }
                
                Button(action: {
                    Task {
                        if appState.isRecording {
                            await appState.stopRecording()
                        } else {
                            await appState.startRecording()
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: appState.isRecording ? "stop.fill" : "record.circle")
                            .font(.title2)
                        
                        Text(appState.isRecording ? "Stop Recording" : "Start Recording")
                            .font(.headline)
                    }
                }
.prezefrenRecordButton(isRecording: appState.isRecording)
            }
        }
    }
    
    // MARK: - Main Tab Cards (Operational Focus)
    
    private var recordingControlsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "waveform.circle")
                        .foregroundColor(.prezefrenPrimary)
                        .font(.title2)
                    
                    Text("Recording")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // Status indicator
                    HStack(spacing: 8) {
                        Circle()
                            .frame(width: 10, height: 10)
                            .prezefrenStatusDot(isActive: appState.isRecording)
                        
                        Text(appState.isRecording ? "Recording" : "Ready")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                // Main recording button
                Button(action: {
                    Task {
                        if appState.isRecording {
                            // Stop transcription recording
                            await appState.stopRecording()
                            
                            // Also stop audio recording if it's active
                            if appState.isRecordingToFile {
                                await appState.stopAudioRecording()
                            }
                        } else {
                            // Start transcription recording
                            await appState.startRecording()
                            
                            // Also start audio recording if enabled
                            if appState.audioRecordingEnabled {
                                await appState.startAudioRecording()
                            }
                        }
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: appState.isRecording ? "stop.fill" : "mic.fill")
                            .font(.title)
                        
                        Text(appState.isRecording ? "Stop Recording" : "Start Recording")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
.prezefrenRecordButton(isRecording: appState.isRecording)
                
                // Noise Suppression Slider for real-time audio testing
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Noise Suppression", systemImage: "speaker.wave.3.fill")
                            .font(.caption2)
                            .foregroundColor(.prezefrenMutedForeground)
                        
                        Spacer()
                        
                        Text("\(Int(appState.noiseSuppression * 100))%")
                            .font(.caption2)
                            .foregroundColor(.prezefrenMutedForeground)
                            .monospacedDigit()
                    }
                    
                    Slider(
                        value: Binding(
                            get: { appState.noiseSuppression },
                            set: { newValue in
                                appState.setNoiseSuppression(newValue)
                            }
                        ),
                        in: 0.0...1.0,
                        step: 0.05
                    ) {
                        Text("Noise Suppression")
                    } minimumValueLabel: {
                        Image(systemName: "speaker.fill")
                            .font(.caption2)
                            .foregroundColor(.prezefrenMutedForeground)
                    } maximumValueLabel: {
                        Image(systemName: "speaker.slash.fill")
                            .font(.caption2)
                            .foregroundColor(.prezefrenMutedForeground)
                    }
                    .accentColor(.blue)
                    
                    if appState.noiseSuppression > 0 {
                        Text("Test transcription above to adjust noise levels")
                            .font(.caption2)
                            .foregroundColor(.prezefrenMutedForeground)
                            .italic()
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.controlBackgroundColor))
                        .opacity(0.5)
                )
                
                // Language selector for extended mode
                HStack {
                    Spacer()
                    
                    if appState.audioMode == .mono {
                        // Single language picker for mono mode
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Speech Language")
                                .font(.caption2)
                                .foregroundColor(.prezefrenMutedForeground)
                            
                            SearchableLanguagePicker.transcriptionPicker(
                                title: "",
                                transcriptionEngine: appState.transcriptionEngine,
                                selectedLanguage: Binding(
                                    get: { monoLanguage },
                                    set: { newLanguage in
                                        monoLanguage = newLanguage
                                        updateMonoLanguage(newLanguage)
                                        print("🎤 Extended Mono language set to: \(newLanguage)")
                                    }
                                )
                            )
                            .frame(width: 180)
                        }
                    } else {
                        // Dual language pickers for stereo mode  
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Channel Languages")
                                .font(.caption2)
                                .foregroundColor(.prezefrenMutedForeground)
                            
                            HStack(spacing: 8) {
                                // Left channel language
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Left")
                                        .font(.caption2)
                                        .foregroundColor(.prezefrenPrimary)
                                    
                                    SearchableLanguagePicker.transcriptionPicker(
                                        title: "",
                                        transcriptionEngine: appState.transcriptionEngine,
                                        selectedLanguage: Binding(
                                            get: { leftChannelLanguage },
                                            set: { newLanguage in
                                                leftChannelLanguage = newLanguage
                                                updateStereoLanguages()
                                                print("🎤 Extended Left channel language set to: \(newLanguage)")
                                            }
                                        )
                                    )
                                    .frame(width: 120)
                                }
                                
                                // Right channel language
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Right") 
                                        .font(.caption2)
                                        .foregroundColor(.prezefrenWarning)
                                    
                                    SearchableLanguagePicker.transcriptionPicker(
                                        title: "",
                                        transcriptionEngine: appState.transcriptionEngine,
                                        selectedLanguage: Binding(
                                            get: { rightChannelLanguage },
                                            set: { newLanguage in
                                                rightChannelLanguage = newLanguage
                                                updateStereoLanguages()
                                                print("🎤 Extended Right channel language set to: \(newLanguage)")
                                            }
                                        )
                                    )
                                    .frame(width: 120)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    private var currentConfigurationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "gearshape.2")
                        .foregroundColor(.prezefrenAccent)
                        .font(.title2)
                    
                    Text("Current Configuration")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("Edit in Preferences") {
                        MenuBarManager.shared.showPreferencesWindow()
                    }
                    .prezefrenGhostButton()
                }
                
                VStack(spacing: 12) {
                    ConfigRow(title: "Translation Mode", value: PreferencesManager.shared.effectiveTranslationMode.rawValue, icon: "globe")
                    ConfigRow(title: "Audio Mode", value: PreferencesManager.shared.audioMode.rawValue, icon: "speaker.wave.2")
                    ConfigRow(title: "Apple Translation", value: PreferencesManager.shared.canUseAppleTranslation ? "Available" : "Unavailable", icon: "applelogo")
                    ConfigRow(title: "Gemini API", value: PreferencesManager.shared.isGeminiConfigured ? "Configured" : "Not Configured", icon: "sparkles")
                }
            }
        }
    }
    
    // MARK: - Window Management Cards
    
    private var windowTemplateCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "macwindow.badge.plus")
                        .foregroundColor(.prezefrenAccent)
                        .font(.title2)
                    
                    Text("Window Templates")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    ForEach(WindowTemplate.allCases, id: \.self) { template in
                        TemplateButton(template: template) {
                            appState.addSubtitleWindow(template: template)
                            // Ensure AppState is updated before creating panel
                            DispatchQueue.main.async {
                                if let newWindow = appState.subtitleWindows.last {
                                    print("🪟 Creating panel for window: \(newWindow.name) at position: \(newWindow.position)")
                                    panelManager.showPanel(for: newWindow.id, appState: appState)
                                    print("✅ Panel shown for window: \(newWindow.id)")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var windowListCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundColor(.prezefrenSuccess)
                        .font(.title2)
                    
                    Text("Subtitle Windows")
                        .prezefrenHeading()
                    
                    Spacer()
                    
                    Text("\(appState.subtitleWindows.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
                
                if appState.subtitleWindows.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "macwindow.on.rectangle")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        
                        Text("No subtitle windows")
                            .font(.headline)
                            .foregroundColor(.prezefrenMutedForeground)
                        
                        Text("Create a window using the templates above")
                            .font(.caption)
                            .foregroundColor(.prezefrenMutedForeground)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ForEach(appState.subtitleWindows) { window in
                        EnhancedSubtitleWindowRow(
                            window: window,
                            onToggleVisibility: { 
                                appState.toggleWindowVisibility(window)
                                updatePanelVisibility(for: window)
                            },
                            onToggleMode: { appState.toggleWindowMode(window) },
                            onToggleTranslation: { appState.toggleWindowTranslation(window) },
                            onLanguageChange: { language in appState.setWindowTargetLanguage(window, language: language) },
                            onChannelChange: { channel in appState.setWindowAudioChannel(window, channel: channel) },
                            onFontSizeChange: { fontSize in appState.setWindowFontSize(window, fontSize: fontSize) },
                            onRemove: { 
                                panelManager.removePanel(for: window.id)
                                appState.removeSubtitleWindow(window) 
                            }
                        )
                    }
                }
            }
        }
    }
    
    private var windowBatchControlsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "square.3.layers.3d")
                        .foregroundColor(.prezefrenWarning)
                        .font(.title2)
                    
                    Text("Batch Controls")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    Button("Show All") {
                        for window in appState.subtitleWindows {
                            if !window.isVisible {
                                appState.toggleWindowVisibility(window)
                                updatePanelVisibility(for: window)
                            }
                        }
                    }
                    .prezefrenPrimaryButton()
                    
                    Button("Hide All") {
                        for window in appState.subtitleWindows {
                            if window.isVisible {
                                appState.toggleWindowVisibility(window)
                                updatePanelVisibility(for: window)
                            }
                        }
                    }
                    .prezefrenSecondaryButton()
                    
                    Button("Reset Positions") {
                        // TODO: Implement reset positions
                    }
                    .prezefrenSecondaryButton()
                }
            }
        }
    }
    
    // MARK: - Translation Cards
    
    private var apiKeyCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "key")
                        .foregroundColor(.prezefrenPrimary)
                        .font(.title2)
                    
                    Text("API Configuration")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // Status indicator
                    Image(systemName: EnvironmentConfig.shared.getGeminiAPIKey()?.isEmpty == false ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(EnvironmentConfig.shared.getGeminiAPIKey()?.isEmpty == false ? .green : .orange)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    // API Key Input Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gemini API Key:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack {
                            SecureField("Enter your Gemini API key...", text: $apiKeyInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(.body, design: .monospaced))
                            
                            Button("Save") {
                                saveAPIKey()
                            }
                            .prezefrenPrimaryButton()
                            .disabled(apiKeyInput.isEmpty)
                        }
                    }
                    
                    // Status Display
                    if EnvironmentConfig.shared.getGeminiAPIKey()?.isEmpty == false {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.prezefrenSuccess)
                            Text("API key configured and ready")
                                .font(.subheadline)
                                .foregroundColor(.prezefrenSuccess)
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.prezefrenWarning)
                            Text("API key required for translation")
                                .font(.subheadline)
                                .foregroundColor(.prezefrenWarning)
                        }
                    }
                    
                    Link("Get your free API key from Google AI Studio", destination: URL(string: "https://makersuite.google.com/app/apikey")!)
                        .font(.caption)
                        .foregroundColor(.prezefrenPrimary)
                }
            }
        }
    }
    
    private var translationControlsCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.prezefrenAccent)
                        .font(.title2)
                    
                    Text("Translation Settings")
                        .prezefrenHeading()
                    
                    Spacer()
                }
                
                Text("Translation settings are configured per window in the Windows tab")
                    .font(.subheadline)
                    .foregroundColor(.prezefrenMutedForeground)
                
                if !appState.subtitleWindows.filter(\.translationEnabled).isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Active Translations:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(appState.subtitleWindows.filter(\.translationEnabled)) { window in
                            HStack {
                                Text(window.name)
                                    .font(.caption)
                                Spacer()
                                Text("→ \(window.targetLanguage.uppercased())")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var translationModeCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "cpu")
                        .foregroundColor(.prezefrenWarning)
                        .font(.title2)
                    
                    Text("Translation Engine")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // Status indicator
                    Circle()
                        .frame(width: 8, height: 8)
                        .prezefrenStatusDot(isActive: appState.enhancedTranslationService.config.enableAppleNative)
                    
                    Text(appState.enhancedTranslationService.config.mode.rawValue)
                        .font(.caption)
                        .foregroundColor(.prezefrenMutedForeground)
                }
                
                // Translation mode selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose your translation engine:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(TranslationMode.allCases, id: \.self) { mode in
                        HStack {
                            Button(action: {
                                appState.enhancedTranslationService.setTranslationMode(mode)
                            }) {
                                HStack {
                                    Image(systemName: appState.enhancedTranslationService.config.mode == mode ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(appState.enhancedTranslationService.config.mode == mode ? .blue : .secondary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mode.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text(mode.description)
                                            .font(.caption)
                                            .foregroundColor(.prezefrenMutedForeground)
                                    }
                                    
                                    Spacer()
                                    
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Status display - simplified
                VStack(alignment: .leading, spacing: 8) {
                    Text(appState.enhancedTranslationService.statusDescription)
                        .font(.caption)
                        .foregroundColor(.prezefrenMutedForeground)
                }
            }
        }
    }
    
    private var advancedTranslationCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "gearshape.2")
                        .foregroundColor(.prezefrenAccent)
                        .font(.title2)
                    
                    Text("Advanced Features")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // Status badge for Apple Native mode
                    if appState.enhancedTranslationService.config.mode == .appleNative {
                        Text("OFFLINE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.prezefrenSuccess)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("⚠️ These features are experimental and may affect app stability.")
                        .font(.caption)
                        .foregroundColor(.prezefrenWarning)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                    
                    
                    // Simplified settings - core functionality only
                    Text("Translation settings have been simplified for reliability. Only Apple Native (offline) and Gemini API (cloud) modes are available.")
                        .font(.caption)
                        .foregroundColor(.prezefrenMutedForeground)
                        .padding(.vertical, 8)
                }
            }
        }
    }
    
    // MARK: - Compact Mode Cards
    
    private var quickControlsCard: some View {
        ModernCard {
            HStack(spacing: 16) {
                Button(action: {
                    Task {
                        if appState.isRecording {
                            await appState.stopRecording()
                        } else {
                            await appState.startRecording()
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: appState.isRecording ? "stop.fill" : "record.circle")
                        Text(appState.isRecording ? "Stop" : "Record")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(appState.isRecording ? .red : .green)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                // Language selector(s) next to recording button - varies by audio mode
                if appState.audioMode == .mono {
                    // Single language picker for mono mode
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Speech Language")
                            .font(.caption2)
                            .foregroundColor(.prezefrenMutedForeground)
                        
                        SearchableLanguagePicker.transcriptionPicker(
                            title: "",
                            transcriptionEngine: appState.transcriptionEngine,
                            selectedLanguage: Binding(
                                get: { monoLanguage },
                                set: { newLanguage in
                                    monoLanguage = newLanguage
                                    updateMonoLanguage(newLanguage)
                                    print("🎤 Compact Mono language set to: \(newLanguage)")
                                }
                            )
                        )
                        .frame(width: 160)
                    }
                } else {
                    // Dual language pickers for stereo mode  
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Channel Languages")
                            .font(.caption2)
                            .foregroundColor(.prezefrenMutedForeground)
                        
                        HStack(spacing: 8) {
                            // Left channel language
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Left")
                                    .font(.caption2)
                                    .foregroundColor(.prezefrenPrimary)
                                
                                SearchableLanguagePicker.transcriptionPicker(
                                    title: "",
                                    transcriptionEngine: appState.transcriptionEngine,
                                    selectedLanguage: Binding(
                                        get: { leftChannelLanguage },
                                        set: { newLanguage in
                                            leftChannelLanguage = newLanguage
                                            updateStereoLanguages()
                                            print("🎤 Left channel language set to: \(newLanguage)")
                                        }
                                    )
                                )
                                .frame(width: 120)
                            }
                            
                            // Right channel language
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Right") 
                                    .font(.caption2)
                                    .foregroundColor(.prezefrenWarning)
                                
                                SearchableLanguagePicker.transcriptionPicker(
                                    title: "",
                                    transcriptionEngine: appState.transcriptionEngine,
                                    selectedLanguage: Binding(
                                        get: { rightChannelLanguage },
                                        set: { newLanguage in
                                            rightChannelLanguage = newLanguage
                                            updateStereoLanguages()
                                            print("🎤 Right channel language set to: \(newLanguage)")
                                        }
                                    )
                                )
                                .frame(width: 120)
                            }
                        }
                    }
                }
                
                // Noise Suppression Slider - Compact Version
                VStack(alignment: .leading, spacing: 4) {
                    Text("Noise Suppression")
                        .font(.caption2)
                        .foregroundColor(.prezefrenMutedForeground)
                    
                    VStack(spacing: 4) {
                        HStack {
                            Text("0%")
                                .font(.caption2)
                                .foregroundColor(.prezefrenMutedForeground)
                            
                            Slider(
                                value: Binding(
                                    get: { appState.noiseSuppression },
                                    set: { newValue in
                                        appState.setNoiseSuppression(newValue)
                                    }
                                ),
                                in: 0.0...1.0,
                                step: 0.05
                            )
                            .accentColor(.blue)
                            
                            Text("100%")
                                .font(.caption2)
                                .foregroundColor(.prezefrenMutedForeground)
                        }
                        
                        Text("\(Int(appState.noiseSuppression * 100))%")
                            .font(.caption2)
                            .foregroundColor(.prezefrenMutedForeground)
                            .monospacedDigit()
                    }
                }
                .frame(width: 120)
                
                Spacer()
                
                Button("Add Window") {
                    appState.addSubtitleWindow()
                }
                .prezefrenPrimaryButton()
            }
        }
    }
    
    private var windowQuickControlsCard: some View {
        ModernCard {
            VStack(spacing: 12) {
                HStack {
                    Text("Quick Window Controls")
                        .font(.headline)
                    Spacer()
                }
                
                HStack(spacing: 8) {
                    Button("Show All") {
                        for window in appState.subtitleWindows {
                            if !window.isVisible {
                                appState.toggleWindowVisibility(window)
                                updatePanelVisibility(for: window)
                            }
                        }
                    }
                    .prezefrenPrimaryButton()
                    
                    Button("Hide All") {
                        for window in appState.subtitleWindows {
                            if window.isVisible {
                                appState.toggleWindowVisibility(window)
                                updatePanelVisibility(for: window)
                            }
                        }
                    }
                    .prezefrenSecondaryButton()
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func saveAPIKey() {
        appState.setAPIKey(apiKeyInput)
        print("🔑 API key saved: \(apiKeyInput.prefix(8))...")
        apiKeyInput = "" // Clear input after saving
    }
    
    
    private func updatePanelVisibility(for window: SubtitleWindow) {
        // Get the current state from AppState, not the passed window parameter
        if let currentWindow = appState.subtitleWindows.first(where: { $0.id == window.id }) {
            if currentWindow.isVisible {
                panelManager.showPanel(for: window.id, appState: appState)
            } else {
                panelManager.hidePanel(for: window.id)
            }
        }
    }
    
    
    // CRITICAL: Function to detect actual processing mode from logs/state
    private func getActualProcessingMode() -> String {
        // This function analyzes the current audio processing state to determine
        // what mode is actually being used (vs what the UI shows)
        
        guard appState.isRecording else {
            return "Not Recording"
        }
        
        // Check if we have recent transcription activity to determine mode
        let hasLeftChannel = !appState.leftChannelTranscription.isEmpty
        let hasRightChannel = !appState.rightChannelTranscription.isEmpty
        let hasMixedChannel = !appState.currentTranscription.isEmpty
        
        // Analyze recent transcription patterns
        if appState.audioMode == .goobero {
            if hasLeftChannel || hasRightChannel {
                return "Goobero Mode (L/R Processing)"
            } else if hasMixedChannel {
                return "Mixed Channel (Stereo Fallback)"
            } else {
                return "Stereo Mode (No Activity)"
            }
        } else {
            // Mono mode
            if hasMixedChannel {
                return "Mono Mode (Active)"
            } else {
                return "Mono Mode (No Activity)"
            }
        }
    }
    
    // MARK: - Audio Mode Helper Functions
    
    private func getModeIcon(_ mode: AudioMode) -> String {
        switch mode {
        case .mono:
            return "waveform"
        case .goobero:
            return "waveform.path"
        }
    }
    
    private func getModeColor(_ mode: AudioMode) -> Color {
        switch mode {
        case .mono:
            return .blue
        case .goobero:
            return .purple
        }
    }
    
    // MARK: - Language Helper Functions
    
    private func getSupportedWhisperLanguages() -> [(String, String)] {
        // Use comprehensive Whisper language list from LanguageService
        return LanguageService.whisperLanguages
    }
    
    private func updateMonoLanguage(_ language: String) {
        print("🌍 Mono language updated to: \(language)")
        // CRITICAL FIX: Pass language hint to AudioEngine for better Whisper recognition
        Task {
            await appState.audioEngine.setMonoLanguage(language)
        }
        // CRITICAL FIX: Update AppState to use correct source language for translation
        appState.setMonoInputLanguage(language)
    }
    
    private func updateStereoLanguages() {
        print("🌍 Stereo languages updated - Left: \(leftChannelLanguage), Right: \(rightChannelLanguage)")
        // TODO: Pass stereo language hints to AudioEngine for better Whisper recognition
        // This will require updating AudioEngine to support per-channel language hints
        Task {
            // For now, just pass the left channel language as the primary language
            await appState.audioEngine.setMonoLanguage(leftChannelLanguage)
            print("⚠️ Stereo language support limited - using left channel language (\(leftChannelLanguage)) as primary")
        }
        // CRITICAL FIX: Update AppState to use correct source languages for translation
        appState.setLeftChannelLanguage(leftChannelLanguage)
        appState.setRightChannelLanguage(rightChannelLanguage)
    }
    
    // MARK: - Audio Device Cards
    
    private var audioDeviceSelectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "headphones")
                        .foregroundColor(.prezefrenPrimary)
                        .font(.title2)
                    
                    Text("Audio Device Selection")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("Refresh") {
                        Task {
                            await audioDeviceManager.scanAudioDevices()
                        }
                    }
                    .prezefrenGhostButton()
                }
                
                // Input Device Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Input Device (Microphone)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Input Device", selection: Binding(
                        get: { audioDeviceManager.selectedInputDevice },
                        set: { audioDeviceManager.selectInputDevice($0!) }
                    )) {
                        ForEach(audioDeviceManager.inputDevices) { device in
                            HStack {
                                Text(device.name)
                                if device.isDefault {
                                    Text("(Default)")
                                        .foregroundColor(.prezefrenMutedForeground)
                                }
                                Spacer()
                                Text("\(device.channelCount) ch")
                                    .foregroundColor(.prezefrenMutedForeground)
                                    .font(.caption)
                            }
                            .tag(device as AudioDevice?)
                        }
                    }
                    .pickerStyle(.menu)
                    .prezefrenPicker()
                    
                    if let selectedInput = audioDeviceManager.selectedInputDevice {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.prezefrenPrimary)
                                .font(.caption)
                            Text("Selected: \(selectedInput.name) (\(selectedInput.channelCount) channels)")
                                .font(.caption)
                                .foregroundColor(.prezefrenMutedForeground)
                        }
                    }
                }
                
                Divider()
                
                // Output Device Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Output Device (Speakers)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Output Device", selection: Binding(
                        get: { audioDeviceManager.selectedOutputDevice },
                        set: { audioDeviceManager.selectOutputDevice($0!) }
                    )) {
                        ForEach(audioDeviceManager.outputDevices) { device in
                            HStack {
                                Text(device.name)
                                if device.isDefault {
                                    Text("(Default)")
                                        .foregroundColor(.prezefrenMutedForeground)
                                }
                                Spacer()
                                Text("\(device.channelCount) ch")
                                    .foregroundColor(.prezefrenMutedForeground)
                                    .font(.caption)
                            }
                            .tag(device as AudioDevice?)
                        }
                    }
                    .pickerStyle(.menu)
                    .prezefrenPicker()
                    
                    if let selectedOutput = audioDeviceManager.selectedOutputDevice {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.prezefrenPrimary)
                                .font(.caption)
                            Text("Selected: \(selectedOutput.name)")
                                .font(.caption)
                                .foregroundColor(.prezefrenMutedForeground)
                        }
                    }
                }
            }
        }
    }
    
    
    private var simplePassthroughCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "speaker.wave.2.circle")
                    .foregroundColor(.prezefrenSuccess)
                    .font(.title2)
                
                Text("Enable Audio Passthrough")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { audioDeviceManager.passthroughEnabled },
                    set: { enabled in
                        audioDeviceManager.passthroughEnabled = enabled
                        Task {
                            await appState.audioEngine.setPassthroughEnabled(enabled)
                            if enabled, let outputDevice = audioDeviceManager.selectedOutputDevice {
                                await appState.audioEngine.setOutputDevice(outputDevice)
                            }
                        }
                    }
                ))
                .toggleStyle(.switch)
            }
            .padding(.vertical, 8)
        }
    }
    
    private var audioRecordingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: appState.isRecordingToFile ? "record.circle.fill" : "record.circle")
                        .foregroundColor(appState.isRecordingToFile ? .red : .orange)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Record Audio to File")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if appState.isRecordingToFile {
                            HStack {
                                Text("Recording to file...")
                                    .font(.caption)
                                    .foregroundColor(.prezefrenError)
                                Spacer()
                                Text(String(format: "%.1fs", appState.audioRecorder.recordingDuration))
                                    .font(.caption)
                                    .foregroundColor(.prezefrenError)
                                    .monospacedDigit()
                            }
                        } else if appState.audioRecordingEnabled {
                            Text("Ready to record audio")
                                .font(.caption)
                                .foregroundColor(.prezefrenMutedForeground)
                        } else {
                            Text("Enable to record audio to file")
                                .font(.caption)
                                .foregroundColor(.prezefrenMutedForeground)
                        }
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { appState.audioRecordingEnabled },
                        set: { enabled in
                            Task {
                                await appState.setAudioRecordingEnabled(enabled)
                            }
                        }
                    ))
                    .toggleStyle(PrezefrenToggleStyle())
                }
                
                // Volume control slider (only visible when recording)
                if appState.isRecordingToFile {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "speaker.wave.1")
                                .foregroundColor(.gray)
                                .font(.caption)
                            
                            Text("Passthrough Volume")
                                .font(.caption)
                                .foregroundColor(.prezefrenMutedForeground)
                            
                            Spacer()
                            
                            Text("\(Int(appState.passthroughVolume * 100))%")
                                .font(.caption)
                                .foregroundColor(.prezefrenMutedForeground)
                                .monospacedDigit()
                        }
                        
                        HStack {
                            Image(systemName: "speaker")
                                .foregroundColor(.gray)
                                .font(.caption2)
                            
                            Slider(value: Binding(
                                get: { appState.passthroughVolume },
                                set: { volume in
                                    Task {
                                        await appState.setPassthroughVolume(volume)
                                    }
                                }
                            ), in: 0.0...1.0)
                            .accentColor(.blue)
                            
                            Image(systemName: "speaker.wave.3")
                                .foregroundColor(.gray)
                                .font(.caption2)
                        }
                        
                        Text("💡 Set to 0% for silent recording, 100% for full monitoring")
                            .font(.caption2)
                            .foregroundColor(.prezefrenMutedForeground)
                            .opacity(0.8)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var audioPassthroughCard: some View {
        ModernCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "speaker.wave.2.circle")
                        .foregroundColor(.prezefrenSuccess)
                        .font(.title2)
                    
                    Text("Audio Passthrough")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Toggle("Enable Audio Passthrough", isOn: Binding(
                            get: { audioDeviceManager.passthroughEnabled },
                            set: { enabled in
                                audioDeviceManager.passthroughEnabled = enabled
                                Task {
                                    await appState.audioEngine.setPassthroughEnabled(enabled)
                                    if enabled, let outputDevice = audioDeviceManager.selectedOutputDevice {
                                        await appState.audioEngine.setOutputDevice(outputDevice)
                                    }
                                }
                            }
                        ))
                        .toggleStyle(PrezefrenToggleStyle())
                        
                        Spacer()
                    }
                    
                    if audioDeviceManager.passthroughEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("💡 Passthrough Information")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.prezefrenPrimary)
                            
                            Text("• Audio from your microphone will be routed to the selected output device")
                                .font(.caption2)
                                .foregroundColor(.prezefrenMutedForeground)
                            
                            Text("• In goobero mode, left and right channels will be mixed for speaker output")
                                .font(.caption2)
                                .foregroundColor(.prezefrenMutedForeground)
                            
                            Text("• This allows others to hear both speakers through a shared speaker system")
                                .font(.caption2)
                                .foregroundColor(.prezefrenMutedForeground)
                        }
                        .padding(.top, 4)
                    }
                    
                    if !audioDeviceManager.passthroughEnabled {
                        Text("Enable passthrough to route microphone audio to speakers for shared listening scenarios.")
                            .font(.caption)
                            .foregroundColor(.prezefrenMutedForeground)
                    }
                }
            }
        }
    }
    
    
}

// MARK: - Supporting Views

struct TemplateButton: View {
    let template: WindowTemplate
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: template.icon)
                    .font(.title2)
                    .foregroundColor(.prezefrenPrimary)
                
                Text(template.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                
                Text(template.description)
                    .font(.caption2)
                    .foregroundColor(.prezefrenMutedForeground)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct EnhancedSubtitleWindowRow: View {
    let window: SubtitleWindow
    let onToggleVisibility: () -> Void
    let onToggleMode: () -> Void
    let onToggleTranslation: () -> Void
    let onLanguageChange: (String) -> Void
    let onChannelChange: (AudioChannel) -> Void
    let onFontSizeChange: (CGFloat) -> Void
    let onRemove: () -> Void
    
    // Access current translation mode for dynamic language selection
    private var currentTranslationService: TranslationServiceType {
        switch PreferencesManager.shared.effectiveTranslationMode {
        case .geminiAPI:
            return .geminiAPI
        case .appleNative:
            return .appleNative
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // Window info
                VStack(alignment: .leading, spacing: 4) {
                    Text(window.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 8) {
                        // Template badge
                        Text(window.template.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .cornerRadius(4)
                        
                        // Mode badge  
                        Text(window.isAdditive ? "Additive" : "Simple")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(window.isAdditive ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2))
                            .cornerRadius(4)
                        
                        // Status
                        Text(window.isVisible ? "Visible" : "Hidden")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(window.isVisible ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                            .cornerRadius(4)
                        
                        // Translation mode badge
                        Text("Subtitles")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.2))
                            .cornerRadius(4)
                        
                        if window.translationEnabled {
                            Text("→ \(window.targetLanguage.uppercased())")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
                
                // Controls
                HStack(spacing: 8) {
                    Button(action: onToggleVisibility) {
                        Image(systemName: window.isVisible ? "eye.fill" : "eye.slash")
                            .foregroundColor(window.isVisible ? .green : .gray)
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: onToggleMode) {
                        Text(window.isAdditive ? "A" : "S")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(window.isAdditive ? Color.blue : Color.orange)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: onToggleTranslation) {
                        Image(systemName: "globe")
                            .foregroundColor(window.translationEnabled ? .purple : .gray)
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: onRemove) {
                        Image(systemName: "trash")
                            .foregroundColor(.prezefrenError)
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            // Subtitle window type indicator
            HStack {
                Text("Window Type:")
                    .font(.caption)
                    .foregroundColor(.prezefrenMutedForeground)
                
                Text("Translation Display")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                
                Spacer()
            }
            .padding(.leading, 8)
            
            // Translation controls (when enabled)
            if window.translationEnabled {
                HStack {
                    // Dynamic translation language picker based on current translation service
                    Group {
                        if currentTranslationService == .appleNative && ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 15 {
                            // Use Apple Translation with runtime availability checking
                            if #available(macOS 15.0, *) {
                                SearchableLanguagePicker.appleTranslationPicker(
                                    title: "Translation Target Language",
                                    selectedLanguage: Binding(
                                        get: { window.targetLanguage },
                                        set: onLanguageChange
                                    )
                                )
                            } else {
                                // Fallback to static list for older macOS versions
                                SearchableLanguagePicker.translationPicker(
                                    title: "Translation Target Language",
                                    translationService: .appleNative,
                                    selectedLanguage: Binding(
                                        get: { window.targetLanguage },
                                        set: onLanguageChange
                                    )
                                )
                            }
                        } else {
                            // Use Gemini or static Apple Native list
                            SearchableLanguagePicker.translationPicker(
                                title: "Translation Target Language",
                                translationService: currentTranslationService,
                                selectedLanguage: Binding(
                                    get: { window.targetLanguage },
                                    set: onLanguageChange
                                )
                            )
                        }
                    }
                    .frame(minWidth: 200, maxWidth: 280)
                    
                    Spacer()
                }
                .padding(.leading, 8)
            }
            
            // Font size controls
            HStack {
                Text("Font Size:")
                    .font(.caption)
                    .foregroundColor(.prezefrenMutedForeground)
                
                HStack(spacing: 8) {
                    Button("−") {
                        onFontSizeChange(max(12, window.fontSize - 2))
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.prezefrenPrimary)
                    
                    Text("\(Int(window.fontSize))pt")
                        .font(.caption)
                        .frame(minWidth: 30)
                    
                    Button("+") {
                        onFontSizeChange(min(72, window.fontSize + 2))
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.prezefrenPrimary)
                }
                
                Spacer()
            }
            .padding(.leading, 8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .prezefrenWindowItem()
    }
}

// MARK: - Configuration Row Component

struct ConfigRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.prezefrenPrimary)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.prezefrenMutedForeground)
        }
        .padding(.vertical, 4)
    }
}

// Preview removed due to macro compilation issues