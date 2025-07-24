import SwiftUI

// MARK: - Prezefren Design System
// Based on Shadcn/Gluestack aesthetic with 5px corners and clean minimal design

// MARK: - Color Palette
extension Color {
    // Core colors from website
    static let prezefrenPrimary = Color(hex: "03a9f4")
    static let prezefrenPrimaryForeground = Color.white
    static let prezefrenSecondary = Color(hex: "1e293b")
    static let prezefrenSecondaryForeground = Color(hex: "f8fafc")
    static let prezefrenAccent = Color(hex: "00d4aa")
    static let prezefrenAccentForeground = Color.white
    
    // Neutral palette
    static let prezefrenBackground = Color(hex: "0a0a0a")
    static let prezefrenForeground = Color(hex: "fafafa")
    static let prezefrenCard = Color(hex: "18181b")
    static let prezefrenCardForeground = Color(hex: "fafafa")
    static let prezefrenPopover = Color(hex: "18181b")
    static let prezefrenPopoverForeground = Color(hex: "fafafa")
    
    // UI elements
    static let prezefrenMuted = Color(hex: "27272a")
    static let prezefrenMutedForeground = Color(hex: "a1a1aa")
    static let prezefrenBorder = Color(hex: "27272a")
    static let prezefrenInput = Color(hex: "27272a")
    static let prezefrenRing = Color(hex: "03a9f4")
    
    // Status colors
    static let prezefrenSuccess = Color(hex: "00d4aa")
    static let prezefrenWarning = Color(hex: "f59e0b")
    static let prezefrenError = Color(hex: "ef4444")
    
    // Hex initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Design Constants
struct PrezefrenDesign {
    // Border radius
    static let radiusSmall: CGFloat = 5
    static let radiusMedium: CGFloat = 8
    static let radiusLarge: CGFloat = 12
    
    // Spacing
    static let spacing2: CGFloat = 8
    static let spacing3: CGFloat = 12
    static let spacing4: CGFloat = 16
    static let spacing6: CGFloat = 24
    static let spacing8: CGFloat = 32
    
    // Typography
    static let fontSizeXS: CGFloat = 11
    static let fontSizeSM: CGFloat = 13
    static let fontSizeMD: CGFloat = 14
    static let fontSizeLG: CGFloat = 16
    static let fontSizeXL: CGFloat = 18
    static let fontSize2XL: CGFloat = 24
    
    // Border width
    static let borderWidth: CGFloat = 1
    
    // Button heights
    static let buttonHeightSM: CGFloat = 32
    static let buttonHeightMD: CGFloat = 36
    static let buttonHeightLG: CGFloat = 44
}

// MARK: - View Modifiers

// Background modifier
struct PrezefrenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.prezefrenBackground)
    }
}

// Card modifier
struct PrezefrenCard: ViewModifier {
    var padding: CGFloat = PrezefrenDesign.spacing6
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.prezefrenCard)
            .overlay(
                RoundedRectangle(cornerRadius: PrezefrenDesign.radiusMedium)
                    .stroke(Color.prezefrenBorder, lineWidth: PrezefrenDesign.borderWidth)
            )
            .cornerRadius(PrezefrenDesign.radiusMedium)
    }
}

// MARK: - Button Styles

struct PrezefrenPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: PrezefrenDesign.fontSizeMD, weight: .medium))
            .foregroundColor(.prezefrenPrimaryForeground)
            .padding(.horizontal, PrezefrenDesign.spacing4)
            .padding(.vertical, PrezefrenDesign.spacing2)
            .frame(minHeight: PrezefrenDesign.buttonHeightMD)
            .background(configuration.isPressed ? Color.prezefrenPrimary.opacity(0.9) : Color.prezefrenPrimary)
            .cornerRadius(PrezefrenDesign.radiusSmall)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct PrezefrenSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: PrezefrenDesign.fontSizeMD, weight: .medium))
            .foregroundColor(.prezefrenSecondaryForeground)
            .padding(.horizontal, PrezefrenDesign.spacing4)
            .padding(.vertical, PrezefrenDesign.spacing2)
            .frame(minHeight: PrezefrenDesign.buttonHeightMD)
            .background(configuration.isPressed ? Color.prezefrenSecondary.opacity(0.9) : Color.prezefrenSecondary)
            .cornerRadius(PrezefrenDesign.radiusSmall)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct PrezefrenOutlineButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: PrezefrenDesign.fontSizeMD, weight: .medium))
            .foregroundColor(.prezefrenForeground)
            .padding(.horizontal, PrezefrenDesign.spacing4)
            .padding(.vertical, PrezefrenDesign.spacing2)
            .frame(minHeight: PrezefrenDesign.buttonHeightMD)
            .background(configuration.isPressed ? Color.prezefrenMuted : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: PrezefrenDesign.radiusSmall)
                    .stroke(Color.prezefrenBorder, lineWidth: PrezefrenDesign.borderWidth)
            )
            .cornerRadius(PrezefrenDesign.radiusSmall)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct PrezefrenGhostButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: PrezefrenDesign.fontSizeSM, weight: .medium))
            .foregroundColor(.prezefrenMutedForeground)
            .padding(.horizontal, PrezefrenDesign.spacing3)
            .padding(.vertical, 6)
            .background(configuration.isPressed ? Color.prezefrenMuted : Color.clear)
            .cornerRadius(PrezefrenDesign.radiusSmall)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

