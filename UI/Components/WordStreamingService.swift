import Foundation
import SwiftUI

/**
 * @brief WordStreamingService - Progressive Text Display for Natural UX
 * 
 * Converts complete transcription text into progressive word-by-word display
 * to make Prezefren feel more "snappy" and natural. Instead of showing complete
 * text chunks instantly, words appear progressively at configurable intervals.
 * 
 * Ported from Lenguan2 implementation for buttery smooth animations.
 * 
 * Key Features:
 * - Configurable word display timing (default: 150ms per word)
 * - Immediate mode for instant display (settings option)
 * - Word boundary detection and natural spacing
 * - Cancellable streaming for new transcriptions
 * - Thread-safe operations with MainActor integration
 */

// MARK: - Streaming State

enum WordStreamingState: Equatable {
    case idle
    case streaming(progress: Double)  // 0.0 to 1.0
    case completed
    
    static func == (lhs: WordStreamingState, rhs: WordStreamingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.completed, .completed):
            return true
        case (.streaming(let lhsProgress), .streaming(let rhsProgress)):
            return lhsProgress == rhsProgress
        default:
            return false
        }
    }
}

// MARK: - Configuration

struct WordStreamingConfig {
    let wordsPerSecond: Double       // Default: ~6-7 words per second (natural speech rate)
    let immediateMode: Bool          // Skip animation, show instantly
    let punctuationPause: Double     // Extra pause after punctuation (milliseconds)
    
    static let `default` = WordStreamingConfig(
        wordsPerSecond: 16.0,        // ~63ms per word (AssemblyAI-like smoothness)
        immediateMode: false,
        punctuationPause: 50         // Reduced pause for smoother flow
    )
    
    static let fast = WordStreamingConfig(
        wordsPerSecond: 20.0,        // ~50ms per word (match AssemblyAI frequency)
        immediateMode: false,
        punctuationPause: 25
    )
    
    static let slow = WordStreamingConfig(
        wordsPerSecond: 6.5,         // ~154ms per word (original natural reading pace)
        immediateMode: false,
        punctuationPause: 100
    )
    
    static let instant = WordStreamingConfig(
        wordsPerSecond: 100.0,       // Effectively instant
        immediateMode: true,
        punctuationPause: 0
    )
    
    var millisecondsPerWord: Int {
        Int((1000.0 / wordsPerSecond))
    }
}

// MARK: - Progressive Text Data

struct ProgressiveText {
    let completeText: String
    let displayedText: String
    let currentWordIndex: Int
    let totalWords: Int
    let isComplete: Bool
    let streamingState: WordStreamingState
    
    var progress: Double {
        guard totalWords > 0 else { return 1.0 }
        return Double(currentWordIndex) / Double(totalWords)
    }
}

// MARK: - Word Streaming Service

@MainActor
class WordStreamingService: ObservableObject {
    
    // MARK: - Published State
    
    @Published var currentText: ProgressiveText = ProgressiveText(
        completeText: "",
        displayedText: "",
        currentWordIndex: 0,
        totalWords: 0,
        isComplete: true,
        streamingState: .idle
    )
    
    @Published var config: WordStreamingConfig = .default
    
    // MARK: - Private State
    
    private var streamingTask: Task<Void, Never>?
    private var words: [String] = []
    private let streamingQueue = DispatchQueue(label: "WordStreamingService", qos: .userInitiated)
    
    // MARK: - Public Interface
    
    /**
     * @brief Start progressive display of text
     * Cancels any existing streaming and begins new word-by-word display
     */
    func streamText(_ text: String) {
        // Cancel any existing streaming
        cancelCurrentStreaming()
        
        // Handle empty text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            updateToEmptyState()
            return
        }
        
        // Immediate mode: show everything instantly
        if config.immediateMode {
            updateToCompleteState(text)
            return
        }
        
        // Prepare for progressive display
        words = tokenizeText(text)
        updateToStartingState(text, totalWords: words.count)
        
