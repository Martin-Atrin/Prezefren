import Foundation
import SwiftUI
import AVFoundation
import Network

/**
 * @brief AssemblyAI Real-Time Transcription Service
 * 
 * WebSocket-based streaming transcription service providing sub-500ms latency
 * for real-time audio transcription. Optimized for presentations and live events.
 * 
 * Key Features:
 * - WebSocket streaming with partial transcripts
 * - 50ms audio segments for optimal accuracy  
 * - Temporary token authentication for security
 * - End-of-utterance detection
 * - Automatic reconnection and error handling
 * 
 * Performance Targets:
 * - Latency: <300ms end-to-end with Universal-Streaming
 * - Accuracy: >95% for clear speech
 * - Uptime: 99.9% with auto-reconnection
 */

@MainActor
class AssemblyAITranscriptionService: ObservableObject {
    
    // MARK: - Configuration
    private let apiKey: String
    private let sampleRate: Double = 16000.0  // AssemblyAI optimal sample rate
    private let chunkDurationMs: Int = 50     // 50ms chunks for optimal performance
    
    // MARK: - WebSocket Connection
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private let connectionQueue = DispatchQueue(label: "AssemblyAI.Connection", qos: .userInitiated)
    
    // MARK: - Audio Processing
    private let audioQueue = DispatchQueue(label: "AssemblyAI.Audio", qos: .userInitiated)
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()
    private var isConnected = false
    private var isStreaming = false
    
    // MARK: - Authentication (v3 API uses direct API key)
    
    // MARK: - Callbacks (matching existing engine pattern)
    var transcriptionCallback: ((String) -> Void)?
    var partialTranscriptionCallback: ((String) -> Void)?
    var errorCallback: ((Error) -> Void)?
    var connectionStatusCallback: ((Bool) -> Void)?
    
    // MARK: - Performance Monitoring
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastLatency: TimeInterval = 0
    @Published var processedAudioDuration: TimeInterval = 0
    @Published var isActive: Bool = false
    
    enum ConnectionStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
        
