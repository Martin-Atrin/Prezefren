import SwiftUI
import Foundation

/**
 * @brief ProgressiveTextView - Word-by-word display component
 * 
 * A SwiftUI view that takes a complete text string and displays it progressively
 * word by word for a natural, engaging reading experience. This is a pure
 * presentation layer component that doesn't modify the data pipeline.
 * 
 * Ported from Lenguan2 implementation for buttery smooth animations.
 * 
 * Key Features:
 * - Takes complete text and displays it progressively
 * - Configurable timing and punctuation pauses
 * - Instant mode support for users who prefer immediate display
 * - Automatic restart when text changes
 * - Clean separation from data pipeline
 */

struct ProgressiveTextView: View {
    let fullText: String
    let config: WordStreamingConfig
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let textColor: Color
    let alignment: TextAlignment
    
    @State private var displayedText: String = ""
    @State private var animationTask: Task<Void, Never>?
    @State private var words: [String] = []
    @State private var currentWordIndex: Int = 0
    
    init(
        fullText: String,
        config: WordStreamingConfig = .default,
        fontSize: CGFloat = 16,
        fontWeight: Font.Weight = .regular,
        textColor: Color = .primary,
        alignment: TextAlignment = .leading
    ) {
        self.fullText = fullText
        self.config = config
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.textColor = textColor
        self.alignment = alignment
    }
    
    var body: some View {
        Text(displayedText)
            .font(.system(size: fontSize, weight: fontWeight))
            .foregroundColor(textColor)
            .multilineTextAlignment(alignment)
            .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : alignment == .trailing ? .trailing : .center)
            .scaleEffect(displayedText.isEmpty ? 0.95 : 1.0)
            .opacity(displayedText.isEmpty ? 0.0 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.05), value: displayedText)
            .onAppear {
                startProgressiveDisplay()
            }
            .onChange(of: fullText) { newText in
                startProgressiveDisplay()
            }
            .onChange(of: config.immediateMode) { immediate in
                if immediate {
                    showFullTextImmediately()
                } else {
                    startProgressiveDisplay()
                }
            }
            .onDisappear {
                stopAnimation()
            }
    }
    
    // MARK: - Private Methods
    
    private func startProgressiveDisplay() {
        // Cancel any existing animation
        stopAnimation()
        
        // Handle empty text
        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            displayedText = ""
            return
        }
        
        // Immediate mode: show everything instantly
        if config.immediateMode {
            showFullTextImmediately()
            return
        }
        
        // Prepare for progressive display
        words = tokenizeText(fullText)
        currentWordIndex = 0
        displayedText = ""
        
        // Start progressive animation
        animationTask = Task { @MainActor in
            var displayedWords: [String] = []
            
            for (index, word) in words.enumerated() {
                // Check for cancellation
                if Task.isCancelled {
                    return
                }
                
                // Add word to display
                displayedWords.append(word)
                displayedText = displayedWords.joined(separator: " ")
                currentWordIndex = index + 1
                
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
            
            // Animation complete
            displayedText = fullText
        }
    }
    
    private func showFullTextImmediately() {
        stopAnimation()
        displayedText = fullText
        words = tokenizeText(fullText)
        currentWordIndex = words.count
    }
    
    private func stopAnimation() {
        animationTask?.cancel()
        animationTask = nil
    }
    
    private func tokenizeText(_ text: String) -> [String] {
        return text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }
    
    private func hasPunctuation(_ word: String) -> Bool {
        let punctuationSet = CharacterSet(charactersIn: ".!?;:")
        return word.rangeOfCharacter(from: punctuationSet) != nil
    }
}

// MARK: - Note: Convenience initializers removed
// All components now use the main initializer directly with proper WordStreamingConfig
// This eliminates parameter confusion and ensures consistent configuration

// MARK: - Preview

struct ProgressiveTextView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Normal Mode:")
                .font(.headline)
            
            ProgressiveTextView(
                fullText: "This is a test of progressive text display. It should show word by word with natural timing.",
                config: WordStreamingConfig.default
            )
            .font(.title2)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            
            Text("Fast Mode:")
                .font(.headline)
            
            ProgressiveTextView(
                fullText: "This text should appear faster with quick timing for rapid readers.",
                config: WordStreamingConfig.fast
            )
            .font(.title2)
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
            
            Text("Instant Mode:")
                .font(.headline)
            
            ProgressiveTextView(
                fullText: "This text should appear immediately without any animation delay.",
                config: WordStreamingConfig.instant
            )
            .font(.title2)
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            
            Text("Subtitle Mode (White Text, Center Aligned):")
                .font(.headline)
            
            ProgressiveTextView(
                fullText: "This mimics the floating subtitle window appearance with centered white text.",
                config: .default,
                fontSize: 24,
                fontWeight: .medium,
                textColor: .white,
                alignment: .center
            )
            .padding()
            .background(Color.black.opacity(0.8))
            .cornerRadius(8)
        }
        .padding()
    }
}