// Recording button (special case)
struct PrezefrenRecordButton: ViewModifier {
    let isRecording: Bool
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: PrezefrenDesign.fontSizeLG, weight: .semibold))
            .foregroundColor(.white)
            .padding(.vertical, PrezefrenDesign.spacing4)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: PrezefrenDesign.radiusSmall)
                    .fill(Color.black.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: PrezefrenDesign.radiusSmall)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        (isRecording ? Color.prezefrenError : Color.prezefrenPrimary).opacity(0.6),
                                        (isRecording ? Color.prezefrenError : Color.prezefrenPrimary).opacity(0.1)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: (isRecording ? Color.prezefrenError : Color.prezefrenPrimary).opacity(0.3), radius: 5, x: 0, y: 0)
            )
    }
}

// MARK: - Text Styles

struct PrezefrenHeading: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: PrezefrenDesign.fontSizeLG, weight: .semibold))
            .foregroundColor(.prezefrenForeground)
    }
}

struct PrezefrenLabel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: PrezefrenDesign.fontSizeXS, weight: .medium))
            .foregroundColor(.prezefrenMutedForeground)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

struct PrezefrenCaption: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: PrezefrenDesign.fontSizeSM))
            .foregroundColor(.prezefrenMutedForeground)
    }
}

// MARK: - Input Styles

struct PrezefrenInput: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, PrezefrenDesign.spacing3)
            .padding(.vertical, PrezefrenDesign.spacing2)
            .background(Color.prezefrenInput)
            .overlay(
                RoundedRectangle(cornerRadius: PrezefrenDesign.radiusSmall)
                    .stroke(Color.prezefrenBorder, lineWidth: PrezefrenDesign.borderWidth)
            )
            .cornerRadius(PrezefrenDesign.radiusSmall)
    }
}

// Transcription area modifier
struct PrezefrenTranscriptionArea: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(PrezefrenDesign.spacing3)
            .frame(minHeight: 80)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.prezefrenMuted)
            .overlay(
                RoundedRectangle(cornerRadius: PrezefrenDesign.radiusSmall)
                    .stroke(Color.prezefrenBorder, lineWidth: PrezefrenDesign.borderWidth)
            )
            .cornerRadius(PrezefrenDesign.radiusSmall)
            .font(.system(size: PrezefrenDesign.fontSizeSM, design: .monospaced))
    }
}

// MARK: - Badge Styles

struct PrezefrenBadge: ViewModifier {
    var color: Color = .prezefrenMuted
    var textColor: Color = .prezefrenMutedForeground
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: PrezefrenDesign.fontSizeXS, weight: .medium))
            .foregroundColor(textColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .cornerRadius(PrezefrenDesign.radiusSmall)
    }
}

// MARK: - Toggle Style

struct PrezefrenToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .foregroundColor(.prezefrenForeground)
            
            Spacer()
            
            RoundedRectangle(cornerRadius: 12)
                .fill(configuration.isOn ? Color.prezefrenPrimary : Color.prezefrenMuted)
                .frame(width: 44, height: 24)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                        .offset(x: configuration.isOn ? 10 : -10)
                        .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
                )
                .onTapGesture {
                    configuration.isOn.toggle()
                }
        }
    }
}

// MARK: - Status Dot

struct PrezefrenStatusDot: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .frame(width: 6, height: 6)
            .background(isActive ? Color.prezefrenSuccess : Color.prezefrenMuted)
            .clipShape(Circle())
    }
}

