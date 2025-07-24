import SwiftUI

struct SearchableLanguagePicker: View {
    let title: String
    let languages: [(String, String)]
    @Binding var selectedLanguage: String
    @State private var searchText = ""
    @State private var isShowingPopover = false
    
    private var filteredLanguages: [(String, String)] {
        if searchText.isEmpty {
            return languages
        }
        
        let lowercaseSearch = searchText.lowercased()
        return languages.filter { code, name in
            name.lowercased().contains(lowercaseSearch) ||
            code.lowercased().contains(lowercaseSearch)
        }
    }
    
    private var selectedLanguageName: String {
        languages.first { $0.0 == selectedLanguage }?.1 ?? "Select Language"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Button(action: {
                isShowingPopover.toggle()
            }) {
                HStack {
                    Text(selectedLanguageName)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .popover(isPresented: $isShowingPopover, arrowEdge: .bottom) {
                languageSelectionView
            }
        }
    }
    
    private var languageSelectionView: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search languages...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Language list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredLanguages, id: \.0) { code, name in
                        Button(action: {
                            selectedLanguage = code
                            isShowingPopover = false
                            searchText = ""
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(name)
                                        .font(.system(size: 13))
                                        .foregroundColor(.primary)
                                    
                                    Text(code.uppercased())
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if code == selectedLanguage {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 12, weight: .medium))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                code == selectedLanguage
                                    ? Color.blue.opacity(0.1)
                                    : Color.clear
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            // Optional: Add hover effect
                        }
                        
                        if code != filteredLanguages.last?.0 {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .frame(width: 280)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 8)
    }
}

// MARK: - Convenience Initializers for Specific Language Types

extension SearchableLanguagePicker {
    
    // MARK: - Static Language Pickers (Legacy)
    
    // Whisper language picker (legacy - prefer transcriptionPicker)
    static func whisperPicker(title: String, selectedLanguage: Binding<String>) -> SearchableLanguagePicker {
        return SearchableLanguagePicker(
            title: title,
            languages: LanguageService.whisperLanguages,
            selectedLanguage: selectedLanguage
        )
    }
    
    // Translation language picker using new LanguageService
    static func geminiPicker(title: String, selectedLanguage: Binding<String>) -> SearchableLanguagePicker {
        return SearchableLanguagePicker(
            title: title,
            languages: LanguageService.geminiLanguages,
            selectedLanguage: selectedLanguage
        )
    }
    
    // MARK: - Dynamic Language Pickers
    
    // Dynamic transcription language picker based on engine
    static func transcriptionPicker(
        title: String,
        transcriptionEngine: TranscriptionEngine,
        selectedLanguage: Binding<String>
    ) -> SearchableLanguagePicker {
        let serviceType: TranscriptionServiceType
        switch transcriptionEngine {
        case .whisper:
            serviceType = .whisper
        case .appleSpeech:
            serviceType = .appleSpeech
        case .assembly:
            serviceType = .assembly
        }
        
        return SearchableLanguagePicker(
            title: title,
            languages: LanguageService.getSupportedLanguages(for: serviceType),
            selectedLanguage: selectedLanguage
        )
    }
    
    // Dynamic translation language picker based on service
    static func translationPicker(
        title: String,
        translationService: TranslationServiceType,
        selectedLanguage: Binding<String>
    ) -> SearchableLanguagePicker {
        return SearchableLanguagePicker(
            title: title,
            languages: LanguageService.getSupportedLanguages(for: translationService),
            selectedLanguage: selectedLanguage
        )
    }
    
    // Apple Native translation picker (runtime availability checking)
    @available(macOS 15.0, *)
    static func appleTranslationPicker(
        title: String,
        selectedLanguage: Binding<String>
    ) -> some View {
        AppleTranslationLanguagePicker(
            title: title,
            selectedLanguage: selectedLanguage
        )
    }
}

// MARK: - Apple Translation Language Picker (with Runtime Availability)

@available(macOS 15.0, *)
struct AppleTranslationLanguagePicker: View {
    let title: String
    @Binding var selectedLanguage: String
    @State private var availableLanguages: [(String, String)] = []
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        ProgressView()
                            .scaleEffect(0.5)
                        Text("Loading available languages...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            } else {
                SearchableLanguagePicker(
                    title: title,
                    languages: availableLanguages,
                    selectedLanguage: $selectedLanguage
                )
            }
        }
        .onAppear {
            Task {
                let languages = await LanguageService.getAvailableLanguages(for: .appleNative)
                await MainActor.run {
                    availableLanguages = languages
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Preview

struct SearchableLanguagePicker_Previews: PreviewProvider {
    @State static var selectedLanguage = "en"
    
    static var previews: some View {
        VStack(spacing: 20) {
            SearchableLanguagePicker.whisperPicker(
                title: "Whisper (Legacy)",
                selectedLanguage: $selectedLanguage
            )
            
            SearchableLanguagePicker.transcriptionPicker(
                title: "AssemblyAI Input",
                transcriptionEngine: .assembly,
                selectedLanguage: $selectedLanguage
            )
            
            SearchableLanguagePicker.translationPicker(
                title: "Gemini Translation",
                translationService: .geminiAPI,
                selectedLanguage: $selectedLanguage
            )
        }
        .padding()
        .frame(width: 300)
    }
}