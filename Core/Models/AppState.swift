import Foundation
import SwiftUI
import AppKit
import Darwin
import AVFoundation

enum AudioMode: String, CaseIterable, Codable {
    case mono = "Mono"
    case goobero = "Goobero"
    
    var description: String {
        switch self {
        case .mono: return "Single microphone input"
        case .goobero: return "Dual channel processing with VAD (Emma/Alex)"
        }
    }
}

enum TranscriptionEngine: String, CaseIterable, Codable {
    case whisper = "Whisper"
    case appleSpeech = "Apple Speech"
    case assembly = "AssemblyAI"
    
    var description: String {
        switch self {
        case .whisper: return "Whisper.cpp (Local AI Model)"
        case .appleSpeech: return "Apple Speech Recognition (On-Device)"
        case .assembly: return "AssemblyAI (Cloud Streaming)"
        }
    }
    
    var icon: String {
        switch self {
        case .whisper: return "brain.head.profile"
        case .appleSpeech: return "applelogo"
        case .assembly: return "cloud.fill"
        }
    }
}

enum AudioChannel: String, CaseIterable, Codable {
    case mixed = "Mixed"
    case left = "Left"
    case right = "Right"
    
    var displayName: String {
        return self.rawValue
    }
}

struct SubtitleWindow: Identifiable, Codable {
    let id: UUID
    var name: String
    var isAdditive: Bool
    var isVisible: Bool = true
    var translationEnabled: Bool = false
    var targetLanguage: String = "es" // Default to Spanish
    var audioChannel: AudioChannel = .mixed // Which audio channel this window listens to
    var configuration: WindowConfiguration
    
    init(name: String, isAdditive: Bool, template: WindowTemplate = .custom, screenSize: CGSize = CGSize(width: 1920, height: 1080)) {
        self.id = UUID()
        self.name = name
        self.isAdditive = isAdditive
        self.configuration = WindowConfiguration(template: template, screenSize: screenSize, name: name)
    }
    
    // Convenience accessors for common configuration properties
    var opacity: Double {
        get { configuration.opacity }
        set { configuration.opacity = newValue }
    }
    
    var fontSize: CGFloat {
        get { configuration.fontSize }
        set { configuration.fontSize = newValue }
    }
    
    var fontFamily: String {
        get { configuration.fontFamily }
        set { configuration.fontFamily = newValue }
    }
    
    var template: WindowTemplate {
        get { configuration.template }
        set { configuration.template = newValue }
    }
    
    var position: CGPoint {
        get { configuration.position }
        set { configuration.position = newValue }
    }
    