// MARK: - Window Item Style

struct PrezefrenWindowItem: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(PrezefrenDesign.spacing4)
            .background(Color.prezefrenMuted)
            .overlay(
                RoundedRectangle(cornerRadius: PrezefrenDesign.radiusSmall)
                    .stroke(Color.prezefrenBorder, lineWidth: PrezefrenDesign.borderWidth)
            )
            .cornerRadius(PrezefrenDesign.radiusSmall)
    }
}

// MARK: - Configuration Row

struct PrezefrenConfigRow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(PrezefrenDesign.spacing3)
            .background(Color.prezefrenMuted)
            .cornerRadius(PrezefrenDesign.radiusSmall)
    }
}

// MARK: - ModernCard (Compatibility Wrapper)

struct ModernCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .prezefrenCard()
    }
}

// MARK: - View Extension for Easy Access

extension View {
    func prezefrenBackground() -> some View {
        modifier(PrezefrenBackground())
    }
    
    func prezefrenCard(padding: CGFloat = PrezefrenDesign.spacing6) -> some View {
        modifier(PrezefrenCard(padding: padding))
    }
    
    func prezefrenPrimaryButton() -> some View {
        buttonStyle(PrezefrenPrimaryButton())
    }
    
    func prezefrenSecondaryButton() -> some View {
        buttonStyle(PrezefrenSecondaryButton())
    }
    
    func prezefrenOutlineButton() -> some View {
        buttonStyle(PrezefrenOutlineButton())
    }
    
    func prezefrenGhostButton() -> some View {
        buttonStyle(PrezefrenGhostButton())
    }
    
    func prezefrenRecordButton(isRecording: Bool) -> some View {
        modifier(PrezefrenRecordButton(isRecording: isRecording))
    }
    
    func prezefrenHeading() -> some View {
        modifier(PrezefrenHeading())
    }
    
    func prezefrenLabel() -> some View {
        modifier(PrezefrenLabel())
    }
    
    func prezefrenCaption() -> some View {
        modifier(PrezefrenCaption())
    }
    
    func prezefrenInput() -> some View {
        modifier(PrezefrenInput())
    }
    
    func prezefrenTranscriptionArea() -> some View {
        modifier(PrezefrenTranscriptionArea())
    }
    
    func prezefrenBadge(color: Color = .prezefrenMuted, textColor: Color = .prezefrenMutedForeground) -> some View {
        modifier(PrezefrenBadge(color: color, textColor: textColor))
    }
    
    func prezefrenStatusDot(isActive: Bool) -> some View {
        modifier(PrezefrenStatusDot(isActive: isActive))
    }
    
    func prezefrenWindowItem() -> some View {
        modifier(PrezefrenWindowItem())
    }
    
    func prezefrenConfigRow() -> some View {
        modifier(PrezefrenConfigRow())
    }
}


// MARK: - Empty State Text Style
extension Text {
    func emptyStateStyle() -> some View {
        self
            .foregroundColor(.prezefrenMutedForeground)
            .italic()
            .font(.system(size: PrezefrenDesign.fontSizeSM))
    }
}

// MARK: - Picker Style
struct PrezefrenPickerStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, PrezefrenDesign.spacing3)
            .padding(.vertical, PrezefrenDesign.spacing2)
            .background(Color.prezefrenInput)
            .overlay(
                RoundedRectangle(cornerRadius: PrezefrenDesign.radiusSmall)
                    .stroke(Color.prezefrenBorder, lineWidth: PrezefrenDesign.borderWidth)
            )
            .cornerRadius(PrezefrenDesign.radiusSmall)
            .foregroundColor(.prezefrenForeground)
    }
}

extension View {
    func prezefrenPicker() -> some View {
        modifier(PrezefrenPickerStyle())
    }
}

// MARK: - Tab Style
struct PrezefrenTab: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, PrezefrenDesign.spacing4)
            .padding(.vertical, PrezefrenDesign.spacing2)
            .background(isActive ? Color.prezefrenCard : Color.clear)
            .foregroundColor(isActive ? .prezefrenForeground : .prezefrenMutedForeground)
            .cornerRadius(PrezefrenDesign.radiusSmall)
            .font(.system(size: PrezefrenDesign.fontSizeMD, weight: .medium))
    }
}

extension View {
    func prezefrenTab(isActive: Bool) -> some View {
        modifier(PrezefrenTab(isActive: isActive))
    }
}