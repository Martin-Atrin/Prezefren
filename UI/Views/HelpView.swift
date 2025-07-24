import SwiftUI

struct HelpView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedSection = 0
    
    private let helpSections: [(String, AnyView)] = [
        ("Quick Start", AnyView(quickStartContent)),
        ("Windows", AnyView(windowsContent)),
        ("Audio", AnyView(audioContent)),
        ("Translation", AnyView(translationContent)),
        ("Troubleshooting", AnyView(troubleshootingContent))
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Prezefren Help")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Real-time voice transcription & translation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Content
                HStack(spacing: 0) {
                    // Sidebar
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(0..<helpSections.count, id: \.self) { index in
                            Button(action: {
                                selectedSection = index
                            }) {
                                HStack {
                                    Text(helpSections[index].0)
                                        .font(.subheadline)
                                        .foregroundColor(selectedSection == index ? .white : .primary)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(selectedSection == index ? Color.blue : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Spacer()
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Quick links
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Resources")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                            
                            Button("GitHub Repository") {
                                NSWorkspace.shared.open(URL(string: "https://github.com/Martin-Atrin/Prezefren")!)
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            
                            Button("Report Issue") {
                                NSWorkspace.shared.open(URL(string: "https://github.com/Martin-Atrin/Prezefren/issues")!)
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                        }
                    }
                    .frame(width: 180)
                    .padding(.vertical)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    // Main content
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(helpSections[selectedSection].0)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            helpSections[selectedSection].1
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .frame(width: 800, height: 600)
    }
}

// MARK: - Help Content

private var quickStartContent: some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("Get started with Prezefren in 3 easy steps:")
            .font(.headline)
        
        VStack(alignment: .leading, spacing: 8) {
            HelpStep(number: 1, title: "Start Recording", description: "Click the microphone button in the Audio tab and start speaking")
            HelpStep(number: 2, title: "Add Windows", description: "Go to Windows tab, click 'Add Window', and choose a template")
            HelpStep(number: 3, title: "Enable Translation", description: "(Optional) Set up translation in the Translation tab for multilingual subtitles")
        }
        
        Text("Pro Tips:")
            .font(.headline)
            .padding(.top)
        
        VStack(alignment: .leading, spacing: 4) {
            Text("• Speak clearly and at normal pace for best accuracy")
            Text("• Use window templates for quick professional layouts")
            Text("• Try different audio modes for advanced use cases")
            Text("• Enable translation for international communication")
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
}

private var windowsContent: some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("Floating subtitle windows display your transcription and translation in customizable overlays.")
            .font(.subheadline)
            .foregroundColor(.secondary)
        
        Text("Window Templates:")
            .font(.headline)
        
        VStack(alignment: .leading, spacing: 8) {
            TemplateDescription(name: "Top Banner", icon: "rectangle.topthird.inset.filled", description: "Full-width banner at top of screen")
            TemplateDescription(name: "Side Panel", icon: "sidebar.right", description: "Vertical panel on the side")
            TemplateDescription(name: "Picture-in-Picture", icon: "pip", description: "Small overlay in corner")
            TemplateDescription(name: "Center Stage", icon: "rectangle.center.inset.filled", description: "Large central window")
            TemplateDescription(name: "Custom", icon: "slider.horizontal.3", description: "Fully customizable positioning")
        }
        
        Text("Window Modes:")
            .font(.headline)
            .padding(.top)
        
        VStack(alignment: .leading, spacing: 4) {
            Text("• Simple Mode: Shows current transcription only")
            Text("• Additive Mode: Builds continuous text flow")
            Text("• Translation: Shows translated text instead of original")
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
}

private var audioContent: some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("Prezefren supports advanced audio processing for different scenarios.")
            .font(.subheadline)
            .foregroundColor(.secondary)
        
        Text("Audio Modes:")
            .font(.headline)
        
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "waveform")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mono Mode")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Standard single-channel processing. Best for most users with regular microphones.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "waveform.badge.plus")
                    .foregroundColor(.purple)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stereo Mode")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Advanced dual-channel processing. Perfect for dual-language audio or professional setups.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        
        Text("Channel Assignment:")
            .font(.headline)
            .padding(.top)
        
        Text("In Stereo mode, assign windows to specific audio channels:")
            .font(.subheadline)
            .foregroundColor(.secondary)
        
        VStack(alignment: .leading, spacing: 4) {
            Text("• Mixed: Combined left+right audio (default)")
            Text("• Left: Only left channel audio")
            Text("• Right: Only right channel audio")
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
}

private var translationContent: some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("Add instant translation to your transcriptions for multilingual communication.")
            .font(.subheadline)
            .foregroundColor(.secondary)
        
        Text("Setup (Optional):")
            .font(.headline)
        
        VStack(alignment: .leading, spacing: 8) {
            HelpStep(number: 1, title: "Get API Key", description: "Visit Google AI Studio and create a free API key")
            HelpStep(number: 2, title: "Configure", description: "Create .env file with GEMINI_API_KEY=your_key")
            HelpStep(number: 3, title: "Enable", description: "Turn on translation for specific windows")
        }
        
        Text("Translation Modes:")
            .font(.headline)
            .padding(.top)
        
        VStack(alignment: .leading, spacing: 4) {
            Text("• Gemini API: High-quality cloud translation (current)")
            Text("• Local NLLB: Offline translation (experimental)")
            Text("• Hybrid: Local first, cloud fallback")
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
        
        Text("Supported Languages:")
            .font(.headline)
            .padding(.top)
        
        Text("English, Spanish, French, German, Chinese, Japanese, Korean, Portuguese, Italian, Russian, and more.")
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
}

private var troubleshootingContent: some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("Common Issues & Solutions:")
            .font(.headline)
        
        VStack(alignment: .leading, spacing: 12) {
            TroubleshootingItem(
                problem: "No Audio Input",
                solution: "Check microphone permission in System Preferences → Security & Privacy → Microphone"
            )
            
            TroubleshootingItem(
                problem: "No Transcription",
                solution: "Verify AI model loaded successfully. Look for 'Audio engine initialized' in Console output."
            )
            
            TroubleshootingItem(
                problem: "Translation Not Working",
                solution: "Check API key configuration in Translation tab. Ensure internet connection for cloud translation."
            )
            
            TroubleshootingItem(
                problem: "Windows Not Appearing",
                solution: "Check window visibility settings and positioning. Windows may be off-screen on disconnected monitor."
            )
            
            TroubleshootingItem(
                problem: "Poor Performance",
                solution: "Restart app periodically, reduce number of active windows, close other applications."
            )
        }
        
        Text("Still having issues?")
            .font(.headline)
            .padding(.top)
        
        HStack {
            Button("View Full Troubleshooting Guide") {
                NSWorkspace.shared.open(URL(string: "https://github.com/Martin-Atrin/Prezefren/blob/main/docs/TROUBLESHOOTING.md")!)
            }
            .buttonStyle(.borderedProminent)
            
            Button("Report Issue") {
                NSWorkspace.shared.open(URL(string: "https://github.com/Hangry-eggplant/Prezefren/issues")!)
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - Helper Views

private struct HelpStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 24, height: 24)
                
                Text("\(number)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct TemplateDescription: View {
    let name: String
    let icon: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title2)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct TroubleshootingItem: View {
    let problem: String
    let solution: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
                
                Text(problem)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Text(solution)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 20)
        }
        .padding(.vertical, 4)
    }
}