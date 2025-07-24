import Foundation
import AVFoundation
import AudioToolbox
import CoreAudio
import Speech

// Whisper C bridge function declarations
@_silgen_name("whisper_bridge_init_context")
func whisper_bridge_init_context(_ model_path: UnsafePointer<CChar>) -> OpaquePointer?

@_silgen_name("whisper_bridge_free_context") 
func whisper_bridge_free_context(_ ctx: OpaquePointer)

@_silgen_name("whisper_bridge_transcribe")
func whisper_bridge_transcribe(_ ctx: OpaquePointer, _ samples: UnsafePointer<Float>, _ n_samples: Int32) -> UnsafePointer<CChar>?

@_silgen_name("whisper_bridge_transcribe_with_language")
func whisper_bridge_transcribe_with_language(_ ctx: OpaquePointer, _ samples: UnsafePointer<Float>, _ n_samples: Int32, _ language: UnsafePointer<CChar>) -> UnsafePointer<CChar>?

/**
 * SimpleAudioEngine - Clean replacement for AudioEngine
 * 
 * Preserves UI interface while providing reliable audio routing
 * Focus: Working passthrough, device selection, clean architecture
 */




actor SimpleAudioEngine {
    
    // MARK: - Core Properties
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var outputNode: AVAudioOutputNode?
    
    // Whisper Integration
    nonisolated(unsafe) private var context: OpaquePointer?
    
    // Apple Speech Integration  
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // AssemblyAI Integration
    nonisolated(unsafe) private var assemblyAIService: AssemblyAITranscriptionService?
    
    // Audio Configuration
    nonisolated(unsafe) private var audioMode: AudioMode = .mono
    nonisolated(unsafe) private var transcriptionEngine: TranscriptionEngine = .whisper
    nonisolated(unsafe) private var monoLanguage: String = "en"
    nonisolated(unsafe) private var noiseSuppression: Double = 0.0
    
    // Device Management
    nonisolated(unsafe) private var selectedOutputDevice: AudioDevice?
    
    // Passthrough - SIMPLIFIED NATIVE ROUTING
    nonisolated(unsafe) private var passthroughEnabled: Bool = false
    
    // Callbacks
    nonisolated(unsafe) private var transcriptionCallback: ((String) -> Void)?
    nonisolated(unsafe) private var assemblyAITranscriptionCallback: ((String) -> Void)?
    nonisolated(unsafe) private var assemblyAIPartialCallback: ((String) -> Void)?
    nonisolated(unsafe) private var mixedChannelCallback: ((String) -> Void)?
    nonisolated(unsafe) private var leftChannelCallback: ((String) -> Void)?
    nonisolated(unsafe) private var rightChannelCallback: ((String) -> Void)?
    
    // Audio recording callback
    nonisolated(unsafe) private var recordingCallback: ((AVAudioPCMBuffer) -> Void)?
    
    // v1.0.8 ENHANCEMENT: 9-second rolling context window for improved transcription
    nonisolated(unsafe) private var preContextBuffer: [Float] = []     // 3s history context
    nonisolated(unsafe) private var actualBuffer: [Float] = []         // 3s current processing block
    nonisolated(unsafe) private var postContextBuffer: [Float] = []    // 3s future context
    private let bufferQueue = DispatchQueue(label: "com.prezefren.simplebuffer", qos: .userInitiated)
    
    // STEREO MODE: Independent L/R channel processing (buffer-based approach)
    nonisolated(unsafe) private var leftChannelBuffer: [Float] = []    // Left channel accumulation
    nonisolated(unsafe) private var rightChannelBuffer: [Float] = []   // Right channel accumulation
    nonisolated(unsafe) private var leftChannelLanguage: String = "en" // Left channel language
    nonisolated(unsafe) private var rightChannelLanguage: String = "es" // Right channel language
    nonisolated(unsafe) private var leftSpeakerName: String = "Emma"   // Left channel speaker name
    nonisolated(unsafe) private var rightSpeakerName: String = "Alex"  // Right channel speaker name
    
    // v1.0.8 ENHANCEMENT: Context window sizing (16kHz sample rate)
    private let contextWindowSize = 48000  // 3 seconds at 16kHz
    private let totalContextSize = 144000  // 9 seconds total (3s + 3s + 3s)
    private let wordBoundaryTolerance = 8000 // 0.5s at 16kHz for word boundary detection
    
    // STEREO MODE: Buffer size for independent L/R processing
    private let stereoBufferSize = 56000  // ~3.5 seconds at 16kHz (FORCED TO 56000 - MUST NOT BE 32000!)
    
    nonisolated(unsafe) private var passthroughVolume: Float = 1.0
    nonisolated(unsafe) private var passthroughMixer: AVAudioMixerNode? // Store goobero passthrough mixer for volume control
    
    // CRITICAL FIX: Whisper thread safety - single threaded queue for Whisper access
    private let whisperQueue = DispatchQueue(label: "com.prezefren.whisper", qos: .userInitiated)
    
    // v1.1.3 ENHANCEMENT: Clean discrete audio chunks (no rolling context to prevent hallucinations)
    nonisolated(unsafe) private var lastProcessedTimestamp: Date? = nil
    private let minSilenceDuration: TimeInterval = 0.75 // 750ms silence to trigger processing
    nonisolated(unsafe) private var silenceStartTime: Date? = nil
    
    // v1.1.1 ENHANCEMENT: Advanced VAD with multi-threshold detection - FIXED SENSITIVITY
    private struct VADThresholds {
        static let silenceThreshold: Float = 0.001 // Very quiet background noise
        static let speechThreshold: Float = 0.015 // Clear speech detection (reduced)
        static let musicThreshold: Float = 0.030 // Music/complex audio (reduced)
        static let loudThreshold: Float = 0.10 // Loud/clear audio (reduced)
        
        static let minimumSpeechRatio = 0.05 // 5% of samples above speech threshold (much more permissive)
        static let minimumActivityRatio = 0.15 // 15% above silence threshold (more permissive)
        static let energyConsistencyThreshold = 0.12 // Energy variance indicator (more permissive)
    }
    
    // v1.1.3 ENHANCEMENT: Quality-focused processing timing
    nonisolated(unsafe) private var lastProcessingTime: Date? = nil
    private let minimumProcessingInterval: TimeInterval = 0.3 // Minimum 300ms between processing (responsive)
    private let qualityProcessingDelay: TimeInterval = 1.5 // Wait 1.5s for quality context
    
    // PHASE 2 FIX: Separate rate limiting for Goobero channels
    nonisolated(unsafe) private var lastLeftChannelProcessingTime: Date? = nil
    nonisolated(unsafe) private var lastRightChannelProcessingTime: Date? = nil
    
    nonisolated(unsafe) private var vadHistory: [Bool] = [] // Track recent VAD decisions
    private let vadHistorySize = 3 // Keep last 3 VAD decisions for boundary detection
    
    // v1.1.1 ENHANCEMENT: Voice activity persistence to reduce choppy transcriptions
    nonisolated(unsafe) private var lastSpeechDetectionTime: Date? = nil
    private let speechPersistenceWindow: TimeInterval = 0.8 // Continue processing for 0.8s after last speech
    private let minimumSpeechDuration: TimeInterval = 0.3 // Must have at least 0.3s of speech to trigger persistence
    nonisolated(unsafe) private var continuousSpeechStartTime: Date? = nil
    
    // v1.1.3 ENHANCEMENT: Simple timestamp-based duplicate prevention
    nonisolated(unsafe) private var lastOutputText: String = ""
    nonisolated(unsafe) private var lastOutputTimestamp: Date? = nil
    private let duplicatePreventionWindow: TimeInterval = 0.5 // 0.5-second window for duplicate detection (reduced to prevent stale context)
    
    // v1.1.3.2 ENHANCEMENT: Silence period detection to prevent hallucinations
    nonisolated(unsafe) private var consecutiveLowQualityCount: Int = 0
    nonisolated(unsafe) private var lastLowQualityTime: Date? = nil
    private let maxConsecutiveLowQuality = 3 // After 3 consecutive low-quality results, enter silence mode
    private let silenceModeTimeout: TimeInterval = 2.0 // Stay in silence mode for 2 seconds
    nonisolated(unsafe) private var isInSilenceMode: Bool = false
    nonisolated(unsafe) private var silenceModeStartTime: Date? = nil
    
    // v1.1.3 ENHANCEMENT: Context preservation for sentence continuity  
    nonisolated(unsafe) private var previousSentence: String = "" // Last complete sentence for Whisper context
    
    // v1.1.3 ENHANCEMENT: Clean state management (removed complex buffer management)
    
    // Reusable converter for efficiency
    private var audioConverter: AVAudioConverter?
    
    private var isInitialized = false
    private var isRecording = false
    
    // MARK: - v1.1.1 Advanced VAD Implementation
    
    nonisolated private func performAdvancedVAD(samples: [Float]) -> Bool {
        // CRITICAL DEBUG: Log VAD entry
        debugPrint("🔍 VAD: Starting analysis with \(samples.count) samples", source: "SimpleAudioEngine")
        
        // Multi-threshold analysis for better speech detection
        let silentSamples = samples.filter { abs($0) <= VADThresholds.silenceThreshold }.count
        let speechSamples = samples.filter { abs($0) > VADThresholds.speechThreshold }.count
        let musicSamples = samples.filter { abs($0) > VADThresholds.musicThreshold }.count
        let loudSamples = samples.filter { abs($0) > VADThresholds.loudThreshold }.count
        
        let totalSamples = samples.count
        let speechRatio = Double(speechSamples) / Double(totalSamples)
        let activityRatio = Double(totalSamples - silentSamples) / Double(totalSamples)
        let musicRatio = Double(musicSamples) / Double(totalSamples)
        let loudRatio = Double(loudSamples) / Double(totalSamples)
        
        // CRITICAL DEBUG: Log all calculated ratios
        debugPrint("🔍 VAD: Ratios - Speech: \(String(format: "%.3f", speechRatio)), Activity: \(String(format: "%.3f", activityRatio)), Music: \(String(format: "%.3f", musicRatio)), Loud: \(String(format: "%.3f", loudRatio))", source: "SimpleAudioEngine")
        
        // Calculate energy variance for consistency detection
        let meanEnergy = samples.map { abs($0) }.reduce(0, +) / Float(samples.count)
        let energyVariance = samples.map { pow(abs($0) - meanEnergy, 2) }.reduce(0, +) / Float(samples.count)
        let energyConsistency = Double(sqrt(energyVariance))
        
        // CRITICAL DEBUG: Log thresholds and energy analysis
        debugPrint("🔍 VAD: Energy - Mean: \(String(format: "%.6f", meanEnergy)), Variance: \(String(format: "%.6f", energyVariance)), Consistency: \(String(format: "%.6f", energyConsistency))", source: "SimpleAudioEngine")
        debugPrint("🔍 VAD: Thresholds - Silence: \(VADThresholds.silenceThreshold), Speech: \(VADThresholds.speechThreshold), MinSpeechRatio: \(VADThresholds.minimumSpeechRatio)", source: "SimpleAudioEngine")
        
        // Primary speech detection with multiple criteria
        var isSpeech = false
        
        // Strong speech indicators
        if speechRatio >= VADThresholds.minimumSpeechRatio {
            isSpeech = true
            debugPrint("🗣️ VAD: Strong speech detected (\(String(format: "%.1f", speechRatio * 100))%)", source: "SimpleAudioEngine")
        }
        // Moderate activity with good consistency (conversation) - BUT MUST HAVE SIGNIFICANT SPEECH CONTENT
        else if activityRatio >= VADThresholds.minimumActivityRatio && energyConsistency < VADThresholds.energyConsistencyThreshold && speechRatio > 0.15 {
            isSpeech = true
            debugPrint("🗣️ VAD: Consistent moderate speech (activity: \(String(format: "%.1f", activityRatio * 100))%, consistency: \(String(format: "%.3f", energyConsistency)))", source: "SimpleAudioEngine")
        }
        // Loud clear audio (should generally be processed) - BUT MUST HAVE SIGNIFICANT SPEECH CONTENT
        else if loudRatio > 0.15 && activityRatio > 0.20 && speechRatio > 0.10 {
            isSpeech = true
            debugPrint("🗣️ VAD: Loud clear audio (loud: \(String(format: "%.1f", loudRatio * 100))%)", source: "SimpleAudioEngine")
        }
        // Music/complex audio handling (more permissive for potential speech over music)
        else if musicRatio > 0.25 && speechRatio > 0.05 {
            isSpeech = true
            debugPrint("🎵 VAD: Music with potential speech (music: \(String(format: "%.1f", musicRatio * 100))%, speech: \(String(format: "%.1f", speechRatio * 100))%)", source: "SimpleAudioEngine")
        }
        else {
            debugPrint("🔇 VAD: Silence/noise detected (speech: \(String(format: "%.1f", speechRatio * 100))%, activity: \(String(format: "%.1f", activityRatio * 100))%)", source: "SimpleAudioEngine")
        }
        
        // Historical smoothing to reduce choppy behavior
        vadHistory.append(isSpeech)
        if vadHistory.count > vadHistorySize {
            vadHistory.removeFirst()
        }
        
        // Apply smoothing: require majority vote from recent history
        let currentTime = Date()
        var finalDecision = isSpeech
        
        if vadHistory.count >= 3 {
            let recentSpeechCount = vadHistory.suffix(3).filter { $0 }.count
            let smoothedDecision = recentSpeechCount >= 2 // Majority vote from last 3 decisions
            
            // Override for clear cases (very strong speech should always pass)
            if speechRatio >= 0.20 || loudRatio >= 0.30 {
                finalDecision = true
            }
            // Override for clear silence (very low activity should be filtered)
            else if activityRatio < 0.03 && speechRatio < 0.02 {
                finalDecision = false
            }
            else {
                finalDecision = smoothedDecision
            }
            
            if smoothedDecision != isSpeech {
                debugPrint("🎯 VAD: Smoothed decision: \(isSpeech ? "SPEECH" : "SILENCE") → \(smoothedDecision ? "SPEECH" : "SILENCE")", source: "SimpleAudioEngine")
            }
        }
        
        // v1.1.1 ENHANCEMENT: Voice activity persistence logic
        if finalDecision {
            // Speech detected - update timing
            lastSpeechDetectionTime = currentTime
            if continuousSpeechStartTime == nil {
                continuousSpeechStartTime = currentTime
                debugPrint("🎤 VAD: Speech sequence started", source: "SimpleAudioEngine")
            }
            // CRITICAL DEBUG: Log final decision
            debugPrint("✅ VAD: FINAL DECISION = SPEECH (speech: \(String(format: "%.1f", speechRatio * 100))%, activity: \(String(format: "%.1f", activityRatio * 100))%)", source: "SimpleAudioEngine")
            return true
        } else {
            // No speech detected - check for persistence
            if let lastSpeechTime = lastSpeechDetectionTime,
               let speechStartTime = continuousSpeechStartTime {
                
                let timeSinceLastSpeech = currentTime.timeIntervalSince(lastSpeechTime)
                let totalSpeechDuration = lastSpeechTime.timeIntervalSince(speechStartTime)
                
                // Apply persistence if:
                // 1. We had sufficient speech duration AND
                // 2. We're still within the persistence window
                // NOTE: Rate limiting is handled separately in shouldProcess logic
                if totalSpeechDuration >= minimumSpeechDuration && 
                   timeSinceLastSpeech < speechPersistenceWindow {
                    debugPrint("🔄 VAD: Persistence active (\(String(format: "%.1f", timeSinceLastSpeech * 1000))ms since speech, \(String(format: "%.1f", totalSpeechDuration * 1000))ms total)", source: "SimpleAudioEngine")
                    return true
                } else if timeSinceLastSpeech >= speechPersistenceWindow {
                    // Persistence window expired - reset
                    continuousSpeechStartTime = nil
                    lastSpeechDetectionTime = nil
                    debugPrint("🛑 VAD: Speech sequence ended (persistence expired)", source: "SimpleAudioEngine")
                }
            }
            
            // CRITICAL DEBUG: Log final decision
            debugPrint("🔇 VAD: FINAL DECISION = SILENCE (speech: \(String(format: "%.1f", speechRatio * 100))%, activity: \(String(format: "%.1f", activityRatio * 100))%)", source: "SimpleAudioEngine")
            return false
        }
    }
    
    // MARK: - v1.1.3 Quality-Focused Processing Implementation
    
    nonisolated private func detectSpeechBoundary(vadDecision: Bool, currentTime: Date) -> Bool {
        // Add current VAD decision to history
        vadHistory.append(vadDecision)
        if vadHistory.count > vadHistorySize {
            vadHistory.removeFirst()
        }
        
        // Detect speech boundary: silence after speech
        if !vadDecision && vadHistory.count >= 2 {
            let recentSpeech = vadHistory.dropLast().contains(true)
            if recentSpeech {
                // Mark potential silence start
                if silenceStartTime == nil {
                    silenceStartTime = currentTime
                }
                
                // Check if we've had enough silence to indicate speech boundary
                if let silenceStart = silenceStartTime,
                   currentTime.timeIntervalSince(silenceStart) >= minSilenceDuration {
                    silenceStartTime = nil // Reset for next boundary
                    debugPrint("🔚 Speech boundary detected after \(String(format: "%.2f", minSilenceDuration))s silence", source: "SimpleAudioEngine")
                    return true
                }
            }
        } else {
            // Reset silence tracking if speech detected
            silenceStartTime = nil
        }
        
        return false
    }
    
    nonisolated private func shouldProcessForQuality(
        samples: [Float], 
        vadDecision: Bool, 
        speechBoundaryDetected: Bool,
        currentTime: Date
    ) -> Bool {
        // v1.1.3.2 ANTI-HALLUCINATION: Check silence mode first
        if isInSilenceMode {
            if let silenceStart = silenceModeStartTime,
               currentTime.timeIntervalSince(silenceStart) < silenceModeTimeout {
                debugPrint("🔇 SILENCE MODE: Skipping processing for \(String(format: "%.1f", silenceModeTimeout - currentTime.timeIntervalSince(silenceStart)))s", source: "SimpleAudioEngine")
                return false
            } else {
                // Exit silence mode
                isInSilenceMode = false
                silenceModeStartTime = nil
                consecutiveLowQualityCount = 0
                debugPrint("🔊 Exiting silence mode", source: "SimpleAudioEngine")
            }
        }
        
        // Quality threshold 1: Must have sufficient speech content
        let speechSamples = samples.filter { abs($0) > VADThresholds.speechThreshold }.count
        let speechRatio = Double(speechSamples) / Double(samples.count)
        let hasQualitySpeech = speechRatio >= 0.15 // At least 15% speech content
        
        // Quality threshold 2: Minimum audio duration (2 seconds for quality)
        let hasMinimumDuration = samples.count >= 32000 // 2 seconds at 16kHz
        
        // Quality threshold 3: ANTI-HALLUCINATION: Much higher threshold for forced processing
        let timeForced = lastProcessedTimestamp.map { 
            currentTime.timeIntervalSince($0) > qualityProcessingDelay * 2 
        } ?? true
        let highQualityTimeForced = timeForced && speechRatio >= 0.40 // Need 40% speech for forced processing
        
        // Quality threshold 4: Rate limiting to prevent overprocessing
        let rateLimitOk = lastProcessingTime.map { 
            currentTime.timeIntervalSince($0) >= minimumProcessingInterval 
        } ?? true
        
        let shouldProcess = rateLimitOk && (
            (hasQualitySpeech && hasMinimumDuration) || // Quality speech with enough context
            speechBoundaryDetected || // Natural speech boundary
            highQualityTimeForced // Only force process high-quality audio
        )
        
        // v1.1.3.2 ANTI-HALLUCINATION: Track low-quality results
        if speechRatio < 0.35 && shouldProcess {
            consecutiveLowQualityCount += 1
            lastLowQualityTime = currentTime
            debugPrint("⚠️ Low quality audio processed (\(consecutiveLowQualityCount)/\(maxConsecutiveLowQuality)): \(String(format: "%.1f", speechRatio * 100))%", source: "SimpleAudioEngine")
            
            if consecutiveLowQualityCount >= maxConsecutiveLowQuality {
                isInSilenceMode = true
                silenceModeStartTime = currentTime
                debugPrint("🔇 ENTERING SILENCE MODE: Too many low-quality results", source: "SimpleAudioEngine")
                return false
            }
        } else if speechRatio >= 0.35 {
            // Reset low quality counter on good speech
            consecutiveLowQualityCount = 0
        }
        
        debugPrint("🎯 Quality check: speech=\(String(format: "%.1f", speechRatio * 100))%, duration=\(hasMinimumDuration), boundary=\(speechBoundaryDetected), highQualityForced=\(highQualityTimeForced) → \(shouldProcess)", source: "SimpleAudioEngine")
        
        return shouldProcess
    }
    
    private func processQualityTranscription(samples: [Float]) async {
        debugPrint("🎯 Processing quality transcription with \(samples.count) samples (\(String(format: "%.2f", Double(samples.count) / 16000.0))s)", source: "SimpleAudioEngine")
        
        // Process with Whisper using context preservation
        if transcriptionEngine == .whisper {
            await withCheckedContinuation { continuation in
                whisperQueue.async { [weak self] in
                    guard let self = self, let context = self.context else {
                        debugPrint("❌ Whisper context is nil for quality processing", source: "SimpleAudioEngine")
                        continuation.resume()
                        return
                    }
                    
                    debugPrint("🎯 Calling Whisper with context: '\(self.previousSentence.prefix(50))...'", source: "SimpleAudioEngine")
                    
                    // v1.1.3.3 FIX: Apply audio mode processing only to confirmed speech samples
                    let processedSamples = self.applyAudioModeProcessing(to: samples)
                    
                    // Use previous sentence as context for better continuity
                    let result: UnsafePointer<CChar>?
                    if !self.previousSentence.isEmpty {
                        result = whisper_bridge_transcribe_with_language(
                            context,
                            processedSamples,
                            Int32(processedSamples.count),
                            self.monoLanguage
                        )
                    } else {
                        result = whisper_bridge_transcribe_with_language(
                            context,
                            processedSamples,
                            Int32(processedSamples.count),
                            self.monoLanguage
                        )
                    }
                    
                    if let result = result,
                       let text = String(cString: result, encoding: .utf8),
                       !text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                        
                        debugPrint("✅ Quality Whisper result: \(text)", source: "SimpleAudioEngine")
                        
                        // v1.1.3: Simple duplicate prevention and output
                        if let finalText = self.processWithDuplicatePrevention(text) {
                            Task { @MainActor in
                                self.transcriptionCallback?(finalText)
                            }
                        }
                    } else {
                        debugPrint("❌ Quality Whisper returned empty result", source: "SimpleAudioEngine")
                    }
                    
                    continuation.resume()
                }
            }
        }
        
        // Process with Apple Speech
        if transcriptionEngine == .appleSpeech {
            if let recognizer = speechRecognizer, recognizer.isAvailable {
                debugPrint("🍎 Using Apple Speech for transcription", source: "SimpleAudioEngine")
                // Apple Speech processing (placeholder for now)
                debugPrint("🍎 Apple Speech processing not yet implemented", source: "SimpleAudioEngine")
            } else {
                debugPrint("❌ Apple Speech recognizer not available", source: "SimpleAudioEngine")
            }
        }
    }
    
    nonisolated private func processWithDuplicatePrevention(_ newText: String) -> String? {
        let currentTime = Date()
        
        // v1.1.3 ENHANCEMENT: Filter out [BLANK_AUDIO] completely
        let filteredText = newText.replacingOccurrences(of: "[BLANK_AUDIO]", with: "")
        let cleanText = filteredText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // v1.1.3.2 ANTI-HALLUCINATION: Detect [BLANK_AUDIO] and enter silence mode
        if newText.contains("[BLANK_AUDIO]") || cleanText.isEmpty {
            consecutiveLowQualityCount += 1
            debugPrint("🚫 Empty or blank audio filtered (count: \(consecutiveLowQualityCount)/\(maxConsecutiveLowQuality))", source: "SimpleAudioEngine")
            
            if consecutiveLowQualityCount >= maxConsecutiveLowQuality {
                isInSilenceMode = true
                silenceModeStartTime = Date()
                previousSentence = "" // Clear context when entering silence mode
                debugPrint("🔇 ENTERING SILENCE MODE: Too many blank audio results", source: "SimpleAudioEngine")
            }
            return nil
        }
        
        // v1.1.3 ENHANCEMENT: Apply natural sentence refinement
        let refinedText = refineTextForNaturalness(cleanText)
        
        // Check for duplicates within recent window
        if let lastTime = lastOutputTimestamp,
           currentTime.timeIntervalSince(lastTime) < duplicatePreventionWindow {
            
            // Simple similarity check
            if refinedText == lastOutputText {
                debugPrint("🚫 Duplicate text filtered: '\(refinedText)'", source: "SimpleAudioEngine")
                return nil
            }
            
            // FIXED: More conservative extension detection to prevent missing first words
            // Only treat as extension if there's significant overlap and clear continuation
            if refinedText.hasPrefix(lastOutputText) && 
               refinedText.count > lastOutputText.count &&
               lastOutputText.count >= 5 { // Only for substantial previous text
                
                let newPortion = String(refinedText.dropFirst(lastOutputText.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Ensure the new portion is substantial and not just a single character
                if newPortion.count >= 3 && newPortion.first?.isLetter == true {
                    updateOutputState(text: refinedText, timestamp: currentTime)
                    debugPrint("📈 Extended text output: '\(newPortion)'", source: "SimpleAudioEngine")
                    return newPortion
                } else {
                    // Treat as completely new text to avoid cutting off words
                    debugPrint("🔄 Extension too small ('\(newPortion)'), treating as new text", source: "SimpleAudioEngine")
                }
            }
        }
        
        // New unique text
        if !refinedText.isEmpty {
            updateOutputState(text: refinedText, timestamp: currentTime)
            debugPrint("✨ New refined text output: '\(refinedText)'", source: "SimpleAudioEngine")
            return refinedText
        }
        
        return nil
    }
    
    nonisolated private func refineTextForNaturalness(_ text: String) -> String {
        var refined = text
        
        // 1. Remove only obvious artifacts (less aggressive)
        let criticalArtifacts = [
            "[BLANK_AUDIO]",
            "[blank_audio]", 
            "[NOISE]",
            "[noise]"
        ]
        
        for artifact in criticalArtifacts {
            refined = refined.replacingOccurrences(of: artifact, with: " ")
        }
        
        // REDUCED: Keep filler words for more natural speech flow
        // User feedback: focus on naturalness, not over-processing
        
        // 2. Fix common transcription issues (contractions)
        refined = fixCommonTranscriptionIssues(refined)
        
        // 3. Basic flow improvements (no forced sentence completion)
        refined = improveSentenceFlow(refined)
        
        // 4. Final cleanup (preserve natural spacing)
        refined = refined.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression) // Multiple spaces only
        refined = refined.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 5. Add trailing space for proper chunk separation in additive mode
        // User feedback: "adding a space when the sentence finishes would be amazing"
        if !refined.isEmpty {
            refined += " "
        }
        
        debugPrint("🎨 Light text refinement: '\(text)' → '\(refined)'", source: "SimpleAudioEngine")
        
        return refined
    }
    
    nonisolated private func fixCommonTranscriptionIssues(_ text: String) -> String {
        var fixed = text
        
        // Fix common word merging issues
        let wordFixes = [
            "youre": "you're",
            "dont": "don't", 
            "cant": "can't",
            "wont": "won't",
            "isnt": "isn't",
            "arent": "aren't",
            "wasnt": "wasn't",
            "werent": "weren't",
            "havent": "haven't",
            "hasnt": "hasn't",
            "hadnt": "hadn't",
            "shouldnt": "shouldn't",
            "wouldnt": "wouldn't",
            "couldnt": "couldn't",
            "mustnt": "mustn't",
            "thats": "that's",
            "whats": "what's",
            "heres": "here's",
            "theres": "there's",
            "wheres": "where's",
            "hows": "how's",
            "whos": "who's",
            "its": "it's" // Be careful with this one, sometimes "its" is correct
        ]
        
        for (wrong, correct) in wordFixes {
            // Use word boundaries to avoid partial matches
            let pattern = "\\b\(wrong)\\b"
            fixed = fixed.replacingOccurrences(of: pattern, with: correct, options: [.regularExpression, .caseInsensitive])
        }
        
        return fixed
    }
    
    nonisolated private func improveSentenceFlow(_ text: String) -> String {
        var improved = text
        
        // Basic capitalization (only if clearly needed)
        if !improved.isEmpty {
            let firstChar = improved.first!
            if firstChar.isLetter && firstChar.isLowercase {
                improved = String(firstChar.uppercased()) + String(improved.dropFirst())
            }
        }
        
        // REMOVED: Aggressive period insertion that was causing "gravel-like" flow
        // Let natural speech flow without forcing sentence boundaries
        
        // Fix only obvious spacing issues around punctuation
        improved = improved.replacingOccurrences(of: " \\.", with: ".", options: .regularExpression)
        improved = improved.replacingOccurrences(of: " ,", with: ",", options: .regularExpression)
        improved = improved.replacingOccurrences(of: " !", with: "!", options: .regularExpression)
        improved = improved.replacingOccurrences(of: " \\?", with: "?", options: .regularExpression)
        
        return improved
    }
    
    // REMOVED: looksLikeCompleteSentence function - was causing forced sentence boundaries
    // User feedback: "don't try to force 'sentence stop' - it makes for a very unnatural experience"
    
    nonisolated private func updateOutputState(text: String, timestamp: Date) {
        lastOutputText = text
        lastOutputTimestamp = timestamp
        
        // v1.1.3.2 ANTI-HALLUCINATION: Quality-gated context preservation
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Only preserve context if we're NOT in silence mode and text quality is high
        if !isInSilenceMode && 
           consecutiveLowQualityCount == 0 && // Only from high-quality audio
           cleanText.count <= 10 && 
           !cleanText.hasSuffix(".") && 
           !cleanText.hasSuffix("!") && 
           !cleanText.hasSuffix("?") &&
           !cleanText.hasSuffix(",") &&
           !cleanText.contains(" ") { // Only single incomplete words
            previousSentence = cleanText
            debugPrint("🔗 Preserving quality-gated context: '\(cleanText)'", source: "SimpleAudioEngine")
        } else {
            // Clear context aggressively to prevent hallucinations
            previousSentence = ""
            if isInSilenceMode {
                debugPrint("🧹 Clearing context (silence mode): '\(cleanText)'", source: "SimpleAudioEngine")
            } else if consecutiveLowQualityCount > 0 {
                debugPrint("🧹 Clearing context (low quality): '\(cleanText)' (lowQualityCount: \(consecutiveLowQualityCount))", source: "SimpleAudioEngine")
            } else {
                debugPrint("🧹 Clearing context (punctuated/long): '\(cleanText)' (length: \(cleanText.count))", source: "SimpleAudioEngine")
            }
        }
    }
    
    // MARK: - v1.1.3.3 Audio Mode Processing (Device-Agnostic)
    
    nonisolated private func applyAudioModeProcessing(to samples: [Float]) -> [Float] {
        switch audioMode {
        case .mono:
            // Mono mode: no additional processing (current optimized behavior)
            return samples
            
        case .goobero:
            // Goobero mode: clean processing for dual channel VAD-protected mode
            debugPrint("🎧 Goobero mode: processing clean dual channel audio", source: "SimpleAudioEngine")
            return samples
        }
    }
    
    // MARK: - Bluetooth Device Detection
    
    /// Determines if the current input device is likely a Bluetooth device
    /// This is used to apply appropriate audio processing optimizations
    nonisolated private func isLikelyBluetoothDevice(inputFormat: AVAudioFormat) -> Bool {
        // Use the provided input format for detection instead of accessing actor properties
        
        // Bluetooth devices typically have specific characteristics:
        // 1. Lower sample rates (often 8kHz, 16kHz, or 44.1kHz)
        // 2. Compressed audio quality indicators
        // 3. Mono channel configuration for many BT devices
        
        let sampleRate = inputFormat.sampleRate
        let channels = inputFormat.channelCount
        
        // Check for typical Bluetooth audio characteristics
        let isLowSampleRate = sampleRate <= 16000 || sampleRate == 44100
        let isMonoOrStereo = channels <= 2
        
        // Additional heuristic: check if device name contains Bluetooth indicators
        // This is a simplified heuristic - in practice, you'd query Core Audio for device info
        var isBluetoothLikely = false
        
        if isLowSampleRate && isMonoOrStereo {
            // Further analysis could be done here by checking:
            // - Audio device properties through Core Audio
            // - Device transport type (kAudioDevicePropertyTransportType)
            // - Device manufacturer ID
            isBluetoothLikely = true
            
            debugPrint("🔍 Device characteristics suggest Bluetooth: sampleRate=\(sampleRate)Hz, channels=\(channels)", source: "SimpleAudioEngine")
        }
        
        debugPrint("🔍 Bluetooth device detection result: \(isBluetoothLikely)", source: "SimpleAudioEngine")
        return isBluetoothLikely
    }
    
    /// Applies specialized optimizations for single earbud Bluetooth devices
    /// This method enhances the existing single earbud optimizations specifically for Bluetooth characteristics
    nonisolated private func applySingleEarbudOptimizations(to samples: [Float], inputFormat: AVAudioFormat) -> [Float] {
        debugPrint("🎧 Applying single earbud optimizations to \(samples.count) samples", source: "SimpleAudioEngine")
        
        var optimizedSamples = samples
        
        // Check if this is likely a Bluetooth device for additional processing
        let isBluetoothDevice = isLikelyBluetoothDevice(inputFormat: inputFormat)
        
        if isBluetoothDevice {
            debugPrint("🔵 Detected Bluetooth device - applying enhanced optimizations", source: "SimpleAudioEngine")
            
            // Additional Bluetooth-specific optimizations
            // 1. Compensate for Bluetooth compression artifacts
            optimizedSamples = compensateBluetoothCompression(samples: optimizedSamples)
            
            // 2. Apply enhanced noise reduction for Bluetooth transmission noise
            optimizedSamples = applyBluetoothNoiseReduction(samples: optimizedSamples)
        }
        
        // Apply the standard single earbud optimizations (REDUCED AGGRESSIVENESS)
        
        // 1. SUBTLE GAIN BOOST: Gentle enhancement based on signal amplitude
        for i in 0..<optimizedSamples.count {
            let amplitude = abs(optimizedSamples[i])
            
            if amplitude < 0.005 {
                // Very quiet signals - minimal boost
                optimizedSamples[i] *= 1.2 // 1.2x boost for extremely quiet (was 4x)
            } else if amplitude < 0.015 {
                // Quiet signals - slight boost
                optimizedSamples[i] *= 1.15 // 1.15x boost for quiet (was 3x)
            } else if amplitude < 0.035 {
                // Moderate signals - very subtle enhancement
                optimizedSamples[i] *= 1.1 // 1.1x boost for moderate (was 2x)
            }
            // All other signals get no additional boost to preserve naturalness
            
            // Prevent clipping after gain boost
            optimizedSamples[i] = max(-1.0, min(1.0, optimizedSamples[i]))
        }
        
        // 2. SUBTLE FREQUENCY COMPENSATION: Minimal adjustment for speech clarity
        let frequencyBoost: Float = isBluetoothDevice ? 1.05 : 1.03 // Very subtle boost (was 1.4/1.3)
        for i in 0..<optimizedSamples.count {
            optimizedSamples[i] *= frequencyBoost
            optimizedSamples[i] = max(-1.0, min(1.0, optimizedSamples[i])) // Prevent clipping
        }
        
        // 3. MINIMAL NOISE FLOOR: Conservative noise reduction
        let noiseFloor: Float = isBluetoothDevice ? 0.002 : 0.001 // Lower threshold for natural sound
        for i in 0..<optimizedSamples.count {
            if abs(optimizedSamples[i]) < noiseFloor {
                optimizedSamples[i] *= 0.5 // Reduce rather than eliminate (was 0.0)
            }
        }
        
        let optimizationType = isBluetoothDevice ? "Bluetooth + single earbud" : "single earbud"
        debugPrint("🎧 \(optimizationType) optimizations applied: subtle gain + minimal frequency compensation + conservative noise reduction", source: "SimpleAudioEngine")
        
        return optimizedSamples
    }
    
    /// Compensates for Bluetooth audio compression artifacts (REDUCED AGGRESSIVENESS)
    nonisolated private func compensateBluetoothCompression(samples: [Float]) -> [Float] {
        var compensated = samples
        
        // Apply very subtle high-frequency emphasis to counteract Bluetooth compression
        // This is a simplified approach - in practice, you might use more sophisticated DSP
        for i in 1..<compensated.count {
            // Simple high-pass filter effect to restore some high-frequency detail
            let highFreqComponent = compensated[i] - compensated[i-1]
            compensated[i] += highFreqComponent * 0.03 // Very subtle emphasis (was 0.1)
            
            // Prevent clipping
            compensated[i] = max(-1.0, min(1.0, compensated[i]))
        }
        
        debugPrint("🔵 Applied subtle Bluetooth compression compensation", source: "SimpleAudioEngine")
        return compensated
    }
    
    /// Applies noise reduction specifically tuned for Bluetooth transmission artifacts (REDUCED AGGRESSIVENESS)
    nonisolated private func applyBluetoothNoiseReduction(samples: [Float]) -> [Float] {
        var filtered = samples
        
        // Simple noise gate with Bluetooth-specific threshold
        let bluetoothNoiseGate: Float = 0.002 // Lower threshold for more natural sound (was 0.004)
        
        for i in 0..<filtered.count {
            if abs(filtered[i]) < bluetoothNoiseGate {
                filtered[i] *= 0.7 // Minimal reduction to maintain naturalness (was 0.3)
            }
        }
        
        debugPrint("🔵 Applied minimal Bluetooth-specific noise reduction", source: "SimpleAudioEngine")
        return filtered
    }
    
    
    // MARK: - v1.1.3 Simple Text Cleanup (removed complex sentence completion logic)
    
    // MARK: - v1.1.3 Helper Methods (removed old v1.1.2 methods)
    
    // MARK: - v1.1.3 Context Management (simplified for discrete chunks)
    
    // MARK: - Public Interface (UI Compatibility)
    
    func initialize() async {
        guard !isInitialized else { 
            await DebugLogger.warning("Already initialized", source: "SimpleAudioEngine")
            return 
        }
        
        await DebugLogger.engine("Starting initialization...", source: "SimpleAudioEngine")
        debugPrint("🔧 SimpleAudioEngine: Starting initialization in async context", source: "SimpleAudioEngine")
        
        // Request microphone permission
        debugPrint("🔧 SimpleAudioEngine: Requesting microphone permission...", source: "SimpleAudioEngine")
        await requestMicrophonePermission()
        
        // CRITICAL FIX: Proper audio session configuration BEFORE creating engine
        await configureAudioSession()
        
        // Initialize audio engine
        debugPrint("🔧 SimpleAudioEngine: Creating AVAudioEngine...", source: "SimpleAudioEngine")
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        outputNode = audioEngine?.outputNode
        
        debugPrint("🔧 SimpleAudioEngine: Audio engine components:", source: "SimpleAudioEngine")
        debugPrint("   - AudioEngine: \(audioEngine != nil ? "✅" : "❌")", source: "SimpleAudioEngine")
        debugPrint("   - InputNode: \(inputNode != nil ? "✅" : "❌")", source: "SimpleAudioEngine")
        debugPrint("   - OutputNode: \(outputNode != nil ? "✅" : "❌")", source: "SimpleAudioEngine")
        
        // Debug: Log input device information
        if let inputNode = inputNode {
            let inputFormat = inputNode.outputFormat(forBus: 0)
            await DebugLogger.audio("📱 Current Input Device Format Details:", source: "SimpleAudioEngine")
            await DebugLogger.audio("   Sample Rate: \(inputFormat.sampleRate) Hz", source: "SimpleAudioEngine")
            await DebugLogger.audio("   Channels: \(inputFormat.channelCount)", source: "SimpleAudioEngine")
            await DebugLogger.audio("   Format: \(inputFormat.commonFormat.rawValue)", source: "SimpleAudioEngine")
            await DebugLogger.audio("   Interleaved: \(inputFormat.isInterleaved)", source: "SimpleAudioEngine")
            await DebugLogger.audio("   Full format: \(inputFormat)", source: "SimpleAudioEngine")
        }
        
        // Initialize engine-specific components based on selected engine
        switch transcriptionEngine {
        case .whisper:
            print("🔧 SimpleAudioEngine: Initializing Whisper engine...")
            await initializeWhisper()
            print("🔧 SimpleAudioEngine: Whisper context: \(context != nil ? "✅" : "❌")")
            
        case .appleSpeech:
            print("🔧 SimpleAudioEngine: Initializing Apple Speech engine...")
            await initializeAppleSpeech()
            print("🔧 SimpleAudioEngine: Apple Speech: \(speechRecognizer != nil ? "✅" : "❌")")
            
        case .assembly:
            print("🔧 SimpleAudioEngine: AssemblyAI engine - using service-based initialization")
            // AssemblyAI service is initialized in setTranscriptionEngine, no additional setup needed here
        }
        
        isInitialized = true
        print("✅ SimpleAudioEngine: Initialization complete for \(transcriptionEngine.rawValue) engine")
        print("✅ SimpleAudioEngine: Ready for recording")
    }
    
    // Separate callbacks for AssemblyAI to prevent UI conflicts
    func setAssemblyAICallback(_ callback: @escaping (String) -> Void) {
        assemblyAITranscriptionCallback = callback
    }
    
    func setAssemblyAIPartialCallback(_ callback: @escaping (String) -> Void) {
        assemblyAIPartialCallback = callback
    }
    
    func startRecording(callback: @escaping (String) -> Void) async {
        guard !isRecording else { return }
        
        transcriptionCallback = callback
        
        // CRITICAL FIX: Reinitialize if needed after cleanup
        if audioEngine == nil || inputNode == nil || context == nil {
            print("🔄 Reinitializing audio engine after cleanup...")
            await initialize()
        }
        
        // CRITICAL FIX: Start AssemblyAI streaming if using AssemblyAI engine
        if transcriptionEngine == .assembly {
            print("🌐 STARTING ASSEMBLY AI STREAMING")
            do {
                try await assemblyAIService?.startStreaming()
                print("✅ AssemblyAI streaming started successfully")
            } catch {
                print("❌ Failed to start AssemblyAI streaming: \(error)")
                return
            }
        }
        
        guard let audioEngine = audioEngine,
              let inputNode = inputNode else {
            print("❌ Audio engine failed to initialize")
            return
        }
        
        await DebugLogger.audio("Starting recording", source: "SimpleAudioEngine")
        
        // CRITICAL FIX: Ensure clean engine state before installing taps
        await ensureCleanEngineState()
        
        // Set up audio tap for transcription
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let whisperFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, 
                                        sampleRate: 16000, 
                                        channels: 1, 
                                        interleaved: false)!
        
        await DebugLogger.audio("🔍 AUDIO FORMAT ANALYSIS:", source: "SimpleAudioEngine")
        await DebugLogger.audio("📥 INPUT FORMAT:", source: "SimpleAudioEngine")
        await DebugLogger.audio("   Sample Rate: \(inputFormat.sampleRate) Hz", source: "SimpleAudioEngine")
        await DebugLogger.audio("   Channels: \(inputFormat.channelCount)", source: "SimpleAudioEngine")
        await DebugLogger.audio("   Common Format: \(inputFormat.commonFormat.rawValue)", source: "SimpleAudioEngine")
        await DebugLogger.audio("   Interleaved: \(inputFormat.isInterleaved)", source: "SimpleAudioEngine")
        
        await DebugLogger.audio("📤 TARGET FORMAT (Whisper):", source: "SimpleAudioEngine")
        await DebugLogger.audio("   Sample Rate: \(whisperFormat.sampleRate) Hz", source: "SimpleAudioEngine")
        await DebugLogger.audio("   Channels: \(whisperFormat.channelCount)", source: "SimpleAudioEngine")
        await DebugLogger.audio("   Common Format: \(whisperFormat.commonFormat.rawValue)", source: "SimpleAudioEngine")
        await DebugLogger.audio("   Interleaved: \(whisperFormat.isInterleaved)", source: "SimpleAudioEngine")
        
        // Create the reusable converter
        audioConverter = AVAudioConverter(from: inputFormat, to: whisperFormat)
        if audioConverter != nil {
            await DebugLogger.audio("✅ AVAudioConverter created successfully for reuse", source: "SimpleAudioEngine")
        } else {
            await DebugLogger.error("❌ AVAudioConverter CANNOT be created - format incompatibility!", source: "SimpleAudioEngine")
            await DebugLogger.error("This means \(inputFormat.sampleRate)Hz \(inputFormat.channelCount)ch → 16kHz 1ch conversion is not supported", source: "SimpleAudioEngine")
            return
        }
        
        // CRITICAL FIX: Defensive tap installation with validation and retry
        let tapInstalled = await installTapWithRetry(
            inputNode: inputNode, 
            inputFormat: inputFormat, 
            whisperFormat: whisperFormat
        )
        
        guard tapInstalled else {
            await DebugLogger.error("❌ Failed to install audio tap after retries", source: "SimpleAudioEngine")
            return
        }
        
        // CRITICAL FIX: Proper initialization order - setup all connections BEFORE starting engine
        
        // 1. First set up passthrough connections if enabled
        if passthroughEnabled {
            setupPassthrough(inputFormat: inputFormat)
        }
        
        // 2. Start the engine AFTER all connections are made
        do {
            try audioEngine.start()
            isRecording = true
            await DebugLogger.audio("✅ SimpleAudioEngine: Audio engine started successfully with proper initialization order", source: "SimpleAudioEngine")
            print("✅ SimpleAudioEngine: Recording started")
        } catch {
            await DebugLogger.error("❌ Failed to start audio engine: \(error)", source: "SimpleAudioEngine")
            print("❌ Failed to start audio engine: \(error)")
            
            // CRITICAL: Clean up tap before throwing error
            inputNode.removeTap(onBus: 0)
            
            // Reset engine state for retry
            audioEngine.stop()
            audioEngine.reset()
        }
    }
    
    func stopRecording() async {
        guard isRecording else { return }
        
        await DebugLogger.audio("Stopping recording", source: "SimpleAudioEngine")
        
        // CRITICAL FIX: Thread-safe cleanup with dedicated queue
        isRecording = false
        
        await performThreadSafeCleanup()
        
        print("✅ SimpleAudioEngine: Recording stopped")
    }
    
    // CRITICAL FIX: Thread-safe cleanup implementation
    private func performThreadSafeCleanup() async {
        // SIMPLIFIED: Direct cleanup within actor context (thread-safe by design)
        await DebugLogger.engine("Starting cleanup...", source: "SimpleAudioEngine")
        
        // Step 1: Remove tap before stopping engine (prevents crashes)
        if let inputNode = self.inputNode {
            inputNode.removeTap(onBus: 0)
        }
        
        // Step 2: Stop and reset engine safely
        if let audioEngine = self.audioEngine {
            audioEngine.stop()
            audioEngine.reset()
        }
        
        // Step 3: Clear references
        self.audioEngine = nil
        self.inputNode = nil
        self.outputNode = nil
        self.audioConverter = nil
        
        // Step 4: Free Whisper context on dedicated whisper queue
        if let context = self.context {
            await withCheckedContinuation { continuation in
                whisperQueue.async {
                    whisper_bridge_free_context(context)
                    continuation.resume()
                }
            }
            self.context = nil
        }
        
        // Step 5: CRITICAL FIX - Reset initialization flag to allow reinitialization
        self.isInitialized = false
        
        await DebugLogger.engine("Cleanup completed", source: "SimpleAudioEngine")
    }
    
    // MARK: - Configuration Methods (UI Interface)
    
    func setAudioMode(_ mode: AudioMode) {
        audioMode = mode
        print("🎤 Audio mode: \(mode.rawValue)")
    }
    
    func setTranscriptionEngine(_ engine: TranscriptionEngine) async {
        transcriptionEngine = engine
        print("🎤 Transcription engine: \(engine.rawValue)")
        
        if engine == .appleSpeech {
            print("🍎 Apple Speech engine configured")
        } else if engine == .assembly {
            await initializeAssemblyAI()
            print("🔗 AssemblyAI engine configured")
        } else {
            await stopAssemblyAI()
        }
    }
    
    func setMonoLanguage(_ language: String) {
        monoLanguage = language
        print("🌍 Language: \(language)")
    }
    
    func setLeftChannelLanguage(_ language: String) {
        leftChannelLanguage = language
        print("🌍 Left channel language: \(language)")
    }
    
    func setRightChannelLanguage(_ language: String) {
        rightChannelLanguage = language
        print("🌍 Right channel language: \(language)")
    }
    
    func setSpeakerNames(left: String, right: String) {
        leftSpeakerName = left
        rightSpeakerName = right
        print("🎭 Speaker names set - Left: \(left), Right: \(right)")
    }
    
    func setNoiseSuppression(_ level: Double) {
        noiseSuppression = max(0.0, min(1.0, level))
        print("🔇 Noise suppression: \(Int(noiseSuppression * 100))%")
    }
    
    // MARK: - AssemblyAI Integration Methods
    
    private func initializeAssemblyAI() async {
        // AssemblyAI initialization is handled by AppState
        // This method is here for consistency and future direct integration
        print("🔗 AssemblyAI integration initialized")
    }
    
    private func stopAssemblyAI() async {
        // AssemblyAI cleanup is handled by AppState
        print("🔗 AssemblyAI integration stopped")
    }
    
    // REMOVED: routeAudioToAssemblyAI method - redundant due to early return pattern
    // AssemblyAI audio routing is handled by streamDirectlyToAssemblyAI in processAudioBuffer
    
    func setInputDevice(_ device: AudioDevice?) async {
        await DebugLogger.audio("🎤 Setting input device: \(device?.name ?? "nil")", source: "SimpleAudioEngine")
        
        // CRITICAL FIX: If recording, stop and restart with new device
        let wasRecording = isRecording
        
        if wasRecording {
            await DebugLogger.audio("🔄 Input device change during recording - performing safe restart", source: "SimpleAudioEngine")
            
            // Stop current recording safely
            await stopRecording()
            
            // CRITICAL: Extended wait for audio system to fully settle after device change
            await DebugLogger.audio("🕐 Waiting 1000ms for audio system to settle...", source: "SimpleAudioEngine")
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        }
        
        // Configure the new device
        if let device = device {
            await configureAudioSessionForDevice(device)
            
            // Additional wait after device configuration
            await DebugLogger.audio("🕐 Waiting 500ms after device configuration...", source: "SimpleAudioEngine")
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms delay
        }
        
        // Restart recording if it was active
        if wasRecording {
            await DebugLogger.audio("🔄 Restarting recording with new input device", source: "SimpleAudioEngine")
            
            // Re-initialize the audio engine to pick up the new input device
            await reinitializeAudioEngine()
            
            // Additional wait after reinitialization
            await DebugLogger.audio("🕐 Waiting 300ms after engine reinitialization...", source: "SimpleAudioEngine")
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
            
            // Restart recording
            if let callback = transcriptionCallback {
                await startRecording(callback: callback)
            }
        }
    }
    
    func setOutputDevice(_ device: AudioDevice?) async {
        selectedOutputDevice = device
        if let device = device {
            print("🔊 Output device: \(device.name)")
            await configureAudioSessionForOutputDevice(device)
        }
    }
    
    private func configureAudioSessionForDevice(_ device: AudioDevice) async {
        await DebugLogger.audio("🔧 Configuring audio session for INPUT device: \(device.name) (ID: \(device.id))", source: "SimpleAudioEngine")
        
        // Use Core Audio to configure the default input device
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceID = device.id
        let propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            propertySize,
            &deviceID
        )
        
        if status == noErr {
            await DebugLogger.audio("✅ Successfully set system default input to: \(device.name)", source: "SimpleAudioEngine")
        } else {
            await DebugLogger.error("❌ Failed to set input device: OSStatus \(status)", source: "SimpleAudioEngine")
        }
    }
    
    private func configureAudioSessionForOutputDevice(_ device: AudioDevice) async {
        await DebugLogger.audio("🔧 Configuring audio session for OUTPUT device: \(device.name) (ID: \(device.id))", source: "SimpleAudioEngine")
        
        // Use Core Audio to configure the default output device
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceID = device.id
        let propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            propertySize,
            &deviceID
        )
        
        if status == noErr {
            await DebugLogger.audio("✅ Successfully set system default output to: \(device.name)", source: "SimpleAudioEngine")
        } else {
            await DebugLogger.error("❌ Failed to set output device: OSStatus \(status)", source: "SimpleAudioEngine")
        }
    }
    
    func setPassthroughEnabled(_ enabled: Bool) async {
        passthroughEnabled = enabled
        await DebugLogger.audio("Passthrough \(enabled ? "ENABLED" : "DISABLED")", source: "SimpleAudioEngine")
        
        if isRecording {
            // CRITICAL FIX: Avoid dynamic changes during recording - restart instead
            print("⚠️ Passthrough change during recording requires restart for stability")
            
            // Note: The setting is saved, restart will apply it
            // This prevents crashes from modifying the audio graph during recording
            print("ℹ️ Passthrough setting will be applied on next recording session")
        } else {
            print("ℹ️ Passthrough setting saved for next recording session")
        }
    }
    
    func setTranscriptionCallbacks(
        mixedCallback: @escaping (String) -> Void,
        leftCallback: @escaping (String) -> Void,
        rightCallback: @escaping (String) -> Void
    ) {
        mixedChannelCallback = mixedCallback
        leftChannelCallback = leftCallback  
        rightChannelCallback = rightCallback
    }
    
    func setTranscriptionCallbacks(
        mixed: @escaping (String) -> Void,
        left: @escaping (String) -> Void,
        right: @escaping (String) -> Void
    ) async {
        mixedChannelCallback = mixed
        leftChannelCallback = left
        rightChannelCallback = right
        print("🎯 Transcription callbacks configured")
    }
    
    func setRecordingCallback(_ callback: @escaping (AVAudioPCMBuffer) -> Void) async {
        recordingCallback = callback
        print("🎙️ Recording callback configured")
    }
    
    // MARK: - AssemblyAI Integration Methods
    
    func configureAssemblyAI(apiKey: String) async {
        print("🔑 AssemblyAI API key configured")
        assemblyAIService = await AssemblyAITranscriptionService(apiKey: apiKey)
        
        await MainActor.run {
            // Set up callbacks to connect AssemblyAI service to app state
            assemblyAIService?.transcriptionCallback = { [weak self] text in
                self?.assemblyAITranscriptionCallback?(text)
            }
            
            assemblyAIService?.partialTranscriptionCallback = { [weak self] text in
                self?.assemblyAIPartialCallback?(text)
            }
        }
        
        print("🔗 AssemblyAI integration initialized")
        print("🔗 AssemblyAI engine configured")
    }
    
    /// Direct audio streaming to AssemblyAI (bypassing traditional pipeline)
    private func streamDirectlyToAssemblyAI(_ buffer: AVAudioPCMBuffer) async {
        guard let service = assemblyAIService else {
            print("❌ AssemblyAI service not available for direct streaming")
            return
        }
        
        // Convert buffer to Float array for AssemblyAI service
        guard let channelData = buffer.floatChannelData?[0] else {
            print("❌ No channel data in buffer for AssemblyAI streaming")
            return
        }
        
        let frameCount = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        
        // Convert to proper format if needed (resample to 16kHz mono)
        let inputSampleRate = buffer.format.sampleRate
        let targetSamples: [Float]
        
        if inputSampleRate != 16000.0 {
            // Simple downsampling if needed
            let downsampleRatio = max(1, Int(inputSampleRate / 16000.0))
            targetSamples = stride(from: 0, to: samples.count, by: downsampleRatio).map { samples[$0] }
        } else {
            targetSamples = samples
        }
        
        // Stream directly to AssemblyAI
        await MainActor.run {
            service.handleAudioData(targetSamples)
        }
    }
    
    // MARK: - Private Implementation
    
    // CRITICAL FIX: Ensure audio engine is in clean state before installing taps
    private func ensureCleanEngineState() async {
        guard let audioEngine = audioEngine,
              let inputNode = inputNode else { return }
        
        await DebugLogger.audio("🔧 Ensuring clean engine state", source: "SimpleAudioEngine")
        
        // Stop engine if running
        if audioEngine.isRunning {
            await DebugLogger.audio("🛑 Stopping running engine", source: "SimpleAudioEngine")
            audioEngine.stop()
        }
        
        // Remove any existing taps
        inputNode.removeTap(onBus: 0)
        await DebugLogger.audio("🧹 Removed existing taps", source: "SimpleAudioEngine")
        
        // Disconnect passthrough connections
        if passthroughEnabled {
            audioEngine.disconnectNodeOutput(inputNode)
            await DebugLogger.audio("🔌 Disconnected passthrough", source: "SimpleAudioEngine")
        }
        
        // Clear rolling context buffers
        bufferQueue.sync {
            preContextBuffer.removeAll()
            actualBuffer.removeAll() 
            postContextBuffer.removeAll()
        }
        
        // Clean up converter
        audioConverter = nil
        
        await DebugLogger.audio("✅ Engine state cleaned", source: "SimpleAudioEngine")
    }
    
    private func requestMicrophonePermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        debugPrint("🎤 Current microphone permission status: \(status.rawValue)", source: "SimpleAudioEngine")
        
        switch status {
        case .notDetermined:
            debugPrint("🎤 Requesting microphone access...", source: "SimpleAudioEngine")
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            debugPrint("🎤 Microphone permission result: \(granted ? "GRANTED" : "DENIED")", source: "SimpleAudioEngine")
        case .authorized:
            debugPrint("✅ Microphone permission already GRANTED", source: "SimpleAudioEngine")
        case .denied, .restricted:
            debugPrint("❌ Microphone permission DENIED or RESTRICTED", source: "SimpleAudioEngine")
        @unknown default:
            debugPrint("❓ Unknown microphone permission status: \(status.rawValue)", source: "SimpleAudioEngine")
        }
        
        // Final verification
        let finalStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        debugPrint("🎤 Final permission status: \(finalStatus == .authorized ? "AUTHORIZED" : "NOT AUTHORIZED")", source: "SimpleAudioEngine")
    }
    
    // CRITICAL FIX: Proper audio session configuration for recording
    private func configureAudioSession() async {
        debugPrint("🔧 SimpleAudioEngine: Configuring audio session for optimal recording", source: "SimpleAudioEngine")
        
        #if os(macOS)
        // macOS doesn't use AVAudioSession like iOS, but we can still optimize the engine
        debugPrint("🔧 SimpleAudioEngine: Using macOS native audio configuration", source: "SimpleAudioEngine")
        #else
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Configure for recording with measurement mode for low latency
            try audioSession.setCategory(.playAndRecord,
                                       mode: .measurement,
                                       options: [.defaultToSpeaker, .allowBluetooth])
            
            // Set preferred settings for optimal recording
            try audioSession.setPreferredSampleRate(48000) // High quality sample rate
            try audioSession.setPreferredIOBufferDuration(0.005) // 5ms for low latency
            
            // Activate session
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            debugPrint("✅ SimpleAudioEngine: Audio session configured successfully", source: "SimpleAudioEngine")
            debugPrint("   - Category: playAndRecord", source: "SimpleAudioEngine")
            debugPrint("   - Mode: measurement", source: "SimpleAudioEngine")
            debugPrint("   - Sample Rate: 48kHz", source: "SimpleAudioEngine")
            debugPrint("   - Buffer Duration: 5ms", source: "SimpleAudioEngine")
            
        } catch {
            debugPrint("❌ SimpleAudioEngine: Failed to configure audio session: \(error)", source: "SimpleAudioEngine")
        }
        #endif
    }
    
    private func initializeWhisper() async {
        debugPrint("🔧 Creating WhisperModelManager...", source: "SimpleAudioEngine")
        let modelManager = await WhisperModelManager()
        
        debugPrint("🔧 Getting Whisper model path...", source: "SimpleAudioEngine")
        guard let modelPath = await modelManager.getCurrentModelPath() else {
            debugPrint("❌ No Whisper model available", source: "SimpleAudioEngine")
            return
        }
        
        debugPrint("🔧 Initializing Whisper context with model: \(modelPath)", source: "SimpleAudioEngine")
        
        // CRITICAL FIX: Initialize Whisper context on the dedicated thread
        await withCheckedContinuation { continuation in
            whisperQueue.async { [weak self] in
                self?.context = whisper_bridge_init_context(modelPath)
                if self?.context != nil {
                    debugPrint("✅ Whisper initialized successfully on dedicated thread", source: "SimpleAudioEngine")
                } else {
                    debugPrint("❌ Whisper initialization failed", source: "SimpleAudioEngine")
                }
                continuation.resume()
            }
        }
    }
    
    private func initializeAppleSpeech() async {
        do {
            // Request speech recognition authorization
            let authStatus = SFSpeechRecognizer.authorizationStatus()
            if authStatus == .notDetermined {
                // Request authorization
                let status = await withCheckedContinuation { continuation in
                    SFSpeechRecognizer.requestAuthorization { status in
                        continuation.resume(returning: status)
                    }
                }
                if status != .authorized {
                    print("❌ Speech recognition not authorized: \(status)")
                    return
                }
            } else if authStatus != .authorized {
                print("❌ Speech recognition not authorized: \(authStatus)")
                return
            }
            
            // Initialize speech recognizer for current locale
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: monoLanguage))
            guard let recognizer = speechRecognizer, recognizer.isAvailable else {
                print("❌ Speech recognizer not available for language: \(monoLanguage)")
                return
            }
            
            print("✅ Apple Speech initialized for language: \(monoLanguage)")
        } catch {
            print("❌ Apple Speech initialization failed: \(error)")
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) async {
        // RECORDING: Send audio to recording callback before any processing
        // This ensures we capture the original audio format and quality
        if let recordingCallback = recordingCallback {
            recordingCallback(buffer)
        }
        
        // Handle AssemblyAI direct streaming
        if transcriptionEngine == .assembly {
            await streamDirectlyToAssemblyAI(buffer)
            return
        }
        
        // Passthrough handled natively by direct input→output connection
        // No buffer processing needed for passthrough
        
        // Validate input buffer has audio data
        guard let channelData = buffer.floatChannelData?[0] else {
            await DebugLogger.error("❌ Input buffer has no channel data!", source: "SimpleAudioEngine")
            return
        }
        
        // Use the reusable converter
        guard let converter = audioConverter else {
            await DebugLogger.error("❌ Audio converter not available", source: "SimpleAudioEngine")
            return
        }
        
        // Calculate proper output buffer capacity based on sample rate conversion
        let sampleRateRatio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = UInt32(Double(buffer.frameLength) * sampleRateRatio) + 100 // Add padding
        
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
            await DebugLogger.error("❌ Failed to create converted buffer with capacity \(outputFrameCapacity)", source: "SimpleAudioEngine")
            return
        }
        
        var error: NSError?
        
        // Proper AVAudioConverterInputBlock implementation
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
        
        if error != nil || status == .error {
            await DebugLogger.error("❌ Conversion error: \(error?.localizedDescription ?? "Unknown") status: \(status.rawValue)", source: "SimpleAudioEngine")
            return
        }
        
        guard let channelData = convertedBuffer.floatChannelData?[0] else {
            await DebugLogger.error("❌ No channel data in converted buffer", source: "SimpleAudioEngine")
            return
        }
        
        // Accumulate audio for processing
        let frameCount = Int(convertedBuffer.frameLength)
        
        // ASSEMBLYAI INTEGRATION: Handled by early return in processAudioBuffer
        // This code should never execute due to early return at method start
        
        // GOOBERO MODE: Handle L/R channel separation
        debugPrint("🎧 AUDIO MODE CHECK: audioMode=\(audioMode), buffer.channels=\(buffer.format.channelCount), condition=\(audioMode == .goobero && buffer.format.channelCount >= 2)", source: "SimpleAudioEngine")
        
        if audioMode == .goobero && buffer.format.channelCount >= 2 {
            // Extract left and right channels from stereo input
            debugPrint("🎧 ENTERING GOOBERO MODE: calling processStereoChannels", source: "SimpleAudioEngine")
            await processStereoChannels(buffer: buffer, targetFormat: targetFormat)
        } else {
            // MONO MODE: Process through proven mono pipeline
            let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
            
            // v1.0.8 ENHANCEMENT: Rolling window buffer management
            bufferQueue.sync {
            // Add new samples to post-context buffer (future audio)
            postContextBuffer.append(contentsOf: samples)
            
            // Debug: Log buffer accumulation
            let totalSamples = preContextBuffer.count + actualBuffer.count + postContextBuffer.count
            if totalSamples % (contextWindowSize / 4) == 0 { // Every 0.75s
                Task {
                    await DebugLogger.audio("🔄 Rolling buffers: pre(\(preContextBuffer.count)) + actual(\(actualBuffer.count)) + post(\(postContextBuffer.count)) = \(totalSamples)", source: "SimpleAudioEngine")
                }
            }
            
            // v1.0.8 ENHANCEMENT: Process when post-context buffer reaches 3 seconds
            let currentTime = Date()
            
            if postContextBuffer.count >= contextWindowSize {
                // v1.0.8 ENHANCEMENT: Always process exactly 3 seconds for consistency
                let samplesForProcessing = Array(postContextBuffer.prefix(contextWindowSize))
                
                // Perform VAD analysis on the 3-second block
                let vadDecision = self.performAdvancedVAD(samples: samplesForProcessing)
                let speechBoundaryDetected = self.detectSpeechBoundary(vadDecision: vadDecision, currentTime: currentTime)
                
                // v1.0.8 ENHANCEMENT: Simplified quality check for rolling window
                let hasMinimumDuration = samplesForProcessing.count >= contextWindowSize // Always true for 3s blocks
                let rateLimitOk = lastProcessingTime.map { 
                    currentTime.timeIntervalSince($0) >= minimumProcessingInterval 
                } ?? true
                
                let shouldProcess = rateLimitOk && (vadDecision || speechBoundaryDetected)
                
                // Debug: Log processing decision
                Task {
                    await DebugLogger.audio("Quality check: samples=\(samplesForProcessing.count), VAD=\(vadDecision ? "SPEECH" : "SILENCE"), boundary=\(speechBoundaryDetected), process=\(shouldProcess)", source: "SimpleAudioEngine")
                }
                
                if shouldProcess {
                    // v1.0.8 ENHANCEMENT: Create 9-second context window for transcription
                    // Simple processing for now - use the 3.5s buffer as-is
                    let fullContextSamples = samplesForProcessing
                    
                    // Simple buffer processing (placeholder)
                    debugPrint("🔄 Processing buffer with \(fullContextSamples.count) samples", source: "SimpleAudioEngine")
                    
                    lastProcessedTimestamp = currentTime
                    lastProcessingTime = currentTime
                    
                    // FIXED: Complete Whisper processing implementation
                    whisperQueue.async { [weak self] in
                        guard let self = self,
                              let context = self.context else {
                            debugPrint("❌ Whisper context not available", source: "SimpleAudioEngine")
                            return
                        }
                        
                        debugPrint("🎙️ Processing \(fullContextSamples.count) samples with Whisper", source: "SimpleAudioEngine")
                        
                        // Apply audio mode processing
                        let processedSamples = self.applyAudioModeProcessing(to: fullContextSamples)
                        
                        // Call Whisper API with language
                        let result = whisper_bridge_transcribe_with_language(
                            context,
                            processedSamples,
                            Int32(processedSamples.count),
                            self.monoLanguage
                        )
                        
                        // Process result and callback
                        if let result = result,
                           let text = String(cString: result, encoding: .utf8),
                           !text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                            
                            debugPrint("✅ Whisper result: \(text)", source: "SimpleAudioEngine")
                            
                            // Call transcription callback on MainActor
                            Task { @MainActor in
                                self.transcriptionCallback?(text)
                            }
                        } else {
                            debugPrint("⚠️ Whisper returned empty result", source: "SimpleAudioEngine")
                        }
                    }
                } else {
                    // v1.0.8 CRITICAL: Always consume the buffer to prevent infinite loops
                    // Even if we don't process, we need to shift the buffer to prevent repetition
                    if postContextBuffer.count >= contextWindowSize {
                        let consumedSamples = Array(postContextBuffer.prefix(contextWindowSize))
                        // CRITICAL FIX: Actually remove consumed samples from buffer
                        postContextBuffer.removeFirst(contextWindowSize)
                        debugPrint("🔄 Buffer consumed: \(consumedSamples.count) samples, remaining: \(postContextBuffer.count)", source: "SimpleAudioEngine")
                        
                        Task {
                            await DebugLogger.audio("🚫 Skipped processing but consumed \(consumedSamples.count) samples to prevent repetition", source: "SimpleAudioEngine")
                        }
                    }
                }
            }
        }
        } // End of mono mode processing
        
        // GOOBERO MODE: Dual channel processing using proven mono pipeline
        if audioMode == .goobero && buffer.format.channelCount >= 2 {
            await processGooberoChannels(buffer: buffer, targetFormat: targetFormat)
        }
    }
    
    // MARK: - Goobero Channel Processing (Clean Implementation)
    
    private func processGooberoChannels(buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) async {
        debugPrint("🎧 GOOBERO: Starting dual channel processing", source: "SimpleAudioEngine")
        
        guard let channelData = buffer.floatChannelData,
              buffer.format.channelCount >= 2,
              buffer.frameLength > 0 else {
            debugPrint("❌ GOOBERO: Invalid buffer - channels: \(buffer.format.channelCount), frames: \(buffer.frameLength)", source: "SimpleAudioEngine")
            return
        }
        
        let frameCount = Int(buffer.frameLength)
        
        // Extract left channel (channel 0) - hardware pre-split
        let leftChannelData = channelData[0]
        let leftSamples = Array(UnsafeBufferPointer(start: leftChannelData, count: frameCount))
        
        // Extract right channel (channel 1) - hardware pre-split
        let rightChannelData = channelData[1]
        let rightSamples = Array(UnsafeBufferPointer(start: rightChannelData, count: frameCount))
        
        debugPrint("🎧 GOOBERO: Extracted channels L(\(leftSamples.count)) R(\(rightSamples.count))", source: "SimpleAudioEngine")
        
        // PHASE 1 FIX: Use buffer accumulation like stereo mode (3.5 seconds)
        bufferQueue.sync {
            // Accumulate left channel samples
            leftChannelBuffer.append(contentsOf: leftSamples)
            
            // Accumulate right channel samples
            rightChannelBuffer.append(contentsOf: rightSamples)
            
            // Debug: Log goobero buffer accumulation
            let totalLeft = leftChannelBuffer.count
            let totalRight = rightChannelBuffer.count
            
            debugPrint("🎧 GOOBERO: Buffer accumulation L(\(totalLeft)) R(\(totalRight)) / \(stereoBufferSize)", source: "SimpleAudioEngine")
            
            // Process left channel when buffer reaches 3.5 seconds
            if leftChannelBuffer.count >= stereoBufferSize {
                let leftSamplesForProcessing = Array(leftChannelBuffer.prefix(stereoBufferSize))
                
                debugPrint("🎧 GOOBERO LEFT: Buffer full (\(leftChannelBuffer.count) samples), starting VAD analysis", source: "SimpleAudioEngine")
                
                // PHASE 3 FIX: Single VAD decision like mono mode
                let vadDecision = self.performAdvancedVAD(samples: leftSamplesForProcessing)
                let currentTime = Date()
                let speechBoundaryDetected = self.detectSpeechBoundary(vadDecision: vadDecision, currentTime: currentTime)
                
                let rateLimitOk = lastLeftChannelProcessingTime.map { 
                    currentTime.timeIntervalSince($0) >= minimumProcessingInterval 
                } ?? true
                
                let shouldProcess = rateLimitOk && (vadDecision || speechBoundaryDetected)
                
                debugPrint("🎧 GOOBERO LEFT: VAD=\(vadDecision ? "SPEECH" : "SILENCE"), Boundary=\(speechBoundaryDetected), RateLimit=\(rateLimitOk), ShouldProcess=\(shouldProcess)", source: "SimpleAudioEngine")
                
                if shouldProcess {
                    leftChannelBuffer.removeFirst(stereoBufferSize)
                    lastLeftChannelProcessingTime = currentTime
                    
                    // PHASE 4 FIX: Sequential processing to avoid conflicts
                    Task {
                        await self.processGooberoChannelTranscription(samples: leftSamplesForProcessing, channel: "left", language: leftChannelLanguage, speaker: leftSpeakerName)
                    }
                } else {
                    // Consume buffer to prevent infinite loops but don't process
                    leftChannelBuffer.removeFirst(stereoBufferSize)
                    debugPrint("🔇 GOOBERO LEFT: Skipped due to VAD/rate limiting", source: "SimpleAudioEngine")
                }
            }
            
            // Process right channel when buffer reaches 3.5 seconds
            if rightChannelBuffer.count >= stereoBufferSize {
                let rightSamplesForProcessing = Array(rightChannelBuffer.prefix(stereoBufferSize))
                
                debugPrint("🎧 GOOBERO RIGHT: Buffer full (\(rightChannelBuffer.count) samples), starting VAD analysis", source: "SimpleAudioEngine")
                
                // PHASE 3 FIX: Single VAD decision like mono mode
                let vadDecision = self.performAdvancedVAD(samples: rightSamplesForProcessing)
                let currentTime = Date()
                let speechBoundaryDetected = self.detectSpeechBoundary(vadDecision: vadDecision, currentTime: currentTime)
                
                let rateLimitOk = lastRightChannelProcessingTime.map { 
                    currentTime.timeIntervalSince($0) >= minimumProcessingInterval 
                } ?? true
                
                let shouldProcess = rateLimitOk && (vadDecision || speechBoundaryDetected)
                
                debugPrint("🎧 GOOBERO RIGHT: VAD=\(vadDecision ? "SPEECH" : "SILENCE"), Boundary=\(speechBoundaryDetected), RateLimit=\(rateLimitOk), ShouldProcess=\(shouldProcess)", source: "SimpleAudioEngine")
                
                if shouldProcess {
                    rightChannelBuffer.removeFirst(stereoBufferSize)
                    lastRightChannelProcessingTime = currentTime
                    
                    // PHASE 4 FIX: Sequential processing to avoid conflicts
                    Task {
                        await self.processGooberoChannelTranscription(samples: rightSamplesForProcessing, channel: "right", language: rightChannelLanguage, speaker: rightSpeakerName)
                    }
                } else {
                    // Consume buffer to prevent infinite loops but don't process
                    rightChannelBuffer.removeFirst(stereoBufferSize)
                    debugPrint("🔇 GOOBERO RIGHT: Skipped due to VAD/rate limiting", source: "SimpleAudioEngine")
                }
            }
        }
    }
    
    // REMOVED: processGooberoChannel - VAD and rate limiting now handled in processGooberoChannels
    // This eliminates the per-channel conflicts and uses unified processing like mono mode
    
    private func processGooberoChannelTranscription(samples: [Float], channel: String, language: String, speaker: String) async {
        debugPrint("🎧 GOOBERO \(channel.uppercased()): Transcribing \(samples.count) samples, language: \(language)", source: "SimpleAudioEngine")
        
        // Process with Whisper using channel-specific language
        if transcriptionEngine == .whisper {
            if let context = context {
                debugPrint("🎧 GOOBERO \(channel.uppercased()): Calling Whisper", source: "SimpleAudioEngine")
                
                // Apply audio mode processing
                let processedSamples = applyAudioModeProcessing(to: samples)
                
                // Use whisper queue for thread safety
                let result = await withCheckedContinuation { continuation in
                    whisperQueue.async {
                        debugPrint("🎧 Goobero mode: processing clean dual channel audio", source: "SimpleAudioEngine")
                        
                        let whisperResult = whisper_bridge_transcribe_with_language(
                            context,
                            processedSamples,
                            Int32(processedSamples.count),
                            language
                        )
                        continuation.resume(returning: whisperResult)
                    }
                }
                
                if let result = result,
                   let transcription = String(cString: result, encoding: .utf8) {
                    
                    // Clean up the transcription
                    let cleanedText = transcription.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    
                    if !cleanedText.isEmpty {
                        // Format with speaker name
                        let formattedText = "[\(speaker)]: \(cleanedText)"
                        debugPrint("✅ GOOBERO \(channel.uppercased()): \(formattedText)", source: "SimpleAudioEngine")
                        
                        // Route to appropriate callback
                        Task { @MainActor in
                            if channel == "left" {
                                leftChannelCallback?(formattedText)
                            } else {
                                rightChannelCallback?(formattedText)
                            }
                        }
                    }
                } else {
                    debugPrint("⚠️ GOOBERO \(channel.uppercased()): Whisper transcription failed", source: "SimpleAudioEngine")
                }
            }
        }
    }
    
    // MARK: - Stereo Channel Processing
    
    private func processStereoChannels(buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) async {
        debugPrint("🎧 PROCESSSTEREOCHANNELS: ENTRY - channels=\(buffer.format.channelCount), frames=\(buffer.frameLength)", source: "SimpleAudioEngine")
        
        guard let channelData = buffer.floatChannelData,
              buffer.format.channelCount >= 2,
              buffer.frameLength > 0 else {
            debugPrint("❌ PROCESSSTEREOCHANNELS: GUARD FAILED - channels: \(buffer.format.channelCount), frames: \(buffer.frameLength)", source: "SimpleAudioEngine")
            await DebugLogger.error("❌ Invalid stereo buffer - channels: \(buffer.format.channelCount), frames: \(buffer.frameLength)", source: "SimpleAudioEngine")
            return
        }
        
        let frameCount = Int(buffer.frameLength)
        
        // Extract left channel (channel 0) - hardware pre-split
        let leftChannelData = channelData[0]
        let leftSamples = Array(UnsafeBufferPointer(start: leftChannelData, count: frameCount))
        
        // Extract right channel (channel 1) - hardware pre-split
        let rightChannelData = channelData[1]
        let rightSamples = Array(UnsafeBufferPointer(start: rightChannelData, count: frameCount))
        
        // Buffer-based processing for both channels
        bufferQueue.sync {
            // Accumulate left channel samples
            leftChannelBuffer.append(contentsOf: leftSamples)
            
            // Accumulate right channel samples
            rightChannelBuffer.append(contentsOf: rightSamples)
            
            // Debug: Log stereo buffer accumulation
            let totalLeft = leftChannelBuffer.count
            let totalRight = rightChannelBuffer.count
            
            // CRITICAL DEBUG: Log every buffer accumulation to understand the rate
            debugPrint("🎧 BUFFER ACCUMULATION: L(\(totalLeft)) R(\(totalRight)), added L(\(leftSamples.count)) R(\(rightSamples.count))", source: "SimpleAudioEngine")
            
            if totalLeft % (stereoBufferSize / 4) == 0 { // Every ~0.875s
                Task {
                    await DebugLogger.audio("🎧 Stereo buffers: L(\(totalLeft)) R(\(totalRight))", source: "SimpleAudioEngine")
                }
            }
            
            // Process left channel when buffer is full
            if leftChannelBuffer.count >= stereoBufferSize {
                let leftSamplesForProcessing = Array(leftChannelBuffer.prefix(stereoBufferSize))
                
                // CRITICAL DEBUG: Log stereo processing attempt
                debugPrint("🎧 STEREO LEFT: Buffer full (\(leftChannelBuffer.count) samples), starting VAD analysis", source: "SimpleAudioEngine")
                debugPrint("🎧 STEREO LEFT: Buffer threshold reached! stereoBufferSize=\(stereoBufferSize)", source: "SimpleAudioEngine")
                
                // CRITICAL: Apply VAD logic like mono mode (prevent hallucinations)
                let currentTime = Date()
                let vadDecision = self.performAdvancedVAD(samples: leftSamplesForProcessing)
                let speechBoundaryDetected = self.detectSpeechBoundary(vadDecision: vadDecision, currentTime: currentTime)
                let rateLimitOk = lastProcessingTime.map { 
                    currentTime.timeIntervalSince($0) >= minimumProcessingInterval 
                } ?? true
                
                let shouldProcess = rateLimitOk && (vadDecision || speechBoundaryDetected)
                
                // CRITICAL DEBUG: Log VAD decision
                debugPrint("🎧 STEREO LEFT: VAD=\(vadDecision ? "SPEECH" : "SILENCE"), Boundary=\(speechBoundaryDetected), RateLimit=\(rateLimitOk), ShouldProcess=\(shouldProcess)", source: "SimpleAudioEngine")
                
                if shouldProcess {
                    leftChannelBuffer.removeFirst(stereoBufferSize)
                    
                    // Process left channel asynchronously
                    whisperQueue.async { [weak self] in
                        self?.processStereoChannelTranscription(
                            samples: leftSamplesForProcessing,
                            channel: "left",
                            language: self?.leftChannelLanguage ?? "en"
                        )
                    }
                    
                    debugPrint("✅ Left channel: VAD detected speech, processing", source: "SimpleAudioEngine")
                } else {
                    // Consume buffer to prevent infinite loops but don't process
                    leftChannelBuffer.removeFirst(stereoBufferSize)
                    debugPrint("🔇 Left channel: No speech detected, skipping transcription", source: "SimpleAudioEngine")
                }
            }
            
            // Process right channel when buffer is full
            if rightChannelBuffer.count >= stereoBufferSize {
                let rightSamplesForProcessing = Array(rightChannelBuffer.prefix(stereoBufferSize))
                
                // CRITICAL DEBUG: Log stereo processing attempt
                debugPrint("🎧 STEREO RIGHT: Buffer full (\(rightChannelBuffer.count) samples), starting VAD analysis", source: "SimpleAudioEngine")
                
                // CRITICAL: Apply VAD logic like mono mode (prevent hallucinations)
                let currentTime = Date()
                let vadDecision = self.performAdvancedVAD(samples: rightSamplesForProcessing)
                let speechBoundaryDetected = self.detectSpeechBoundary(vadDecision: vadDecision, currentTime: currentTime)
                let rateLimitOk = lastProcessingTime.map { 
                    currentTime.timeIntervalSince($0) >= minimumProcessingInterval 
                } ?? true
                
                let shouldProcess = rateLimitOk && (vadDecision || speechBoundaryDetected)
                
                // CRITICAL DEBUG: Log VAD decision
                debugPrint("🎧 STEREO RIGHT: VAD=\(vadDecision ? "SPEECH" : "SILENCE"), Boundary=\(speechBoundaryDetected), RateLimit=\(rateLimitOk), ShouldProcess=\(shouldProcess)", source: "SimpleAudioEngine")
                
                if shouldProcess {
                    rightChannelBuffer.removeFirst(stereoBufferSize)
                    
                    // Process right channel asynchronously
                    whisperQueue.async { [weak self] in
                        self?.processStereoChannelTranscription(
                            samples: rightSamplesForProcessing,
                            channel: "right",
                            language: self?.rightChannelLanguage ?? "es"
                        )
                    }
                    
                    debugPrint("✅ Right channel: VAD detected speech, processing", source: "SimpleAudioEngine")
                } else {
                    // Consume buffer to prevent infinite loops but don't process
                    rightChannelBuffer.removeFirst(stereoBufferSize)
                    debugPrint("🔇 Right channel: No speech detected, skipping transcription", source: "SimpleAudioEngine")
                }
            }
        }
    }
    
    // MARK: - Stereo Channel Transcription
    
    nonisolated private func processStereoChannelTranscription(samples: [Float], channel: String, language: String) {
        // Ensure we're on the whisper queue for thread safety
        dispatchPrecondition(condition: .onQueue(whisperQueue))
        
        debugPrint("🎧 Processing \(channel) channel transcription with \(samples.count) samples, language: \(language)", source: "SimpleAudioEngine")
        
        // VAD is already handled at buffer level in processStereoChannels() - no need to duplicate
        
        // Process with Whisper using channel-specific language
        if transcriptionEngine == .whisper {
            if let context = context {
                debugPrint("🎧 Calling Whisper for \(channel) channel", source: "SimpleAudioEngine")
                
                // Apply audio mode processing
                let processedSamples = applyAudioModeProcessing(to: samples)
                
                let result = whisper_bridge_transcribe_with_language(
                    context,
                    processedSamples,
                    Int32(processedSamples.count),
                    language
                )
                
                if let result = result,
                   let text = String(cString: result, encoding: .utf8),
                   !text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                    
                    // Create speaker-tagged text with dynamic names
                    let speakerName = channel == "left" ? leftSpeakerName : rightSpeakerName
                    let taggedText = "[\(speakerName)]: \(text)"
                    
                    debugPrint("✅ \(channel.capitalized) channel result: \(taggedText)", source: "SimpleAudioEngine")
                    
                    // Send to appropriate callback
                    Task { @MainActor in
                        if channel == "left" {
                            leftChannelCallback?(taggedText)
                        } else {
                            rightChannelCallback?(taggedText)
                        }
                    }
                } else {
                    debugPrint("❌ \(channel.capitalized) channel returned empty result", source: "SimpleAudioEngine")
                }
            } else {
                debugPrint("❌ Whisper context is nil for \(channel) channel", source: "SimpleAudioEngine")
            }
        }
    }
    
    nonisolated private func processTranscription(samples: [Float]) {
        // Debug: Log transcription attempt
        debugPrint("🎯 Processing transcription with \(samples.count) samples on thread: \(Thread.current)", source: "SimpleAudioEngine")
        
        // Process with Whisper
        if transcriptionEngine == .whisper {
            if let context = context {
                debugPrint("🎯 Calling Whisper with language: \(monoLanguage)", source: "SimpleAudioEngine")
                
                // CRITICAL FIX: Ensure we're on the whisper queue (single-threaded access)
                dispatchPrecondition(condition: .onQueue(whisperQueue))
                
                // v1.1.3.3 FIX: Apply audio mode processing only to confirmed speech samples
                let processedSamples = applyAudioModeProcessing(to: samples)
                
                let result = whisper_bridge_transcribe_with_language(
                    context, 
                    processedSamples, 
                    Int32(processedSamples.count), 
                    monoLanguage
                )
                
                if let result = result,
                   let text = String(cString: result, encoding: .utf8),
                   !text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                    
                    debugPrint("✅ Whisper result: \(text)", source: "SimpleAudioEngine")
                    
                    Task { @MainActor in
                        transcriptionCallback?(text)
                    }
                } else {
                    debugPrint("❌ Whisper returned empty result", source: "SimpleAudioEngine")
                }
            } else {
                debugPrint("❌ Whisper context is nil", source: "SimpleAudioEngine")
            }
        } else {
            debugPrint("❌ Whisper not enabled in transcription engine", source: "SimpleAudioEngine")
        }
        
        // Process with Apple Speech
        if transcriptionEngine == .appleSpeech {
            // Apple Speech processing would go here
            // For now, keeping Whisper as primary
        }
    }
    
    private func setupPassthrough(inputFormat: AVAudioFormat) {
        guard let audioEngine = audioEngine,
              let inputNode = inputNode,
              let outputNode = outputNode else {
            print("❌ Cannot setup passthrough - missing audio components")
            return
        }
        
        print("🔄 Setting up passthrough for audio mode: \(audioMode.rawValue)")
        
        // Clean up any existing passthrough setup
        audioEngine.disconnectNodeOutput(inputNode)
        
        do {
            if audioMode == .goobero && inputFormat.channelCount >= 2 {
                // GOOBERO MODE: Mix L+R to mono for passthrough
                print("🎧 Setting up goobero → mono passthrough mixing")
                
                // Create a mixer node to combine L+R channels
                let mixerNode = AVAudioMixerNode()
                audioEngine.attach(mixerNode)
                
                // Connect input to mixer (stereo → mixer)
                audioEngine.connect(inputNode, to: mixerNode, format: inputFormat)
                
                // Connect mixer to output (mixed → mono output)
                // The mixer will automatically mix stereo to mono
                audioEngine.connect(mixerNode, to: outputNode, format: nil)
                
                // Store mixer for recording purposes
                passthroughMixer = mixerNode
                
                print("✅ Stereo passthrough: input → mixer → output (L+R mixed to mono)")
                
            } else {
                // MONO MODE: Direct connection
                print("🔊 Setting up mono passthrough")
                audioEngine.connect(inputNode, to: outputNode, format: nil)
                
                // Clear mixer reference in mono mode
                passthroughMixer = nil
                
                print("✅ Mono passthrough: input → output (direct routing)")
            }
            
        } catch {
            print("❌ Failed to setup passthrough: \(error)")
            
            // Fallback to simple direct connection
            do {
                audioEngine.connect(inputNode, to: outputNode, format: nil)
                print("🔄 Fallback: Direct passthrough connection established")
            } catch {
                print("❌ Even fallback passthrough failed: \(error)")
            }
        }
    }
    
    
    private func routePassthroughAudio(_ buffer: AVAudioPCMBuffer) {
        // With native routing, no buffer processing needed
        // macOS handles the direct input → output routing automatically
        // This method is kept for compatibility but does nothing
        return
    }
    
    // MARK: - Audio Tap Installation
    
    private func installTapWithRetry(
        inputNode: AVAudioInputNode,
        inputFormat: AVAudioFormat,
        whisperFormat: AVAudioFormat,
        maxRetries: Int = 3
    ) async -> Bool {
        
        for attempt in 1...maxRetries {
            await DebugLogger.audio("🔄 Tap installation attempt \(attempt)/\(maxRetries)", source: "SimpleAudioEngine")
            
            // Validate audio session state before attempting tap installation
            let isValidState = await validateAudioSessionForTapInstallation()
            guard isValidState else {
                await DebugLogger.audio("⚠️ Audio session not ready for tap installation, attempt \(attempt)", source: "SimpleAudioEngine")
                
                if attempt < maxRetries {
                    await DebugLogger.audio("🕐 Waiting 300ms before retry...", source: "SimpleAudioEngine")
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                    continue
                } else {
                    await DebugLogger.error("❌ Audio session validation failed after \(maxRetries) attempts", source: "SimpleAudioEngine")
                    return false
                }
            }
            
            // Attempt to install the tap with format-specific handling
            do {
                await DebugLogger.audio("🔄 About to call inputNode.installTap on attempt \(attempt)", source: "SimpleAudioEngine")
                await DebugLogger.audio("🔍 Using format: SR=\(inputFormat.sampleRate), CH=\(inputFormat.channelCount)", source: "SimpleAudioEngine")
                
                // CRITICAL: Force flush logs before potential crash
                await DebugLogger.forceFlushLogs()
                
                // CRITICAL FIX: Use format=nil for problematic device combinations to let AVAudioEngine choose the best format
                let tapFormat: AVAudioFormat?
                if let outputDevice = selectedOutputDevice {
                    let isBuiltInMic = inputFormat.sampleRate == 44100.0
                    
                    // IMPROVED: Better Bluetooth device detection (consistent with validation logic)
                    let deviceName = outputDevice.name.lowercased()
                    let isBluetoothOutput = (deviceName.contains("airpods") || 
                                           deviceName.contains("earbuds") ||
                                           deviceName.contains("redmi") ||
                                           deviceName.contains("buds")) &&
                                           !deviceName.contains("external") && // Exclude "External Headphones"
                                           !deviceName.contains("wired") &&    // Exclude wired devices
                                           !deviceName.contains("line")        // Exclude line devices
                    
                    if isBuiltInMic && isBluetoothOutput {
                        tapFormat = nil // Let AVAudioEngine choose the format
                        await DebugLogger.audio("🔄 Using automatic format selection for Bluetooth compatibility", source: "SimpleAudioEngine")
                    } else {
                        tapFormat = inputFormat
                        await DebugLogger.audio("🔄 Using standard input format for non-Bluetooth device", source: "SimpleAudioEngine")
                    }
                } else {
                    tapFormat = inputFormat
                }
                
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { [weak self] buffer, _ in
                    Task {
                        await self?.processAudioBuffer(buffer, targetFormat: whisperFormat)
                    }
                }
                
                await DebugLogger.audio("✅ Audio tap installed successfully on attempt \(attempt)", source: "SimpleAudioEngine")
                return true
                
            } catch {
                await DebugLogger.error("❌ Tap installation failed on attempt \(attempt): \(error)", source: "SimpleAudioEngine")
                
                if attempt < maxRetries {
                    await DebugLogger.audio("🕐 Waiting 500ms before retry...", source: "SimpleAudioEngine")
                    try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
                } else {
                    await DebugLogger.error("❌ Tap installation failed after \(maxRetries) attempts", source: "SimpleAudioEngine")
                    return false
                }
            }
        }
        
        return false
    }
    
    private func validateAudioSessionForTapInstallation() async -> Bool {
        guard let audioEngine = audioEngine,
              let inputNode = inputNode else {
            await DebugLogger.error("❌ Audio engine or input node is nil", source: "SimpleAudioEngine")
            return false
        }
        
        // Check if engine is in a valid state
        if audioEngine.isRunning {
            await DebugLogger.audio("⚠️ Audio engine is running - stopping before validation", source: "SimpleAudioEngine")
            audioEngine.stop()
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms to settle
        }
        
        // Get current input format
        let inputFormat = inputNode.outputFormat(forBus: 0)
        await DebugLogger.audio("🔍 Input format: SR=\(inputFormat.sampleRate), CH=\(inputFormat.channelCount), PCM=\(inputFormat.commonFormat.rawValue)", source: "SimpleAudioEngine")
        
        guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
            await DebugLogger.error("❌ Invalid input format: \(inputFormat)", source: "SimpleAudioEngine")
            return false
        }
        
        // CRITICAL FIX: Check for device format compatibility
        if let outputDevice = selectedOutputDevice {
            await DebugLogger.audio("🔍 Checking compatibility: input vs output device '\(outputDevice.name)'", source: "SimpleAudioEngine")
            
            // Detect problematic combinations: Built-in mic + Bluetooth output
            let isBuiltInMic = inputFormat.sampleRate == 44100.0 // MacBook built-in mic uses 44.1kHz
            
            // IMPROVED: Better Bluetooth device detection
            let deviceName = outputDevice.name.lowercased()
            let isBluetoothOutput = (deviceName.contains("airpods") || 
                                   deviceName.contains("earbuds") ||
                                   deviceName.contains("redmi") ||
                                   deviceName.contains("buds")) &&
                                   !deviceName.contains("external") && // Exclude "External Headphones"
                                   !deviceName.contains("wired") &&    // Exclude wired devices
                                   !deviceName.contains("line")        // Exclude line devices
            
            await DebugLogger.audio("🔍 Device analysis: isBuiltInMic=\(isBuiltInMic), isBluetoothOutput=\(isBluetoothOutput)", source: "SimpleAudioEngine")
            
            if isBuiltInMic && isBluetoothOutput {
                await DebugLogger.audio("⚠️ DETECTED: Built-in mic (48kHz) + Bluetooth output combination", source: "SimpleAudioEngine")
                
                // This combination requires format adaptation
                await DebugLogger.audio("🔄 Applying format compatibility workaround...", source: "SimpleAudioEngine")
                
                // Force a brief engine restart to reset internal state
                audioEngine.stop()
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms settle time
                
                // Let the system reconfigure the audio session
                do {
                    try audioEngine.start()
                    audioEngine.stop()
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                } catch {
                    await DebugLogger.error("❌ Engine restart failed during compatibility check: \(error)", source: "SimpleAudioEngine")
                    return false
                }
            }
        }
        
        // Check if there are any existing taps
        inputNode.removeTap(onBus: 0) // Safe cleanup of any existing taps
        
        await DebugLogger.audio("✅ Audio session validation passed", source: "SimpleAudioEngine")
        return true
    }
    
    // MARK: - Device Change Handling
    
    private func reinitializeAudioEngine() async {
        await DebugLogger.audio("🔄 Reinitializing audio engine for device change", source: "SimpleAudioEngine")
        
        // Ensure complete cleanup first
        await ensureCleanEngineState()
        
        // Create new audio engine instance
        audioEngine = nil
        inputNode = nil
        outputNode = nil
        audioConverter = nil
        
        // Wait for system to settle
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Reinitialize engine components
        audioEngine = AVAudioEngine()
        
        guard let audioEngine = audioEngine else {
            await DebugLogger.error("❌ Failed to create new audio engine", source: "SimpleAudioEngine")
            return
        }
        
        inputNode = audioEngine.inputNode
        outputNode = audioEngine.outputNode
        
        await DebugLogger.audio("✅ Audio engine reinitialized successfully", source: "SimpleAudioEngine")
    }
    
    deinit {
        // CRITICAL FIX: Thread-safe cleanup in deinit
        // Note: Can't use async/await in deinit, so using synchronous approach
        if let context = context {
            whisperQueue.sync {
                whisper_bridge_free_context(context)
            }
        }
        
        // Clean up audio engine synchronously
        if let inputNode = inputNode {
            inputNode.removeTap(onBus: 0)
        }
        
        audioEngine?.stop()
        audioEngine?.reset()
        
        print("🧹 SimpleAudioEngine: Cleaned up in deinit")
    }
    
    
    func setPassthroughVolume(_ volume: Double) async {
        passthroughVolume = Float(max(0.0, min(1.0, volume)))
        
        // Apply volume to passthrough pipeline if currently active
        if passthroughEnabled {
            if let mixer = passthroughMixer {
                // Goobero mode: control mixer volume
                mixer.volume = passthroughVolume
                print("🔊 Applied passthrough volume to mixer: \(Int(passthroughVolume * 100))%")
            } else if let inputNode = inputNode {
                // Mono mode: control input volume (affects passthrough)
                inputNode.volume = passthroughVolume
                print("🔊 Applied passthrough volume to input: \(Int(passthroughVolume * 100))%")
            }
        }
    }
    
    // MARK: - Audio Recording to File (Stub implementations)
    
    func setAudioRecordingEnabled(_ enabled: Bool) async {
        // Stub - audio file recording removed
        print("🔇 Audio file recording is disabled")
    }
    
    func startAudioRecording() async -> URL? {
        // Stub - audio file recording removed
        print("🔇 Audio file recording is disabled")
        return nil
    }
    
    func stopAudioRecording() async {
        // Stub - audio file recording removed
        print("🔇 Audio file recording is disabled")
    }
}
