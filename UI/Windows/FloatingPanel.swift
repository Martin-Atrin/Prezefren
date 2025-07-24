import SwiftUI
import AppKit

class FloatingPanelController: NSObject, NSWindowDelegate {
    var window: NSPanel?
    var hostingView: NSHostingView<AnyView>?
    let windowId: UUID
    weak var appState: AppState?
    
    init(windowId: UUID, appState: AppState? = nil) {
        self.windowId = windowId
        self.appState = appState
        super.init()
        Task { @MainActor in
            setupWindow()
        }
    }
    
    @MainActor
    private func setupWindow() {
        let contentView = FloatingSubtitleView(windowId: windowId)
        let viewWithEnvironment: AnyView
        if let appState = appState {
            viewWithEnvironment = AnyView(contentView.environmentObject(appState))
        } else {
            viewWithEnvironment = AnyView(contentView)
        }
        hostingView = NSHostingView(rootView: viewWithEnvironment)
        
        // Get window configuration from app state if available
        var windowFrame = NSRect(x: 100, y: 100, width: 400, height: 200)
        var windowTitle = "Subtitle Window"
        var windowOpacity: Double = 0.8
        
        if let appState = appState,
           let windowData = appState.subtitleWindows.first(where: { $0.id == windowId }) {
            windowFrame = NSRect(
                x: windowData.position.x,
                y: windowData.position.y,
                width: windowData.size.width,
                height: windowData.size.height
            )
            
            // Set window title based on translation language
            if windowData.translationEnabled && windowData.targetLanguage != "direct" {
                let languageName = getLanguageName(code: windowData.targetLanguage)
                windowTitle = "\(languageName) Subtitles"
            } else {
                windowTitle = windowData.name
            }
            
            windowOpacity = windowData.opacity
        }
        
        window = NSPanel(
            contentRect: windowFrame,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window?.contentView = hostingView
        window?.delegate = self
        window?.level = .floating
        window?.isFloatingPanel = true
        window?.hidesOnDeactivate = false
        window?.title = windowTitle
        window?.titlebarAppearsTransparent = true
        window?.backgroundColor = NSColor.black.withAlphaComponent(windowOpacity)
    }
    
    func show() {
        print("🪟 Panel show() called for window: \(windowId)")
        print("🪟 Window exists: \(window != nil)")
        
        // CRITICAL FIX: Wait for window creation if needed
        if window == nil {
            print("⏳ Window not ready, waiting...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.show()
            }
            return
        }
        
        // Force window to be visible and active
        window?.orderFrontRegardless()
        window?.makeKeyAndOrderFront(nil)
        window?.setIsVisible(true)
        
        print("🪟 Window ordered front: \(window?.isVisible ?? false)")
        print("🪟 Window level: \(window?.level.rawValue ?? -1)")
    }
    
    func hide() {
        window?.orderOut(nil)
    }
    
    func windowWillClose(_ notification: Notification) {
        // Update the app state to reflect window is hidden
        if let appState = appState {
            Task { @MainActor in
                if let windowIndex = appState.subtitleWindows.firstIndex(where: { $0.id == windowId }) {
                    appState.subtitleWindows[windowIndex].isVisible = false
                }
            }
        }
    }
    
    @MainActor
    private func getLanguageName(code: String) -> String {
        // Try to get language name from current translation service
        let currentService: TranslationServiceType
        switch PreferencesManager.shared.effectiveTranslationMode {
        case .geminiAPI:
            currentService = .geminiAPI
        case .appleNative:
            currentService = .appleNative
        }
        
        return LanguageService.getLanguageName(forCode: code, service: currentService)
    }
}

struct FloatingSubtitleView: View {
    let windowId: UUID
    @EnvironmentObject var appState: AppState
    
    private var windowData: SubtitleWindow? {
        appState.subtitleWindows.first { $0.id == windowId }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let window = windowData {
                    let (currentText, historicalText) = getTextForWindow(window)
                    
                    if window.isAdditive {
                        ContinuousTextView(
                            historicalText: historicalText,
                            currentText: currentText,
                            availableSize: geometry.size,
                            isTranslation: window.translationEnabled,
                            windowData: window
                        )
                    } else {
                        // Simple mode: Use AnimatedTextView for smooth real-time updates
                        // ProgressiveTextView is only for final/complete text, not streaming
                        AnimatedTextView(
                            text: currentText,
                            fontSize: window.fontSize,
                            animationEnabled: PreferencesManager.shared.enableAnimations
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    // Language badge in northeast corner
                    if window.translationEnabled && window.targetLanguage != "direct" {
                        VStack {
                            HStack {
                                Spacer()
                                languageBadge(for: window.targetLanguage)
                                    .padding(.top, 8)
                                    .padding(.trailing, 8)
                            }
                            Spacer()
                        }
                    }
                    
                } else {
                    Text("Window not found")
                        .foregroundColor(.white)
                }
            }
        }
        .background(Color.clear)
    }
    
