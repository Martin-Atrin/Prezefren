import Foundation
import SwiftUI

enum WindowTemplate: String, CaseIterable, Codable {
    case topBanner = "Top Banner"
    case sidePanel = "Side Panel"
    case pictureInPicture = "Picture-in-Picture"
    case centerStage = "Center Stage"
    case custom = "Custom"
    
    var displayName: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .topBanner: return "rectangle.topthird.inset.filled"
        case .sidePanel: return "sidebar.left"
        case .pictureInPicture: return "pip"
        case .centerStage: return "rectangle.center.inset.filled"
        case .custom: return "gear"
        }
    }
    
    var description: String {
        switch self {
        case .topBanner: return "Full-width banner across top of screen"
        case .sidePanel: return "Tall narrow panel on screen edge"
        case .pictureInPicture: return "Small corner window, minimal distraction"
        case .centerStage: return "Large centered window for presentations"
        case .custom: return "User-defined size and position"
        }
    }
    
    func defaultFrame(for screenSize: CGSize) -> CGRect {
        let screenWidth = screenSize.width
        let screenHeight = screenSize.height
        
        switch self {
        case .topBanner:
            return CGRect(
                x: 0,
                y: screenHeight - 120,
                width: screenWidth,
                height: 100
            )
            
        case .sidePanel:
            return CGRect(
                x: 50,
                y: screenHeight * 0.3,
                width: 300,
                height: screenHeight * 0.4
            )
            
        case .pictureInPicture:
            return CGRect(
                x: screenWidth - 320,
                y: screenHeight - 200,
                width: 300,
                height: 150
            )
            
        case .centerStage:
            return CGRect(
                x: screenWidth * 0.25,
                y: screenHeight * 0.4,
                width: screenWidth * 0.5,
                height: screenHeight * 0.2
            )
            
        case .custom:
            // Default custom size - user can adjust
            return CGRect(
                x: screenWidth * 0.3,
                y: screenHeight * 0.6,
                width: 400,
                height: 200
            )
        }
    }
    
    var defaultOpacity: Double {
        switch self {
        case .topBanner: return 0.9
        case .sidePanel: return 0.85
        case .pictureInPicture: return 0.8
        case .centerStage: return 0.95
        case .custom: return 0.85
        }
    }
    
    var defaultFontSize: CGFloat {
        switch self {
        case .topBanner: return 24
        case .sidePanel: return 16
        case .pictureInPicture: return 14
        case .centerStage: return 28
        case .custom: return 18
        }
    }
}

struct WindowConfiguration: Codable, Identifiable {
    let id: UUID
    var template: WindowTemplate
    var position: CGPoint
    var size: CGSize
    var opacity: Double
    var fontFamily: String
    var fontSize: CGFloat
    var textColor: CodableColor
    var backgroundColor: CodableColor
    var isVisible: Bool
    var name: String
    
    init(template: WindowTemplate, screenSize: CGSize, name: String = "") {
        self.id = UUID()
        self.template = template
        let defaultFrame = template.defaultFrame(for: screenSize)
        self.position = defaultFrame.origin
        self.size = defaultFrame.size
        self.opacity = template.defaultOpacity
        self.fontFamily = "SF Pro Display"
        self.fontSize = template.defaultFontSize
        self.textColor = CodableColor(.white)
        self.backgroundColor = CodableColor(.black.opacity(0.8))
        self.isVisible = false
        self.name = name.isEmpty ? template.displayName : name
    }
    
    var frame: CGRect {
        return CGRect(origin: position, size: size)
    }
}

// Helper struct to make Color Codable
struct CodableColor: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    
    init(_ color: Color) {
        // Extract RGBA components from Color
        // Note: This is a simplified approach - in production you might want more robust color extraction
        if #available(macOS 14.0, *) {
            let resolved = color.resolve(in: EnvironmentValues())
            self.red = Double(resolved.red)
            self.green = Double(resolved.green)
            self.blue = Double(resolved.blue)
            self.alpha = Double(resolved.opacity)
        } else {
            // Fallback for older macOS versions
            self.red = 1.0
            self.green = 1.0
            self.blue = 1.0
            self.alpha = 1.0
        }
    }
    
    var color: Color {
        return Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}