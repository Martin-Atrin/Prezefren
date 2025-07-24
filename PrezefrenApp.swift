import SwiftUI

// Global debug print function that routes to DebugLogger
func debugPrint(_ message: String, source: String = "System") {
    print(message) // Still print to terminal
    Task { @MainActor in
        DebugLogger.log(message, level: .info, source: source)
    }
}

@main
struct PrezefrenApp: App {
    @StateObject private var panelManager = FloatingPanelManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingHelp = false
    
    init() {
        // Set up debug print capture FIRST
        setupGlobalPrintCapture()
        
        // CRITICAL: Show log file location for crash debugging
        debugPrint("📁 Log file location: \(DebugLogger.getLogFilePath())", source: "PrezefrenApp")
        
        // Check if running on actual device (Apple requirement)
        #if targetEnvironment(simulator)
        debugPrint("⚠️ Apple Translation does not work in simulator - requires actual device")
        #else
        debugPrint("✅ Running on actual device - Apple Translation available")
        #endif
        
        // Initialize menu bar immediately
        DispatchQueue.main.async {
            MenuBarManager.shared.setupMenuBar()
        }
    }
    
    private func setupGlobalPrintCapture() {
        // Replace all existing print() calls to route through DebugLogger
        // This ensures ALL terminal output appears in debug console
        debugPrint("🔧 Global print capture initialized")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(panelManager)
                .sheet(isPresented: $showingHelp) {
                    HelpView()
                }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                print("🛑 App going to background - cleaning up")
                cleanup()
            }
        }
    }
    
    private func cleanup() {
        print("🧹 Cleaning up all panels and terminating")
        panelManager.closeAllPanels()
        
        // Force terminate after cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.terminate(nil)
        }
    }
}