    private func getTextForWindow(_ window: SubtitleWindow) -> (current: String, historical: String) {
        let (transcriptionCurrent, transcriptionHistorical): (String, String)
        
        // Get transcription based on transcription engine first, then audio channel
        if appState.transcriptionEngine == .assembly {
            // AssemblyAI integration: Use live text for current, final text for additive mode
            transcriptionCurrent = appState.assemblyAILiveText
            transcriptionHistorical = appState.assemblyAIHistorical
        } else {
            // Traditional transcription engines: Get based on audio channel
            switch window.audioChannel {
            case .mixed:
                transcriptionCurrent = appState.currentTranscription
                transcriptionHistorical = appState.historicalTranscription
            case .left:
                transcriptionCurrent = appState.leftChannelTranscription
                transcriptionHistorical = appState.leftChannelHistorical
            case .right:
                transcriptionCurrent = appState.rightChannelTranscription
                transcriptionHistorical = appState.rightChannelHistorical
            }
        }
        
        // CRITICAL FIX: Use language-specific translation if enabled
        if window.translationEnabled && window.targetLanguage != "direct" {
            let translationCurrent = appState.translationsByLanguage[window.targetLanguage] ?? ""
            let translationHistorical = appState.historicalTranslationsByLanguage[window.targetLanguage] ?? ""
            
            print("🪟 Window \(window.name) using \(window.targetLanguage) translation: \(translationCurrent.prefix(30))...")
            
            return (translationCurrent, translationHistorical)
        } else {
            return (transcriptionCurrent, transcriptionHistorical)
        }
    }
    
    @MainActor
    private func languageBadge(for languageCode: String) -> some View {
        // Get language name from current translation service
        let currentService: TranslationServiceType
        switch PreferencesManager.shared.effectiveTranslationMode {
        case .geminiAPI:
            currentService = .geminiAPI
        case .appleNative:
            currentService = .appleNative
        }
        
        let languageName = LanguageService.getLanguageName(forCode: languageCode, service: currentService)
        
        return Text(languageName.uppercased())
            .prezefrenBadge(color: Color.prezefrenPrimary, textColor: .white)
    }
    
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
}

struct ContinuousTextView: View {
    let historicalText: String
    let currentText: String
    let availableSize: CGSize
    let isTranslation: Bool
    let windowData: SubtitleWindow?
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        // CRITICAL FIX: Remove Spacer to prevent bottom overflow
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    // Historical text with opacity
                    if !historicalText.isEmpty {
                        Text(attributedHistoricalText)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Current text at full opacity with optional animation
                    if !currentText.isEmpty {
                        if PreferencesManager.shared.enableAnimations {
                            if shouldUseProgressiveText() {
                                // Whisper/Apple transcription or Translation: Use word-by-word simulation
                                ProgressiveTextView(
                                    fullText: currentText,
                                    config: getWordStreamingConfig(),
                                    fontSize: fontSize,
                                    fontWeight: .medium,
                                    textColor: .white,
                                    alignment: .leading
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("current")
                            } else {
                                // AssemblyAI transcription: Use smooth real-time updates (natural streaming)
                                AnimatedTextView(
                                    text: currentText,
                                    fontSize: fontSize,
                                    animationEnabled: true
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("current")
                            }
                        } else {
                            Text(currentText)
                                .foregroundColor(.white)
                                .fontWeight(.medium)
                                .font(.system(size: fontSize))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .scaleEffect(currentText.isEmpty ? 0.95 : 1.0)
                                .opacity(currentText.isEmpty ? 0.0 : 1.0)
                                .animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.1), value: currentText)
                                .id("current")
                        }
                    }
                    
                    // CRITICAL FIX: Add bottom padding to ensure text stays within bounds
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: currentText) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo("current", anchor: .bottom)
                }
            }
            // CRITICAL FIX: Constrain scroll view to window bounds
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var fontSize: CGFloat {
        return windowData?.fontSize ?? 18 // Use window-specific font size
    }
    
    private var attributedHistoricalText: AttributedString {
        var attributed = AttributedString(historicalText)
        attributed.foregroundColor = .white.opacity(0.6)
        attributed.font = .system(size: fontSize * 0.8)
        return attributed
    }
    
    private func shouldUseProgressiveText() -> Bool {
        // Always use progressive text for translations (simulate streaming from complete sentences)
        if isTranslation {
            return true
        }
        
        // For transcription: Use progressive text for chunky engines, animated text for streaming engines
        return appState.transcriptionEngine != .assembly
    }
    
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
}

struct SimpleTextView: View {
    let text: String
    let availableSize: CGSize
    let isTranslation: Bool
    let windowData: SubtitleWindow?
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack {
            Spacer()
            
            Text(text)
                .foregroundColor(.white)
                .fontWeight(.medium)
                .font(.system(size: fontSize))
                .multilineTextAlignment(.center)
                .padding()
            
            // CRITICAL FIX: Smaller bottom spacer to prevent overflow
            Spacer(minLength: 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped() // Ensure text stays within bounds
    }
    
    private var fontSize: CGFloat {
        return windowData?.fontSize ?? 18 // Use window-specific font size
    }
}

// Global panel manager
class FloatingPanelManager: ObservableObject {
    private var panels: [UUID: FloatingPanelController] = [:]
    
    func showPanel(for windowId: UUID, appState: AppState? = nil) {
        if panels[windowId] == nil {
            print("🔧 Creating new panel for window: \(windowId)")
            panels[windowId] = FloatingPanelController(windowId: windowId, appState: appState)
        }
        print("👁️ Showing panel for window: \(windowId)")
        panels[windowId]?.show()
    }
    
    func hidePanel(for windowId: UUID) {
        panels[windowId]?.hide()
    }
    
    func removePanel(for windowId: UUID) {
        panels[windowId]?.hide()
        panels[windowId] = nil
    }
    
    func closeAllPanels() {
        for (_, panel) in panels {
            panel.hide()
        }
        panels.removeAll()
    }
}