import Foundation
import AVFoundation

enum RecordingFormat: String, CaseIterable {
    case wav = "wav"
    case m4a = "m4a"
    case caf = "caf"
    
    var fileType: AVFileType {
        switch self {
        case .wav: return .wav
        case .m4a: return .m4a
        case .caf: return .caf
        }
    }
    
    var fileExtension: String {
        return rawValue
    }
}

enum RecordingError: Error {
    case failedToCreateFile
    case failedToWriteBuffer
    case invalidFormat
    case diskSpaceError
    case permissionError
}

@MainActor
class AudioRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var currentRecordingURL: URL?
    
    private var audioFile: AVAudioFile?
    private var audioFormat: AVAudioFormat?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var recordingQueue = DispatchQueue(label: "com.prezefren.recording", qos: .userInitiated)
    
    // Recording configuration
    private let format = RecordingFormat.wav
    
    init() {
        // Format will be set dynamically based on first buffer received
    }
    
    // MARK: - Recording Control
    
    func startRecording() throws {
        guard !isRecording else { return }
        
        currentRecordingURL = generateRecordingURL()
        isRecording = true
        recordingStartTime = Date()
        
        // Start duration timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                self.updateRecordingDuration()
            }
        }
        
        print("🎙️ Recording started - waiting for first audio buffer to determine format")
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        recordingQueue.sync {
            audioFile = nil
            audioFormat = nil
        }
        
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        if let url = currentRecordingURL {
            print("🎙️ Recording saved: \(url.lastPathComponent) (\(String(format: "%.1f", recordingDuration))s)")
        }
    }
    
    func pauseRecording() {
        // For future implementation - pause/resume functionality
    }
    
    // MARK: - Audio Buffer Processing
    
    func writeAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isRecording else { return }
        
        recordingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Create audio file on first buffer if not exists
            if self.audioFile == nil {
                guard let fileURL = self.currentRecordingURL else { return }
                
                do {
                    // Use the incoming buffer's format for recording
                    self.audioFormat = buffer.format
                    self.audioFile = try AVAudioFile(forWriting: fileURL, settings: buffer.format.settings)
                    
                    let sampleRate = buffer.format.sampleRate
                    let channels = buffer.format.channelCount
                    print("🎙️ Recording file created: \(fileURL.lastPathComponent) - \(sampleRate)Hz, \(channels) channels")
                    
                } catch {
                    print("❌ Failed to create audio file: \(error)")
                    Task { @MainActor in
                        self.isRecording = false
                    }
                    return
                }
            }
            
            // Write the buffer to file
            guard let audioFile = self.audioFile else { return }
            
            do {
                try audioFile.write(from: buffer)
            } catch {
                print("❌ Failed to write audio buffer: \(error)")
                // Continue recording despite write error
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func generateRecordingURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsPath.appendingPathComponent("Prezefren_Recordings")
        
        // Create recordings directory if it doesn't exist
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        
        let filename = "Prezefren_\(timestamp).\(format.fileExtension)"
        return recordingsDir.appendingPathComponent(filename)
    }
    
    private func updateRecordingDuration() {
        guard let startTime = recordingStartTime else { return }
        recordingDuration = Date().timeIntervalSince(startTime)
    }
    
    // MARK: - File Management
    
    func getRecordingsDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("Prezefren_Recordings")
    }
    
    func deleteRecording(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
    
    func getAllRecordings() -> [URL] {
        let recordingsDir = getRecordingsDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: recordingsDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        return files.filter { url in
            let pathExtension = url.pathExtension.lowercased()
            return RecordingFormat.allCases.contains { $0.fileExtension == pathExtension }
        }.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            return date1 > date2 // Most recent first
        }
    }
}