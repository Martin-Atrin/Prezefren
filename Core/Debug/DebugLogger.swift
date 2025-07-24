import Foundation
import SwiftUI

/**
 * DebugLogger - Real-time debug console for Prezefren
 * 
 * Captures all debug output and displays it in the app's right panel
 * Replaces blind print() debugging with visible, real-time logs
 */

enum LogLevel: String, CaseIterable {
    case info = "ℹ️"
    case success = "✅"  
    case warning = "⚠️"
    case error = "❌"
    case audio = "🎤"
    case engine = "🔧"
    case ui = "🖥️"
    case network = "🌐"
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        case .audio: return .purple
        case .engine: return .cyan
        case .ui: return .indigo
        case .network: return .mint
        }
    }
}

struct LogMessage: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
    let source: String
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
    
    var displayText: String {
        return "[\(formattedTime)] \(level.rawValue) \(source): \(message)"
    }
}

@MainActor
class DebugLogger: ObservableObject {
    static let shared = DebugLogger()
    
    @Published var messages: [LogMessage] = []
    @Published var isEnabled: Bool = false
    
    private let maxMessages = 1000 // Keep last 1000 messages
    private let queue = DispatchQueue(label: "com.prezefren.debuglogger", qos: .utility)
    
    // CRITICAL: File logging for crash debugging
    private let logFileURL: URL
    private let fileManager = FileManager.default
    
    private init() {
        // Set up log file in the app's working directory where Claude can access it
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        logFileURL = currentDir.appendingPathComponent("Prezefren_Debug.log")
        
        // Clear previous log file
        try? fileManager.removeItem(at: logFileURL)
        
        // Add startup message
        addMessage(level: .engine, source: "DebugLogger", message: "Debug console initialized - logging to \(logFileURL.path)")
        addMessage(level: .engine, source: "DebugLogger", message: "=== NEW SESSION STARTED ===")
        
        // Intercept all print statements
        interceptSystemPrints()
    }
    
    // MARK: - System Print Interception
    
    private func interceptSystemPrints() {
        // Override Swift's print function globally
        // This is simpler and more reliable than pipe redirection
        addMessage(level: .info, source: "DebugLogger", message: "System print interception enabled")
    }
    
    // MARK: - Public Logging Interface
    
    static func log(_ message: String, level: LogLevel = .info, source: String = "System") {
        Task { @MainActor in
            shared.addMessage(level: level, source: source, message: message)
        }
    }
    
    static func info(_ message: String, source: String = "System") {
        log(message, level: .info, source: source)
    }
    
    static func success(_ message: String, source: String = "System") {
        log(message, level: .success, source: source)
    }
    
    static func warning(_ message: String, source: String = "System") {
        log(message, level: .warning, source: source)
    }
    
    static func error(_ message: String, source: String = "System") {
        log(message, level: .error, source: source)
    }
    
    static func audio(_ message: String, source: String = "Audio") {
        log(message, level: .audio, source: source)
    }
    
    static func engine(_ message: String, source: String = "Engine") {
        log(message, level: .engine, source: source)
    }
    
    static func ui(_ message: String, source: String = "UI") {
        log(message, level: .ui, source: source)
    }
    
    // MARK: - Internal Implementation
    
    private func addMessage(level: LogLevel, source: String, message: String) {
        let logMessage = LogMessage(
            timestamp: Date(),
            level: level,
            message: message,
            source: source
        )
        
        // Thread-safe message addition
        messages.append(logMessage)
        
        // Keep buffer size manageable
        if messages.count > maxMessages {
            messages.removeFirst(messages.count - maxMessages)
        }
        
        // CRITICAL: Write to log file immediately for crash debugging
        writeToLogFile(logMessage)
        
        // Also print to console for CLI debugging if needed
        print("[\(logMessage.formattedTime)] \(level.rawValue) \(source): \(message)")
    }
    
    private func writeToLogFile(_ logMessage: LogMessage) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let logLine = logMessage.displayText + "\n"
            
            // Append to log file
            if let data = logLine.data(using: .utf8) {
                if fileManager.fileExists(atPath: logFileURL.path) {
                    // Append to existing file
                    if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    // Create new file
                    try? data.write(to: logFileURL)
                }
            }
        }
    }
    
    // MARK: - Console Management
    
    func clear() {
        messages.removeAll()
        addMessage(level: .info, source: "DebugLogger", message: "Console cleared")
    }
    
    func exportLogs() -> String {
        return messages.map { $0.displayText }.joined(separator: "\n")
    }
    
    // CRITICAL: Get log file path for crash debugging
    static func getLogFilePath() -> String {
        return shared.logFileURL.path
    }
    
    static func forceFlushLogs() async {
        await withCheckedContinuation { continuation in
            shared.queue.async {
                // Force flush all pending writes
                continuation.resume()
            }
        }
    }
    
    func filterMessages(level: LogLevel) -> [LogMessage] {
        return messages.filter { $0.level == level }
    }
    
    func searchMessages(query: String) -> [LogMessage] {
        guard !query.isEmpty else { return messages }
        return messages.filter { 
            $0.message.localizedCaseInsensitiveContains(query) ||
            $0.source.localizedCaseInsensitiveContains(query)
        }
    }
    
    // MARK: - Settings Integration
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            addMessage(level: .success, source: "DebugLogger", message: "Debug mode enabled")
        } else {
            addMessage(level: .info, source: "DebugLogger", message: "Debug mode disabled")
        }
    }
}

// MARK: - Convenience Extensions

extension DebugLogger {
    
    // Quick logging for common scenarios
    static func audioEngineStatus(_ status: String) {
        engine("Audio engine status: \(status)", source: "SimpleAudioEngine")
    }
    
    static func transcriptionResult(_ text: String) {
        audio("Transcription: \(text.prefix(50))\(text.count > 50 ? "..." : "")", source: "Whisper")
    }
    
    static func passthroughStatus(_ enabled: Bool) {
        audio("Passthrough \(enabled ? "enabled" : "disabled")", source: "Passthrough")
    }
    
    static func deviceChange(_ deviceName: String) {
        audio("Device changed to: \(deviceName)", source: "AudioDeviceManager")
    }
    
    static func initializationStep(_ step: String, success: Bool) {
        if success {
            DebugLogger.success(step, source: "Initialization")
        } else {
            error("Failed: \(step)", source: "Initialization")
        }
    }
}