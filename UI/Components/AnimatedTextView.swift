import SwiftUI

/**
 * AnimatedTextView - Superior implementation from assembly version
 * 
 * Features:
 * - Simple, reliable text display with smooth spring animations
 * - Proper center alignment for simple mode
 * - No justification issues or line wrapping problems
 * - Enabled by default for smooth user experience
 */

struct AnimatedTextView: View {
    let text: String
    let fontSize: CGFloat
    let animationEnabled: Bool
    
    init(text: String, fontSize: CGFloat = 18, animationEnabled: Bool = true) {
        self.text = text
        self.fontSize = fontSize
        self.animationEnabled = animationEnabled
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            Text(text)
                .foregroundColor(.white)
                .fontWeight(.medium)
                .font(.system(size: fontSize))
                .multilineTextAlignment(.center)  // CENTER ALIGNED - prevents justification issues
                .padding()
                .scaleEffect(text.isEmpty ? 0.9 : 1.0)
                .opacity(text.isEmpty ? 0.0 : 1.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.1), value: text)
            
            Spacer(minLength: 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped() // Ensures text stays within bounds
    }
}

// MARK: - Preview Support

struct AnimatedTextView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Test with long text to check wrapping
            AnimatedTextView(
                text: "This is a long sentence that should wrap properly without justification issues in the center alignment",
                fontSize: 18,
                animationEnabled: true
            )
            .frame(width: 400, height: 150)
            .background(Color.black.opacity(0.8))
            
            // Test with short text
            AnimatedTextView(
                text: "Short text",
                fontSize: 18,
                animationEnabled: true
            )
            .frame(width: 400, height: 100)
            .background(Color.black.opacity(0.8))
        }
        .padding()
        .background(Color.gray)
    }
}