        // Start progressive streaming
        startProgressiveDisplay()
    }
    
    /**
     * @brief Update configuration and apply to current streaming
     */
    func updateConfig(_ newConfig: WordStreamingConfig) {
        config = newConfig
        
        // If switching to immediate mode and currently streaming, complete instantly
        if newConfig.immediateMode && currentText.streamingState == .streaming(progress: currentText.progress) {
            updateToCompleteState(currentText.completeText)
            cancelCurrentStreaming()
        }
    }
    
    /**
     * @brief Force complete current streaming immediately
     */
    func completeCurrentStreaming() {
        cancelCurrentStreaming()
        updateToCompleteState(currentText.completeText)
    }
    
    /**
     * @brief Cancel current streaming and reset to idle
     */
    func cancelCurrentStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
    }
    
    // MARK: - Private Implementation
    
    private func tokenizeText(_ text: String) -> [String] {
        // Split by whitespace while preserving word boundaries
        return text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }
    
    private func updateToEmptyState() {
        currentText = ProgressiveText(
            completeText: "",
            displayedText: "",
            currentWordIndex: 0,
            totalWords: 0,
            isComplete: true,
            streamingState: .idle
        )
    }
    
    private func updateToCompleteState(_ text: String) {
        let wordCount = tokenizeText(text).count
        currentText = ProgressiveText(
            completeText: text,
            displayedText: text,
            currentWordIndex: wordCount,
            totalWords: wordCount,
            isComplete: true,
            streamingState: .completed
        )
    }
    
    private func updateToStartingState(_ text: String, totalWords: Int) {
        currentText = ProgressiveText(
            completeText: text,
            displayedText: "",
            currentWordIndex: 0,
            totalWords: totalWords,
            isComplete: false,
            streamingState: .streaming(progress: 0.0)
        )
    }
    
    private func startProgressiveDisplay() {
        streamingTask = Task { @MainActor in
            var displayedWords: [String] = []
            
            for (index, word) in words.enumerated() {
                // Check for cancellation
                if Task.isCancelled {
                    return
                }
                
                // Add word to display
                displayedWords.append(word)
                let newDisplayText = displayedWords.joined(separator: " ")
                let progress = Double(index + 1) / Double(words.count)
                
                // Update state
                currentText = ProgressiveText(
                    completeText: currentText.completeText,
                    displayedText: newDisplayText,
                    currentWordIndex: index + 1,
                    totalWords: words.count,
                    isComplete: index + 1 == words.count,
                    streamingState: index + 1 == words.count ? .completed : .streaming(progress: progress)
                )
                
                // Don't pause after the last word
                if index < words.count - 1 {
                    let baseDelay = config.millisecondsPerWord
                    let punctuationDelay = hasPunctuation(word) ? Int(config.punctuationPause) : 0
                    let totalDelay = baseDelay + punctuationDelay
                    
                    // Use DispatchQueue for macOS 11.0+ compatibility
                    await withCheckedContinuation { continuation in
                        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(totalDelay)) {
                            continuation.resume()
                        }
                    }
                }
            }
            
            // Mark as completed
            currentText = ProgressiveText(
                completeText: currentText.completeText,
                displayedText: currentText.completeText,
                currentWordIndex: words.count,
                totalWords: words.count,
                isComplete: true,
                streamingState: .completed
            )
        }
    }
    
    private func hasPunctuation(_ word: String) -> Bool {
        let punctuationSet = CharacterSet(charactersIn: ".!?;:")
        return word.rangeOfCharacter(from: punctuationSet) != nil
    }
}

// MARK: - Convenience Extensions

extension WordStreamingService {
    
    /**
     * @brief Get current display text (convenience property)
     */
    var displayText: String {
        currentText.displayedText
    }
    
    /**
     * @brief Check if currently streaming
     */
    var isStreaming: Bool {
        if case .streaming = currentText.streamingState {
            return true
        }
        return false
    }
    
    /**
     * @brief Get streaming progress (0.0 to 1.0)
     */
    var streamingProgress: Double {
        currentText.progress
    }
}