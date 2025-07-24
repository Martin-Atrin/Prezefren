import SwiftUI

/**
 * DebugConsoleView - Real-time debug console UI
 * 
 * Replaces the "More features coming soon" right panel
 * Shows live debug output from all app components
 */

struct DebugConsoleView: View {
    @StateObject private var debugLogger = DebugLogger.shared
    @State private var searchText = ""
    @State private var selectedLogLevel: LogLevel? = nil
    @State private var autoScroll = true
    @State private var showingExportSheet = false
    
    private var filteredMessages: [LogMessage] {
        var messages = debugLogger.messages
        
        // Filter by log level if selected
        if let selectedLevel = selectedLogLevel {
            messages = messages.filter { $0.level == selectedLevel }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            messages = messages.filter { message in
                message.message.localizedCaseInsensitiveContains(searchText) ||
                message.source.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return messages
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            debugHeader
            
            Divider()
            
            // Console output
            debugConsole
        }
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(isPresented: $showingExportSheet) {
            exportView
        }
    }
    
    private var debugHeader: some View {
        VStack(spacing: 12) {
            // Title
            HStack {
                Image(systemName: "terminal.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text("Debug Console")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(debugLogger.isEnabled ? .green : .orange)
                        .frame(width: 8, height: 8)
                    
                    Text(debugLogger.isEnabled ? "Active" : "Inactive")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Controls row
            HStack(spacing: 12) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    TextField("Search logs...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .frame(maxWidth: 150)
                
                // Log level filter
                Menu {
                    Button("All Levels") {
                        selectedLogLevel = nil
                    }
                    
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Button(action: {
                            selectedLogLevel = selectedLogLevel == level ? nil : level
                        }) {
                            HStack {
                                Text("\(level.rawValue) \(level.rawValue)")
                                if selectedLogLevel == level {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedLogLevel?.rawValue ?? "All")
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    // Auto-scroll toggle
                    Button(action: { autoScroll.toggle() }) {
                        Image(systemName: autoScroll ? "arrow.down.circle.fill" : "arrow.down.circle")
                            .foregroundColor(autoScroll ? .blue : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Auto-scroll to new messages")
                    
                    // Clear button
                    Button(action: { debugLogger.clear() }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("Clear console")
                    
                    // Copy All button
                    Button(action: { 
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(debugLogger.exportLogs(), forType: .string)
                    }) {
                        Image(systemName: "doc.on.clipboard")
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.borderless)
                    .help("Copy all logs to clipboard")
                    
                    // Export button
                    Button(action: { showingExportSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.borderless)
                    .help("Export logs")
                }
                .font(.caption)
            }
        }
        .padding()
    }
    
    private var debugConsole: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    if filteredMessages.isEmpty {
                        // Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "terminal")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            
                            Text(searchText.isEmpty ? "No debug messages yet..." : "No matching messages")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            if !debugLogger.isEnabled {
                                Text("Enable debug mode in preferences to see live output")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        ForEach(filteredMessages) { message in
                            LogMessageRow(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .background(Color(NSColor.textBackgroundColor))
            .onChange(of: filteredMessages.count) { _ in
                if autoScroll && !filteredMessages.isEmpty {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(filteredMessages.last?.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var exportView: some View {
        VStack(spacing: 16) {
            Text("Export Debug Logs")
                .font(.headline)
            
            Text("Copy the debug logs below to share with support or save to a file.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            ScrollView {
                Text(debugLogger.exportLogs())
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
            }
            .frame(height: 300)
            
            HStack {
                Button("Close") {
                    showingExportSheet = false
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Button("Copy All") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(debugLogger.exportLogs(), forType: .string)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}

struct LogMessageRow: View {
    let message: LogMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Timestamp
            Text(message.formattedTime)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            // Log level icon
            Text(message.level.rawValue)
                .font(.caption)
                .foregroundColor(message.level.color)
                .frame(width: 20, alignment: .center)
            
            // Source
            Text(message.source)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
                .lineLimit(1)
            
            // Message
            Text(message.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(message.level == .error ? Color.red.opacity(0.1) : 
                      message.level == .warning ? Color.orange.opacity(0.1) :
                      Color.clear)
        )
        .contextMenu {
            Button("Copy Message") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.displayText, forType: .string)
            }
        }
    }
}

// Preview removed for CLI compilation compatibility