    var size: CGSize {
        get { configuration.size }
        set { configuration.size = newValue }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var subtitleWindows: [SubtitleWindow] = []
    @Published var isRecording = false
    @Published var audioMode: AudioMode = .mono
    @Published var transcriptionEngine: TranscriptionEngine = .whisper
    
    // Channel language assignment for better transcription
    @Published var leftChannelLanguage: String = "en" // Default English
    @Published var rightChannelLanguage: String = "en" // Default English
    
    // Input language for translation (mono mode uses this)
    @Published var monoInputLanguage: String = "en" // Default English
    
    // Mixed/Mono channel transcription (legacy)
    @Published var currentTranscription = ""
    @Published var historicalTranscription = ""
    @Published var currentTranslation = ""
    @Published var historicalTranslation = ""
    
    // Goobero channel-specific transcription
    @Published var leftChannelTranscription = ""
    @Published var rightChannelTranscription = ""
    @Published var leftChannelTranslation = ""
    @Published var rightChannelTranslation = ""
    @Published var leftChannelHistorical = ""
    @Published var rightChannelHistorical = ""
    
    // CRITICAL FIX: Per-language translation storage
    @Published var translationsByLanguage: [String: String] = [:]
    @Published var historicalTranslationsByLanguage: [String: String] = [:]
    
    // Word-by-word animation configuration
    @Published var wordStreamingConfig: WordStreamingConfig = .default
    
    // AssemblyAI Integration - Isolated state management
    @Published var assemblyAILiveText = ""      // Partial transcriptions for real-time display
    @Published var assemblyAIFinalText = ""     // Final confirmed transcriptions
    @Published var assemblyAIHistorical = ""    // Accumulated historical transcriptions
    @Published var assemblyAIConnectionState: String = "Disconnected"
    
    // Translation throttling to prevent API overload
    private var activeTranslationTasks: Set<String> = []
    private var lastTranslationTime: [String: Date] = [:]
    private let translationCooldown: TimeInterval = 1.0 // Minimum 1 second between translations per language
    private var partialTranslationTask: Task<Void, Never>?
    
    @Published var isModelLoading = false
    @Published var modelLoadingProgress: Double = 0.0
    
    // Audio recording
    @Published var audioRecorder = AudioRecorder()
    @Published var isRecordingToFile = false
    @Published var audioRecordingEnabled = false
    
    private let _audioEngine = SimpleAudioEngine()
    
    // Public accessor for audioEngine (maintained for UI compatibility)
    var audioEngine: SimpleAudioEngine {
        return _audioEngine
    }
    @Published var enhancedTranslationService = EnhancedTranslationService()
    @Published var assemblyAIService = AssemblyAITranscriptionService(apiKey: "")
    
    // CRITICAL MEMORY MANAGEMENT: Enhanced limits and cleanup (reduced for AssemblyAI)
    private let maxContextLength = 800   // Limit context size to 800 chars
    private let retainLength = 600       // Amount to retain after truncation (600 chars as requested)
    private let maxWindowHistory = 1000  // Maximum history per window
    private let retainWindowHistory = 800 // Amount to retain after window cleanup
    
    // Memory cleanup timer
    private var memoryCleanupTimer: Timer?
    
    // Memory monitoring
    @Published var memoryUsageMB: Double = 0.0
    @Published var memoryPressure: String = "Normal"
    private var memoryTimer: Timer?
    
    // Audio device management integration
    private let audioDeviceManager = AudioDeviceManager.shared
    
    // CRITICAL FIX 7: Resource monitoring integration
    private let resourceMonitor = ResourceMonitor()
    
    // Noise suppression
    @Published var noiseSuppression: Double = 0.0 // 0.0 to 1.0
    
    // Recording state management
    @Published var recordingError: String?
    @Published var isRecovering = false
    private var isHandlingDeviceChange = false
    
    @Published var currentRecordingFile: URL?
    @Published var passthroughVolume: Double = 1.0 // 0.0 to 1.0 (only visible during recording)
    private var originalPassthroughState: Bool = false // Store user's original passthrough preference
    
    init() {
        // Load settings from preferences
        transcriptionEngine = PreferencesManager.shared.transcriptionEngine
        audioMode = PreferencesManager.shared.audioMode
        
        startMemoryMonitoring()
        setupAudioDeviceCallbacks()
        startResourceMonitoring()
        setupAssemblyAIIntegration()
        
        Task {
            await _audioEngine.initialize()
        }
    }
    
    private func setupAudioDeviceCallbacks() {
        // Set up callbacks for device disconnections
        audioDeviceManager.deviceDisconnectedCallback = { [weak self] in
            await self?.handleAudioDeviceDisconnection()
        }
        
        audioDeviceManager.audioEngineUpdateCallback = { [weak self] device in
            await self?.handleAudioDeviceChange(device: device)
        }
        
        audioDeviceManager.passthroughUpdateCallback = { [weak self] enabled in
            await self?.handlePassthroughChange(enabled: enabled)
        }
    }
    
    private func setupAssemblyAIIntegration() {
        // AssemblyAI service is configured through SimpleAudioEngine when needed
        
        // Set up AssemblyAI callbacks for isolated pipeline
        assemblyAIService.partialTranscriptionCallback = { [weak self] transcript in
            Task { @MainActor in
                self?.handleAssemblyAIPartialTranscription(transcript)
            }
        }
        
        assemblyAIService.transcriptionCallback = { [weak self] transcript in
            Task { @MainActor in
                self?.handleAssemblyAIFinalTranscription(transcript)
            }
        }
        
        // Callback-based approach only (no NotificationCenter duplication)
        
        print("🔗 AssemblyAI integration configured")
    }
    
    func addSubtitleWindow(template: WindowTemplate = .custom) {
        // Get screen size for proper window positioning
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        
        let newWindow = SubtitleWindow(
            name: "Subtitle Window \(subtitleWindows.count + 1)",
            isAdditive: false,
            template: template,
            screenSize: screenSize
        )
        subtitleWindows.append(newWindow)
    }
    
    func removeSubtitleWindow(_ window: SubtitleWindow) {
        subtitleWindows.removeAll { $0.id == window.id }
    }
    
    func toggleWindowVisibility(_ window: SubtitleWindow) {
        if let index = subtitleWindows.firstIndex(where: { $0.id == window.id }) {
            subtitleWindows[index].isVisible.toggle()
        }
    }
    
    func toggleWindowMode(_ window: SubtitleWindow) {
        if let index = subtitleWindows.firstIndex(where: { $0.id == window.id }) {
            subtitleWindows[index].isAdditive.toggle()
        }
    }
    
    func toggleWindowTranslation(_ window: SubtitleWindow) {
        if let index = subtitleWindows.firstIndex(where: { $0.id == window.id }) {
            subtitleWindows[index].translationEnabled.toggle()
        }
    }
    
    func setWindowTargetLanguage(_ window: SubtitleWindow, language: String) {
        if let index = subtitleWindows.firstIndex(where: { $0.id == window.id }) {
            subtitleWindows[index].targetLanguage = language
        }
    }
    
    func setWindowAudioChannel(_ window: SubtitleWindow, channel: AudioChannel) {
        if let index = subtitleWindows.firstIndex(where: { $0.id == window.id }) {
            subtitleWindows[index].audioChannel = channel
        }
    }
    
    func setWindowFontSize(_ window: SubtitleWindow, fontSize: CGFloat) {
        if let index = subtitleWindows.firstIndex(where: { $0.id == window.id }) {
            subtitleWindows[index].fontSize = fontSize
        }
    }
    
    func setAudioMode(_ mode: AudioMode) {
        audioMode = mode
        
        // Save to preferences for persistence across app sessions
        PreferencesManager.shared.audioMode = mode
        PreferencesManager.shared.saveSettings()
        
        // Enhanced debug logging for audio mode investigation
        debugPrint("🔍 AUDIO DEBUG: AppState.setAudioMode() called with: \(mode.rawValue)", source: "AppState")
        debugPrint("  - PreferencesManager.audioMode now: \(PreferencesManager.shared.audioMode.rawValue)", source: "AppState")
        
        // CRITICAL: Inform audio engine of mode change
        Task {
            await _audioEngine.setAudioMode(mode)
            debugPrint("✅ AUDIO DEBUG: Audio engine notified of mode change to: \(mode.rawValue)", source: "AppState")
        }
        
        // Clear channel-specific data when switching to mono
        if mode == .mono {
            leftChannelTranscription = ""
            rightChannelTranscription = ""
            leftChannelTranslation = ""
            rightChannelTranslation = ""
            leftChannelHistorical = ""
            rightChannelHistorical = ""
        }
        
    }
    
    
    func setLeftChannelLanguage(_ language: String) {
        leftChannelLanguage = language
        Task {
            await _audioEngine.setLeftChannelLanguage(language)
        }
    }
    
    func setRightChannelLanguage(_ language: String) {
        rightChannelLanguage = language
        Task {
            await _audioEngine.setRightChannelLanguage(language)
        }
    }
    
    func setSpeakerNames(left: String, right: String) {
        Task {
            await _audioEngine.setSpeakerNames(left: left, right: right)
        }
    }
    
    func setMonoInputLanguage(_ language: String) {
        monoInputLanguage = language
        print("🎤 Mono input language set to: \(language)")
        
        // Update audio engine with new language
        Task {
            await _audioEngine.setMonoLanguage(language)
        }
    }
    
    func setAPIKey(_ key: String) {
        enhancedTranslationService.setAPIKey(key)
    }
    
    func setAssemblyAPIKey(_ key: String) {
        PreferencesManager.shared.assemblyAIApiKey = key
        PreferencesManager.shared.saveSettings()
        print("🔑 AssemblyAI API key updated - will take effect on next recording session")
    }
    
    func startRecording() async {
        // Clear any previous errors
        recordingError = nil
        isRecovering = false
        
        // Validate audio input before starting
        guard let selectedDevice = audioDeviceManager.selectedInputDevice else {
            recordingError = "No audio input device selected"
            print("❌ Cannot start recording: No input device")
            return
        }
        
        print("🎤 Starting recording with device: \(selectedDevice.name)")
        
        isRecording = true
        
        // Set high priority for real-time performance
        setPriority()
        
        // Configure input device BEFORE starting recording
        await _audioEngine.setInputDevice(selectedDevice)
        
        // Configure output device for passthrough 
        if let outputDevice = audioDeviceManager.selectedOutputDevice {
            await _audioEngine.setOutputDevice(outputDevice)
        }
        
        // Configure audio engine mode
        debugPrint("🔍 AUDIO DEBUG: startRecording() - about to set audioMode: \(audioMode.rawValue)", source: "AppState")
        debugPrint("  - PreferencesManager.audioMode: \(PreferencesManager.shared.audioMode.rawValue)", source: "AppState")
        await _audioEngine.setAudioMode(audioMode)
        
        // Configure transcription engine
        await _audioEngine.setTranscriptionEngine(transcriptionEngine)
        
        // Apply noise suppression setting
        await _audioEngine.setNoiseSuppression(noiseSuppression)
        
        // Configure passthrough setting
        await _audioEngine.setPassthroughEnabled(audioDeviceManager.passthroughEnabled)
        
        // Set up channel-specific callbacks
        await _audioEngine.setTranscriptionCallbacks(
            mixed: { [weak self] transcription in
                Task { @MainActor in
                    self?.handleNewTranscription(transcription, channel: .mixed)
                }
            },
            left: { [weak self] transcription in
                Task { @MainActor in
                    self?.handleNewTranscription(transcription, channel: .left)
                }
            },
            right: { [weak self] transcription in
                Task { @MainActor in
                    self?.handleNewTranscription(transcription, channel: .right)
                }
            }
        )
        
        // Set up specialized AssemblyAI callbacks to prevent UI conflicts
        await _audioEngine.setAssemblyAICallback { [weak self] text in
            Task { @MainActor in
                self?.handleAssemblyAIFinalTranscription(text)
            }
        }
        
        // CRITICAL: Wire up partial callback for live word-by-word display
        await _audioEngine.setAssemblyAIPartialCallback { [weak self] text in
            Task { @MainActor in
                self?.handleAssemblyAIPartialTranscription(text)
            }
        }
        
        // Set up recording callback for file recording
        await _audioEngine.setRecordingCallback { [weak self] buffer in
            Task { @MainActor in
                self?.audioRecorder.writeAudioBuffer(buffer)
            }
        }
        
        // Configure AssemblyAI service if needed
        if transcriptionEngine == .assembly {
            let apiKey = PreferencesManager.shared.assemblyAIApiKey
            if !apiKey.isEmpty {
                await _audioEngine.configureAssemblyAI(apiKey: apiKey)
            } else {
                recordingError = "AssemblyAI API key not configured"
                isRecording = false
                return
            }
        }
        
        // Start recording - now uses simple non-throwing approach
        await _audioEngine.startRecording { [weak self] transcription in
            Task { @MainActor in
                self?.handleNewTranscription(transcription, channel: .mixed)
            }
        }
        
        print("✅ Recording started successfully")
    }
    
    func stopRecording() async {
        print("🔇 Stopping recording...")
        
        isRecording = false
        
        // AssemblyAI cleanup is handled by SimpleAudioEngine
        
        await _audioEngine.stopRecording()
        recordingError = nil
        print("✅ Recording stopped successfully")
    }
    
    // MARK: - Audio Device Management
    
    private func handleAudioDeviceDisconnection() async {
        guard isRecording else { return }
        
        print("🚨 Audio device disconnected during recording - attempting recovery")
        
        isRecovering = true
        
        // Stop current recording safely
        await stopRecording()
        
        // Wait for device settling
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Attempt to restart with new device
        await startRecording()
        
        isRecovering = false
        
        if isRecording {
            print("✅ Recording recovered successfully")
        } else {
            recordingError = "Failed to recover from device disconnection"
            print("❌ Recording recovery failed")
        }
    }
    
    private func handleAudioDeviceChange(device: AudioDevice?) async {
        guard isRecording && !isHandlingDeviceChange else { return }
        
        print("🔄 Audio device changed during recording - performing safe restart")
        
        // CRITICAL FIX: Prevent multiple simultaneous device change handlers
        isHandlingDeviceChange = true
        defer { isHandlingDeviceChange = false }
        
        // Complete shutdown with delay before restart
        await stopRecording()
        
        // Wait for audio system to settle after device change
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms delay
        
        print("🔄 Restarting recording after device change")
        await startRecording()
    }
    
    private func handlePassthroughChange(enabled: Bool) async {
        print("🔄 Passthrough changed to: \(enabled ? "ON" : "OFF")")
        
        // Update engine passthrough setting
        await _audioEngine.setPassthroughEnabled(enabled)
    }
    
    func setNoiseSuppression(_ level: Double) {
        noiseSuppression = max(0.0, min(1.0, level))
        
        // Apply to audio engine if recording
        if isRecording {
            Task {
                await _audioEngine.setNoiseSuppression(noiseSuppression)
            }
        }
        
        print("🔇 Noise suppression set to: \(Int(noiseSuppression * 100))%")
    }
    
    
    private func handleNewTranscription(_ transcription: String, channel: AudioChannel) {
        // CRITICAL MEMORY MANAGEMENT: Smart truncation to prevent unbounded growth
        let processedTranscription = processTranscriptionForMemory(transcription, channel: channel)
        
        switch channel {
        case .mixed:
            handleMixedChannelTranscription(processedTranscription)
        case .left:
            handleLeftChannelTranscription(processedTranscription)
        case .right:
            handleRightChannelTranscription(processedTranscription)
        }
        
        // Trigger translation for windows assigned to this channel
        if subtitleWindows.contains(where: { $0.translationEnabled && $0.audioChannel == channel }) {
            translateCurrentText(for: channel)
        }
        
        // Periodic memory cleanup
        performMemoryCleanupIfNeeded()
    }
    
    // CRITICAL MEMORY MANAGEMENT: Process transcription to prevent memory bloat
    private func processTranscriptionForMemory(_ transcription: String, channel: AudioChannel) -> String {
        // Limit individual transcription size
        let maxTranscriptionLength = 2000
        if transcription.count > maxTranscriptionLength {
            let truncatedIndex = transcription.index(transcription.startIndex, offsetBy: maxTranscriptionLength)
            return String(transcription[..<truncatedIndex]) + "..."
        }
        return transcription
    }
    
    private func handleMixedChannelTranscription(_ transcription: String) {
        // Direct handling - no concatenation at AppState level
        // SimpleAudioEngine handles all text flow logic
        currentTranscription = transcription
        
        // Update historical for additive mode windows
        historicalTranscription = historicalTranscription + transcription
        
        // Smart truncation for resource management
        if historicalTranscription.count > maxContextLength {
            let truncateAmount = historicalTranscription.count - retainLength
            let truncateIndex = historicalTranscription.index(historicalTranscription.startIndex, offsetBy: truncateAmount)
            historicalTranscription = String(historicalTranscription[truncateIndex...])
        }
    }
    
    
    private func handleLeftChannelTranscription(_ transcription: String) {
        // Direct handling - no concatenation at AppState level
        leftChannelTranscription = transcription
        
        // Update historical for additive mode windows
        leftChannelHistorical = leftChannelHistorical + transcription
        
        // Smart truncation for resource management
        if leftChannelHistorical.count > maxContextLength {
            let truncateAmount = leftChannelHistorical.count - retainLength
            let truncateIndex = leftChannelHistorical.index(leftChannelHistorical.startIndex, offsetBy: truncateAmount)
            leftChannelHistorical = String(leftChannelHistorical[truncateIndex...])
        }
    }
    
    private func handleRightChannelTranscription(_ transcription: String) {
        // Direct handling - no concatenation at AppState level
        rightChannelTranscription = transcription
        
        // Update historical for additive mode windows
        rightChannelHistorical = rightChannelHistorical + transcription
        
        // Smart truncation for resource management
        if rightChannelHistorical.count > maxContextLength {
            let truncateAmount = rightChannelHistorical.count - retainLength
            let truncateIndex = rightChannelHistorical.index(rightChannelHistorical.startIndex, offsetBy: truncateAmount)
            rightChannelHistorical = String(rightChannelHistorical[truncateIndex...])
        }
    }
    
    
    private func translateCurrentText(for channel: AudioChannel) {
        // Get transcription text for the specific channel
        let transcriptionText: String
        switch channel {
        case .mixed:
            transcriptionText = transcriptionEngine == .assembly ? assemblyAIFinalText : currentTranscription
        case .left:
            transcriptionText = leftChannelTranscription
        case .right:
            transcriptionText = rightChannelTranscription
        }
        
        guard !transcriptionText.isEmpty else { return }
        
        // CRITICAL FIX: Get all target languages for windows assigned to this channel
        let channelWindows = subtitleWindows.filter { $0.translationEnabled && $0.audioChannel == channel }
        guard !channelWindows.isEmpty else { return }
        
        // Get unique target languages to avoid duplicate API calls
        let uniqueLanguages = Set(channelWindows.map { $0.targetLanguage })
        
        print("🌍 Translating to languages: \(uniqueLanguages) for channel: \(channel.displayName)")
        
        // Translate to each unique language with throttling
        for targetLanguage in uniqueLanguages {
            
            // CRITICAL FIX: Check if translation is already in progress for this language
            let taskKey = "\(channel.displayName)-\(targetLanguage)"
            
            // Skip if already translating this language
            if activeTranslationTasks.contains(taskKey) {
                print("⏭️ Skipping \(targetLanguage) - translation already in progress")
                continue
            }
            
            // Check cooldown period
            if let lastTime = lastTranslationTime[taskKey],
               Date().timeIntervalSince(lastTime) < translationCooldown {
                print("⏰ Skipping \(targetLanguage) - cooldown period active")
                continue
            }
            
            // Mark as active and start translation
            activeTranslationTasks.insert(taskKey)
            lastTranslationTime[taskKey] = Date()
            
            Task {
                defer {
                    // Always clean up the task tracking
                    Task { @MainActor in
                        self.activeTranslationTasks.remove(taskKey)
                    }
                }
                
                do {
                    // Determine source language based on audio mode and channel
                    let sourceLanguage: String
                    switch channel {
                    case .mixed:
                        sourceLanguage = monoInputLanguage
                    case .left:
                        sourceLanguage = leftChannelLanguage
                    case .right:
                        sourceLanguage = rightChannelLanguage
                    }
                    
                    print("🌍 Starting translation to \(targetLanguage) for \(channel.displayName) from \(sourceLanguage)")
                    
                    let translation = try await enhancedTranslationService.translate(
                        text: transcriptionText,
                        from: sourceLanguage,
                        to: targetLanguage
                    )
                    
                    print("✅ Translation to \(targetLanguage): \(translation.prefix(50))...")
                    
                    await MainActor.run {
                        updateChannelTranslation(translation, for: channel, targetLanguage: targetLanguage)
                    }
                } catch {
                    print("❌ Translation failed for \(channel.displayName) channel to \(targetLanguage): \(error)")
                    
                    // Add exponential backoff for failed translations
                    await MainActor.run {
                        self.lastTranslationTime[taskKey] = Date().addingTimeInterval(5.0) // 5 second penalty
                    }
                }
            }
        }
    }
    
    private func updateChannelTranslation(_ translation: String, for channel: AudioChannel, targetLanguage: String) {
        // Store translation by language for window-specific display
        translationsByLanguage[targetLanguage] = translation
        
        // Update historical translations by language
        let existingHistorical = historicalTranslationsByLanguage[targetLanguage] ?? ""
        let totalTranslation = existingHistorical + translation
        
        if totalTranslation.count > maxContextLength {
            let truncateAmount = totalTranslation.count - retainLength
            let truncateIndex = totalTranslation.index(totalTranslation.startIndex, offsetBy: truncateAmount)
            historicalTranslationsByLanguage[targetLanguage] = String(totalTranslation[truncateIndex...])
        } else {
            historicalTranslationsByLanguage[targetLanguage] = totalTranslation
        }
        
        // Legacy support: Update the first translation for backward compatibility
        if currentTranslation.isEmpty {
            currentTranslation = translation
            historicalTranslation = historicalTranslationsByLanguage[targetLanguage] ?? ""
        }
        
        print("💾 Updated translation for \(targetLanguage): \(translation.prefix(30))...")
    }
    
    // MARK: - AssemblyAI Transcription Handling
    
    // MARK: - ISOLATED AssemblyAI Pipeline Handlers
    
    /**
     * @brief Handle partial AssemblyAI transcriptions for live word-by-word display
     */
    func handleAssemblyAIPartialTranscription(_ text: String) {
        debugPrint("📝 AppState: AssemblyAI partial transcription: '\(text)'", source: "AppState")
        
        // Update live text for real-time display (word-by-word)
        assemblyAILiveText = text
        
        // Send notification for floating windows
        NotificationCenter.default.post(
            name: NSNotification.Name("AssemblyAIPartialTranscript"),
            object: nil,
            userInfo: ["text": text]
        )
    }
    
    /**
     * @brief Handle final AssemblyAI transcriptions - ISOLATED from traditional pipeline
     */
    func handleAssemblyAIFinalTranscription(_ text: String) {
        debugPrint("✅ AppState: AssemblyAI final transcription: '\(text)'", source: "AppState")
        
        // Cancel any pending partial translation (final takes precedence)
        partialTranslationTask?.cancel()
        
        // Update final text for display
        assemblyAIFinalText = text
        
        // Add to historical for additive mode windows (with space separator)
        if !assemblyAIHistorical.isEmpty && !assemblyAIHistorical.hasSuffix(" ") {
            assemblyAIHistorical += " "
        }
        assemblyAIHistorical += text
        
        // Smart truncation for memory management
        if assemblyAIHistorical.count > maxContextLength {
            let truncateAmount = assemblyAIHistorical.count - retainLength
            let truncateIndex = assemblyAIHistorical.index(assemblyAIHistorical.startIndex, offsetBy: truncateAmount)
            assemblyAIHistorical = String(assemblyAIHistorical[truncateIndex...])
        }
        
        // No NotificationCenter notifications needed - callbacks handle everything
        
        // CRITICAL FIX: Pipe AssemblyAI into existing translation pipeline
        if subtitleWindows.contains(where: { $0.translationEnabled }) {
            translateCurrentText(for: .mixed)
        }
        
        debugPrint("📊 AppState: AssemblyAI historical length: \(assemblyAIHistorical.count) chars", source: "AppState")
    }
    
    // MARK: - Memory Management & Monitoring
    
    private func startMemoryMonitoring() {
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryStats()
            }
        }
    }
    
    private func updateMemoryStats() {
        let usage = getMemoryUsage()
        let pressure = getMemoryPressure()
        
        DispatchQueue.main.async {
            self.memoryUsageMB = usage
            self.memoryPressure = pressure
            
            // Log memory issues
            if pressure != "Normal" {
                print("⚠️ Memory pressure: \(pressure), Usage: \(String(format: "%.1f", usage))MB")
            }
            
            // Auto-cleanup if memory pressure is high
            if pressure == "Critical" {
                self.performMemoryCleanup()
            }
        }
    }
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0
        }
        return 0.0
    }
    
    private func getMemoryPressure() -> String {
        // Check available memory vs used memory
        let processInfo = ProcessInfo.processInfo
        let physicalMemory = Double(processInfo.physicalMemory) / 1024.0 / 1024.0
        let usedMemory = getMemoryUsage()
        
        let memoryPressurePercent = (usedMemory / physicalMemory) * 100
        
        if memoryPressurePercent > 80 {
            return "Critical"
        } else if memoryPressurePercent > 60 {
            return "High"  
        } else if memoryPressurePercent > 40 {
            return "Medium"
        } else {
            return "Normal"
        }
    }
    
    private func performMemoryCleanup() {
        print("🧹 Performing emergency memory cleanup...")
        
        // Aggressive cleanup of translation history
        for language in translationsByLanguage.keys {
            if let historical = historicalTranslationsByLanguage[language], historical.count > retainLength {
                let truncateAmount = historical.count - (retainLength / 2) // Keep even less during pressure
                let truncateIndex = historical.index(historical.startIndex, offsetBy: truncateAmount)
                historicalTranslationsByLanguage[language] = String(historical[truncateIndex...])
            }
        }
        
        // Cleanup legacy translations
        if historicalTranscription.count > retainLength {
            let truncateAmount = historicalTranscription.count - (retainLength / 2)
            let truncateIndex = historicalTranscription.index(historicalTranscription.startIndex, offsetBy: truncateAmount)
            historicalTranscription = String(historicalTranscription[truncateIndex...])
        }
        
        if historicalTranslation.count > retainLength {
            let truncateAmount = historicalTranslation.count - (retainLength / 2)
            let truncateIndex = historicalTranslation.index(historicalTranslation.startIndex, offsetBy: truncateAmount)
            historicalTranslation = String(historicalTranslation[truncateIndex...])
        }
        
        // Cleanup channel-specific historical data
        if leftChannelHistorical.count > retainLength {
            let truncateAmount = leftChannelHistorical.count - (retainLength / 2)
            let truncateIndex = leftChannelHistorical.index(leftChannelHistorical.startIndex, offsetBy: truncateAmount)
            leftChannelHistorical = String(leftChannelHistorical[truncateIndex...])
        }
        
        if rightChannelHistorical.count > retainLength {
            let truncateAmount = rightChannelHistorical.count - (retainLength / 2)
            let truncateIndex = rightChannelHistorical.index(rightChannelHistorical.startIndex, offsetBy: truncateAmount)
            rightChannelHistorical = String(rightChannelHistorical[truncateIndex...])
        }
        
        // Cleanup AssemblyAI historical data
        if assemblyAIHistorical.count > retainLength {
            let truncateAmount = assemblyAIHistorical.count - (retainLength / 2)
            let truncateIndex = assemblyAIHistorical.index(assemblyAIHistorical.startIndex, offsetBy: truncateAmount)
            assemblyAIHistorical = String(assemblyAIHistorical[truncateIndex...])
        }
        
        print("🧹 Memory cleanup completed")
    }
    
    // Priority management for real-time performance
    func setPriority() {
        // Set high priority for real-time audio processing
        let success = setpriority(PRIO_PROCESS, 0, -10) // Higher priority (lower nice value)
        if success == 0 {
            print("🚀 Set high priority for real-time performance")
        } else {
            print("⚠️ Failed to set high priority")
        }
    }
    
    // CRITICAL MEMORY MANAGEMENT: Comprehensive cleanup methods
    private var cleanupCounter = 0
    private func performMemoryCleanupIfNeeded() {
        // Only cleanup every 50 transcriptions to avoid performance impact
        cleanupCounter += 1
        
        if cleanupCounter >= 50 {
            cleanupCounter = 0
            performPeriodicMemoryCleanup()
        }
    }
    
    private func performPeriodicMemoryCleanup() {
        // Clean up window-specific transcription history
        for window in subtitleWindows {
            // Window-specific cleanup would require modifications to WindowTemplate
            _ = window.configuration
        }
        
        // Force garbage collection of translation caches
        activeTranslationTasks.removeAll(keepingCapacity: false)
        
        // Clean up old translation timestamps (keep only last 10)
        if lastTranslationTime.count > 10 {
            let sortedKeys = lastTranslationTime.keys.sorted { key1, key2 in
                (lastTranslationTime[key1] ?? Date.distantPast) > (lastTranslationTime[key2] ?? Date.distantPast)
            }
            
            let keysToKeep = Array(sortedKeys.prefix(10))
            let newTranslationTime = Dictionary(uniqueKeysWithValues: keysToKeep.map { ($0, lastTranslationTime[$0]!) })
            lastTranslationTime = newTranslationTime
        }
        
        print("🧹 Periodic memory cleanup completed")
    }
    
    // REMOVED: Duplicate function replaced by ResourceMonitor integration
    
    private func performEmergencyMemoryCleanup() {
        // Aggressive cleanup for high memory situations
        
        // Truncate all historical data to minimum
        let emergencyRetainLength = retainLength / 4 // Keep only 25%
        
        if historicalTranscription.count > emergencyRetainLength {
            let truncateAmount = historicalTranscription.count - emergencyRetainLength
            let truncateIndex = historicalTranscription.index(historicalTranscription.startIndex, offsetBy: truncateAmount)
            historicalTranscription = String(historicalTranscription[truncateIndex...])
        }
        
        if leftChannelHistorical.count > emergencyRetainLength {
            let truncateAmount = leftChannelHistorical.count - emergencyRetainLength
            let truncateIndex = leftChannelHistorical.index(leftChannelHistorical.startIndex, offsetBy: truncateAmount)
            leftChannelHistorical = String(leftChannelHistorical[truncateIndex...])
        }
        
        if rightChannelHistorical.count > emergencyRetainLength {
            let truncateAmount = rightChannelHistorical.count - emergencyRetainLength
            let truncateIndex = rightChannelHistorical.index(rightChannelHistorical.startIndex, offsetBy: truncateAmount)
            rightChannelHistorical = String(rightChannelHistorical[truncateIndex...])
        }
        
        // Clear translation caches
        translationsByLanguage.removeAll(keepingCapacity: false)
        historicalTranslationsByLanguage.removeAll(keepingCapacity: false)
        
        // Clear AssemblyAI data
        assemblyAILiveText = ""
        assemblyAIFinalText = ""
        assemblyAIHistorical = ""
        
        // Clear translation tasks
        activeTranslationTasks.removeAll(keepingCapacity: false)
        lastTranslationTime.removeAll(keepingCapacity: false)
        
        print("🚨 Emergency memory cleanup completed - freed significant memory")
    }
    
    // REMOVED: Duplicate function - now handled by ResourceMonitor
    
    // CRITICAL FIX 7: Resource monitoring integration
    private func startResourceMonitoring() {
        Task {
            await resourceMonitor.startMonitoring(
                memoryWarning: { [weak self] (memoryUsage: Double) in
                    Task { @MainActor in
                        print("⚠️ ResourceMonitor: Memory warning - \(String(format: "%.1f", memoryUsage))MB")
                        self?.performMemoryCleanup()
                    }
                },
                cpuWarning: { (cpuUsage: Double) in
                    Task { @MainActor in
                        print("⚠️ ResourceMonitor: CPU warning - \(String(format: "%.1f", cpuUsage))%")
                        // Optionally reduce processing intensity
                    }
                },
                emergencyCleanup: { [weak self] in
                    Task { @MainActor in
                        print("🚨 ResourceMonitor: Emergency cleanup triggered")
                        self?.performEmergencyMemoryCleanup()
                    }
                }
            )
        }
    }
    
    func setPassthroughVolume(_ volume: Double) async {
        await MainActor.run {
            passthroughVolume = max(0.0, min(1.0, volume)) // Clamp between 0.0 and 1.0
        }
        
        // Send volume to audio engine
        await audioEngine.setPassthroughVolume(passthroughVolume)
        
        let percentage = Int(passthroughVolume * 100)
        print("🔊 Passthrough volume set to: \(percentage)%")
    }
    
    // MARK: - Audio Recording to File
    
    func startAudioRecording() async {
        guard audioRecordingEnabled else {
            print("⚠️ Audio recording not enabled")
            return
        }

        guard !isRecordingToFile else {
            print("⚠️ Already recording to file")
            return
        }

        // Store original passthrough state and force it ON for recording
        await MainActor.run {
            originalPassthroughState = audioDeviceManager.passthroughEnabled
            if !audioDeviceManager.passthroughEnabled {
                print("🔄 Auto-enabling passthrough for recording")
            }
        }

        // Force passthrough ON (required for recording pipeline)
        audioDeviceManager.passthroughEnabled = true
        await _audioEngine.setPassthroughEnabled(true)

        // Start recording using SimpleAudioEngine's new method
        let result = await _audioEngine.startAudioRecording()

        await MainActor.run {
            if let fileURL = result {
                currentRecordingFile = fileURL
                isRecordingToFile = true
                print("✅ Started recording to: \(fileURL.path)")
                print("🎛️ Use passthrough volume slider to control monitoring (0% = silent recording)")
            } else {
                // Restore original passthrough state if recording failed
                if originalPassthroughState != audioDeviceManager.passthroughEnabled {
                    Task {
                        audioDeviceManager.passthroughEnabled = originalPassthroughState
                        await _audioEngine.setPassthroughEnabled(originalPassthroughState)
                    }
                }
                print("❌ Failed to start audio recording")
            }
        }
    }
    
    func stopAudioRecording() async {
        guard isRecordingToFile else {
            print("⚠️ Not currently recording")
            return
        }

        // Stop recording using SimpleAudioEngine's new method
        await _audioEngine.stopAudioRecording()

        // Restore original passthrough state
        let shouldRestorePassthrough = originalPassthroughState != audioDeviceManager.passthroughEnabled
        if shouldRestorePassthrough {
            print("🔄 Restoring original passthrough state: \(originalPassthroughState ? "ON" : "OFF")")
            audioDeviceManager.passthroughEnabled = originalPassthroughState
            await _audioEngine.setPassthroughEnabled(originalPassthroughState)
        }

        await MainActor.run {
            isRecordingToFile = false
            if let fileURL = currentRecordingFile {
                print("✅ Stopped recording. File saved: \(fileURL.path)")
            }
            // Keep currentRecordingFile reference for potential access
        }
    }
    
    func setAudioRecordingEnabled(_ enabled: Bool) async {
        await MainActor.run {
            audioRecordingEnabled = enabled
        }

        // Use SimpleAudioEngine's new recording methods
        await _audioEngine.setAudioRecordingEnabled(enabled)

        // If recording is disabled while actively recording, stop it
        if !enabled && isRecordingToFile {
            await stopAudioRecording()
        }
    }
    
    deinit {
        memoryTimer?.invalidate()
        memoryCleanupTimer?.invalidate()
        // Note: ResourceMonitor cleanup will happen automatically when actor is deallocated
        print("🗑️ AppState deinit - stopping audio and cleaning up memory monitoring")
    }
}