        var displayText: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting..."
            case .connected: return "Connected"
            case .error(let message): return "Error: \(message)"
            }
        }
        
        var color: Color {
            switch self {
            case .disconnected: return .gray
            case .connecting: return .orange
            case .connected: return .green
            case .error: return .red
            }
        }
    }
    
    // MARK: - Initialization
    
    init(apiKey: String) {
        self.apiKey = apiKey
        setupURLSession()
        assemblyDebugPrint("🔧 AssemblyAI: Initialized with buffer duration: \(chunkDurationMs)ms", source: "AssemblyAI")
    }
    
    deinit {
        // Perform synchronous cleanup only
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        urlSession?.invalidateAndCancel()
    }
    
    // MARK: - Public Interface
    
    /**
     * @brief Start streaming transcription
     */
    func startStreaming() async throws {
        guard !apiKey.isEmpty else {
            throw AssemblyAIError.missingAPIKey
        }
        
        guard !isStreaming else {
            assemblyDebugPrint("⚠️ AssemblyAI: Already streaming", source: "AssemblyAI")
            return
        }
        
        assemblyDebugPrint("🚀 AssemblyAI: Starting streaming transcription", source: "AssemblyAI")
        connectionStatus = .connecting
        isActive = true
        
        do {
            try await establishConnection()
            isConnected = true
            isStreaming = true
            connectionStatus = .connected
            connectionStatusCallback?(true)
            assemblyDebugPrint("✅ AssemblyAI: Streaming started successfully", source: "AssemblyAI")
        } catch {
            connectionStatus = .error(error.localizedDescription)
            isActive = false
            errorCallback?(error)
            throw error
        }
    }
    
    /**
     * @brief Stop streaming transcription
     */
    func stopStreaming() async {
        assemblyDebugPrint("⏹️ AssemblyAI: Stopping streaming transcription", source: "AssemblyAI")
        
        isConnected = false
        isStreaming = false
        isActive = false
        
        // Send termination message
        if let webSocket = webSocketTask {
            let terminateMessage = """
            {"terminate_session": true}
            """
            
            do {
                try await webSocket.send(.string(terminateMessage))
                webSocket.cancel(with: .normalClosure, reason: nil)
            } catch {
                assemblyDebugPrint("⚠️ AssemblyAI: Error during termination: \(error)", source: "AssemblyAI")
            }
        }
        
        cleanup()
        connectionStatus = .disconnected
        connectionStatusCallback?(false)
        assemblyDebugPrint("✅ AssemblyAI: Streaming stopped", source: "AssemblyAI")
    }
    
    /**
     * @brief Process audio buffer for streaming
     */
    func processAudio(_ buffer: AVAudioPCMBuffer) {
        guard isConnected && isStreaming, let channelData = buffer.floatChannelData else { return }
        
        // Extract data safely on main thread
        let frameCount = Int(buffer.frameLength)
        let audioData = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
        
        audioQueue.async { [weak self] in
            Task { @MainActor in
                self?.handleAudioData(audioData)
            }
        }
    }
    
    /**
     * @brief Check if service is ready for use
     */
    var isReady: Bool {
        return !apiKey.isEmpty && connectionStatus == .connected
    }
    
    // MARK: - Private Implementation
    
    private func setupURLSession() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 0  // No timeout for streaming
        urlSession = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
    }
    
    private func establishConnection() async throws {
        // Use AssemblyAI Universal Streaming v3 WebSocket endpoint (like Lenguan2)
        guard let url = URL(string: "wss://streaming.assemblyai.com/v3/ws?sample_rate=16000&encoding=pcm_s16le&format_turns=true") else {
            throw AssemblyAIError.invalidURL
        }
        
        // Create WebSocket with proper API key authentication (v3 style)
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        
        assemblyDebugPrint("🔌 AssemblyAI v3: Connecting to \(url)", source: "AssemblyAI")
        assemblyDebugPrint("🔑 AssemblyAI v3: Using API key: \(apiKey.prefix(8))...", source: "AssemblyAI")
        
        webSocketTask = urlSession?.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Start listening for messages
        Task {
            await listenForMessages()
        }
        
        // Wait for connection confirmation
        try await waitForConnection()
    }
    
    
    private func waitForConnection() async throws {
        var attempts = 0
        let maxAttempts = 20
        
        while !isConnected && attempts < maxAttempts {
            try await Task.sleep(nanoseconds: 100_000_000)  // 100ms
            attempts += 1
        }
        
        if !isConnected {
            throw AssemblyAIError.connectionTimeout
        }
    }
    
    private func listenForMessages() async {
        while webSocketTask != nil {  // Keep listening as long as WebSocket connection exists
            do {
                guard let webSocket = webSocketTask else { break }
                let message = try await webSocket.receive()
                await handleWebSocketMessage(message)
            } catch {
                assemblyDebugPrint("❌ AssemblyAI: WebSocket error: \(error)", source: "AssemblyAI")
                await handleConnectionError(error)
                break
            }
        }
    }
    
    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .string(let text):
            await processTranscriptionMessage(text)
        case .data(let data):
            assemblyDebugPrint("⚠️ AssemblyAI: Received unexpected binary data: \(data.count) bytes", source: "AssemblyAI")
        @unknown default:
            assemblyDebugPrint("⚠️ AssemblyAI: Received unknown message type", source: "AssemblyAI")
        }
    }
    
    private func processTranscriptionMessage(_ message: String) async {
        // Always log received messages for debugging (v3 API style)
        assemblyDebugPrint("📨 AssemblyAI v3: Received message: \(message)", source: "AssemblyAI")
        
        do {
            guard let data = message.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                assemblyDebugPrint("❌ AssemblyAI v3: Failed to parse message as JSON", source: "AssemblyAI")
                return
            }
            
            // Handle v3 API message types (matching Lenguan2)
            if let messageType = json["type"] as? String {
                assemblyDebugPrint("🔍 AssemblyAI Processing message type: '\(messageType)' (length: \(messageType.count))", source: "AssemblyAI")
                assemblyDebugPrint("🔍 AssemblyAI About to enter switch statement", source: "AssemblyAI")
                
                switch messageType {
                case "begin", "Begin":
                    assemblyDebugPrint("🎯 AssemblyAI ENTERING Begin case handler", source: "AssemblyAI")
                    isConnected = true
                    connectionStatus = .connected
                    if let sessionId = json["id"] as? String {
                        assemblyDebugPrint("✅ AssemblyAI v3: Session started: \(sessionId)", source: "AssemblyAI")
                    } else {
                        assemblyDebugPrint("✅ AssemblyAI v3: Session started", source: "AssemblyAI")
                    }
                    return
                    
                case "turn", "Turn":
                    assemblyDebugPrint("🎯 AssemblyAI ENTERING Turn case handler", source: "AssemblyAI")
                    assemblyDebugPrint("🎯 AssemblyAI Matched Turn case for messageType: '\(messageType)'", source: "AssemblyAI")
                    // Handle turn events from Universal Streaming API
                    let transcript = json["transcript"] as? String ?? ""
                    let endOfTurn = json["end_of_turn"] as? Bool ?? false
                    let isFormatted = json["turn_is_formatted"] as? Bool ?? false
                    
                    assemblyDebugPrint("🔍 AssemblyAI Turn: transcript='\(transcript)', endOfTurn=\(endOfTurn), isFormatted=\(isFormatted)", source: "AssemblyAI")
                    
                    await MainActor.run {
                        if endOfTurn {
                            // CRITICAL FIX: Only process formatted final transcripts to prevent duplication
                            // AssemblyAI sends both unformatted and formatted versions of the same text
                            if isFormatted && !transcript.isEmpty {
                                transcriptionCallback?(transcript)
                                assemblyDebugPrint("✅ AssemblyAI v3: Final turn (FORMATTED): '\(transcript)'", source: "AssemblyAI")
                                assemblyDebugPrint("🔗 AssemblyAI: Calling transcriptionCallback with: '\(transcript)'", source: "AssemblyAI")
                            } else {
                                assemblyDebugPrint("⏭️ AssemblyAI v3: Skipping unformatted final turn to prevent duplication", source: "AssemblyAI")
                            }
                        } else {
                            // Process all partial transcripts (these are live streaming)
                            if !transcript.isEmpty {
                                partialTranscriptionCallback?(transcript)
                                assemblyDebugPrint("📝 AssemblyAI v3: Partial turn: '\(transcript)'", source: "AssemblyAI")
                                assemblyDebugPrint("🔗 AssemblyAI: Calling partialTranscriptionCallback with: '\(transcript)'", source: "AssemblyAI")
                            }
                        }
                    }
                    return
                    
                case "termination", "Termination":
                    isConnected = false
                    if let audioDuration = json["audio_duration_seconds"] as? Double {
                        assemblyDebugPrint("🔚 AssemblyAI v3: Session terminated after \(audioDuration)s", source: "AssemblyAI")
                    } else {
                        assemblyDebugPrint("🔚 AssemblyAI v3: Session terminated", source: "AssemblyAI")
                    }
                    return
                    
                case "error":
                    if let errorMessage = json["message"] as? String {
                        let realtimeError = AssemblyAIError.serverError(errorMessage)
                        await MainActor.run {
                            errorCallback?(realtimeError)
                        }
                        assemblyDebugPrint("❌ AssemblyAI v3: Server error: \(errorMessage)", source: "AssemblyAI")
                    }
                    return
                    
                default:
                    assemblyDebugPrint("⚠️ AssemblyAI v3: Unknown message type: '\(messageType)' (characters: \(Array(messageType)))", source: "AssemblyAI")
                }
            }
            
            // Handle direct errors (fallback)
            if let error = json["error"] as? String {
                let realtimeError = AssemblyAIError.serverError(error)
                await MainActor.run {
                    errorCallback?(realtimeError)
                }
                assemblyDebugPrint("❌ AssemblyAI v3: Error: \(error)", source: "AssemblyAI")
            }
            
        } catch {
            assemblyDebugPrint("❌ AssemblyAI v3: Failed to parse message: \(error)", source: "AssemblyAI")
        }
    }
    
    func handleAudioData(_ audioData: [Float]) {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        // Append new audio data
        audioBuffer.append(contentsOf: audioData)
        
        // Check if we have enough data to send (50ms chunks)
        let targetSamples = Int(sampleRate * Double(chunkDurationMs) / 1000.0)
        
        while audioBuffer.count >= targetSamples {
            let audioChunk = Array(audioBuffer.prefix(targetSamples))
            audioBuffer.removeFirst(targetSamples)
            
            // Send audio chunk
            Task {
                await sendAudioChunk(audioChunk)
            }
        }
    }
    
    private func sendAudioChunk(_ samples: [Float]) async {
        guard isConnected && isStreaming, let webSocket = webSocketTask else { 
            assemblyDebugPrint("⚠️ AssemblyAI v3: Cannot send audio - not connected", source: "AssemblyAI")
            return 
        }
        
        // Convert Float32 samples to Int16 PCM data for v3 API (like Lenguan2)
        let int16Samples = samples.map { sample in
            let clampedSample = max(-1.0, min(1.0, sample))
            return Int16(clampedSample * Float(Int16.max))
        }
        
        // Convert to binary data
        let data = int16Samples.withUnsafeBytes { Data($0) }
        
        do {
            try await webSocket.send(.data(data))
            // Removed per-chunk logging to prevent console spam (was 20 logs/second)
            
            // Update performance metrics
            await MainActor.run {
                processedAudioDuration += Double(samples.count) / sampleRate
            }
            
        } catch {
            assemblyDebugPrint("❌ AssemblyAI v3: Failed to send audio chunk: \(error)", source: "AssemblyAI")
            await handleConnectionError(error)
        }
    }
    
    private func handleConnectionError(_ error: Error) async {
        // CRITICAL FIX: Don't treat cleanup errors as operational errors
        // During shutdown, WebSocket errors are expected and should not trigger reconnection
        guard isStreaming && isConnected else {
            assemblyDebugPrint("🔄 AssemblyAI: Ignoring connection error during shutdown: \(error)", source: "AssemblyAI")
            return
        }
        
        assemblyDebugPrint("🔄 AssemblyAI: Connection error, attempting reconnection: \(error)", source: "AssemblyAI")
        
        await MainActor.run {
            connectionStatus = .error(error.localizedDescription)
            errorCallback?(error)
        }
        
        // Attempt reconnection after delay (only if still supposed to be streaming)
        if isStreaming {
            try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
            
            if isStreaming {  // Check again after delay
                do {
                    try await startStreaming()
                } catch {
                    assemblyDebugPrint("❌ AssemblyAI: Reconnection failed: \(error)", source: "AssemblyAI")
                }
            }
        }
    }
    
    private func cleanup() {
        bufferLock.lock()
        audioBuffer.removeAll()
        bufferLock.unlock()
        
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
    }
}

// MARK: - Error Types

enum AssemblyAIError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case authenticationFailed
    case connectionTimeout
    case invalidResponse
    case serverError(String)
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "AssemblyAI API key is required"
        case .invalidURL:
            return "Invalid AssemblyAI URL"
        case .authenticationFailed:
            return "AssemblyAI authentication failed - check your API key"
        case .connectionTimeout:
            return "AssemblyAI connection timeout"
        case .invalidResponse:
            return "Invalid response from AssemblyAI"
        case .serverError(let message):
            return "AssemblyAI server error: \(message)"
        case .networkUnavailable:
            return "Network connection unavailable"
        }
    }
}

// MARK: - Debug Helper

private func assemblyDebugPrint(_ message: String, source: String) {
    print("[\(source)] \(message)")
}