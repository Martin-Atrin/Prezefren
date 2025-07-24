import Foundation

enum WhisperModel: String, CaseIterable, Codable {
    case base = "base"
    
    var displayName: String {
        return "base (Multilingual) - Good balance, supports 100+ languages"
    }
    
    var fileName: String {
        return "ggml-\(rawValue).bin"
    }
    
    var downloadURL: String {
        return "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-\(rawValue).bin"
    }
    
    var sizeInMB: Int {
        return 142
    }
    
    var isMultilingual: Bool {
        return true
    }
    
    var speedRating: Int {
        return 4
    }
    
    var qualityRating: Int {
        return 2
    }
}

enum ModelDownloadError: Error, LocalizedError {
    case networkError(Error)
    case invalidURL
    case diskSpaceError
    case checksumMismatch
    case fileWriteError
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidURL:
            return "Invalid download URL"
        case .diskSpaceError:
            return "Insufficient disk space"
        case .checksumMismatch:
            return "Downloaded file is corrupted"
        case .fileWriteError:
            return "Failed to write file to disk"
        }
    }
}

@MainActor
class WhisperModelManager: ObservableObject {
    @Published var availableModels: [WhisperModel] = WhisperModel.allCases
    @Published var downloadedModels: [WhisperModel] = []
    @Published var currentModel: WhisperModel = .base
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadingModel: WhisperModel?
    @Published var downloadError: ModelDownloadError?
    
    private let modelsDirectory: URL
    private let userDefaults = UserDefaults.standard
    private let currentModelKey = "SelectedWhisperModel"
    
    init() {
        // Create models directory in app support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        modelsDirectory = appSupport.appendingPathComponent("Prezefren/Models")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        
        // Load current model from UserDefaults
        if let savedModelRaw = userDefaults.string(forKey: currentModelKey),
           let savedModel = WhisperModel(rawValue: savedModelRaw) {
            currentModel = savedModel
        }
        
        scanDownloadedModels()
    }
    
    // MARK: - Model Scanning
    
    func scanDownloadedModels() {
        downloadedModels.removeAll()
        
        for model in WhisperModel.allCases {
            let modelPath = modelsDirectory.appendingPathComponent(model.fileName)
            if FileManager.default.fileExists(atPath: modelPath.path) {
                downloadedModels.append(model)
            }
        }
        
        // Also check for legacy models in working directory
        for model in WhisperModel.allCases {
            let legacyPath = "./\(model.fileName)"
            if FileManager.default.fileExists(atPath: legacyPath) && !downloadedModels.contains(model) {
                downloadedModels.append(model)
            }
        }
        
        // Check build directory
        for model in WhisperModel.allCases {
            let buildPath = "./build/\(model.fileName)"
            if FileManager.default.fileExists(atPath: buildPath) && !downloadedModels.contains(model) {
                downloadedModels.append(model)
            }
        }
        
        print("📥 Found \(downloadedModels.count) downloaded models: \(downloadedModels.map { $0.rawValue })")
        
        // Ensure current model is available
        if !downloadedModels.contains(currentModel) {
            if let firstAvailable = downloadedModels.first {
                setCurrentModel(firstAvailable)
            }
        }
    }
    
    // MARK: - Model Selection
    
    func setCurrentModel(_ model: WhisperModel) {
        currentModel = model
        userDefaults.set(model.rawValue, forKey: currentModelKey)
        print("🤖 Current Whisper model set to: \(model.displayName)")
        
        // Note: Actual model switching requires app restart due to Whisper context initialization
    }
    
    func isModelDownloaded(_ model: WhisperModel) -> Bool {
        return downloadedModels.contains(model)
    }
    
    func getModelPath(_ model: WhisperModel) -> String? {
        // Priority order: App Support -> Bundle -> Working Dir -> Build Dir
        
        // 1. App Support directory (downloaded models)
        let appSupportPath = modelsDirectory.appendingPathComponent(model.fileName)
        if FileManager.default.fileExists(atPath: appSupportPath.path) {
            return appSupportPath.path
        }
        
        // 2. Bundle resources (for distribution)
        if let bundlePath = Bundle.main.path(forResource: "ggml-\(model.rawValue)", ofType: "bin") {
            return bundlePath
        }
        
        // 3. Working directory (development)
        let workingPath = "./\(model.fileName)"
        if FileManager.default.fileExists(atPath: workingPath) {
            return workingPath
        }
        
        // 4. Build directory (development)
        let buildPath = "./build/\(model.fileName)"
        if FileManager.default.fileExists(atPath: buildPath) {
            return buildPath
        }
        
        return nil
    }
    
    func getCurrentModelPath() -> String? {
        return getModelPath(currentModel)
    }
    
    // MARK: - Model Downloading
    
    func downloadModel(_ model: WhisperModel) async {
        guard !isDownloading else {
            print("⚠️ Download already in progress")
            return
        }
        
        isDownloading = true
        downloadingModel = model
        downloadProgress = 0.0
        downloadError = nil
        
        defer {
            Task { @MainActor in
                isDownloading = false
                downloadingModel = nil
                downloadProgress = 0.0
            }
        }
        
        do {
            print("📥 Starting download of \(model.displayName)")
            
            guard let url = URL(string: model.downloadURL) else {
                throw ModelDownloadError.invalidURL
            }
            
            let destinationPath = modelsDirectory.appendingPathComponent(model.fileName)
            
            // Check available disk space
            let requiredSpace = UInt64(model.sizeInMB * 1024 * 1024)
            if !hasEnoughDiskSpace(requiredBytes: requiredSpace) {
                throw ModelDownloadError.diskSpaceError
            }
            
            // Download with progress tracking
            let (tempURL, _) = try await URLSession.shared.download(from: url) { bytesWritten, totalBytesExpected, totalBytesWritten in
                if totalBytesExpected > 0 {
                    let progress = Double(totalBytesWritten) / Double(totalBytesExpected)
                    Task { @MainActor in
                        self.downloadProgress = progress
                    }
                }
            }
            
            // Move to final location
            try FileManager.default.moveItem(at: tempURL, to: destinationPath)
            
            // Update UI on main thread
            await MainActor.run {
                scanDownloadedModels()
                print("✅ Successfully downloaded \(model.displayName)")
            }
            
        } catch {
            await MainActor.run {
                if let downloadError = error as? ModelDownloadError {
                    self.downloadError = downloadError
                } else {
                    self.downloadError = .networkError(error)
                }
                print("❌ Failed to download \(model.displayName): \(error)")
            }
        }
    }
    
    private func hasEnoughDiskSpace(requiredBytes: UInt64) -> Bool {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: modelsDirectory.path)
            if let freeSpace = attributes[.systemFreeSize] as? UInt64 {
                return freeSpace > requiredBytes * 2 // Require 2x space for safety
            }
        } catch {
            print("⚠️ Could not check disk space: \(error)")
        }
        return true // Assume we have space if we can't check
    }
    
    // MARK: - Model Management
    
    func deleteModel(_ model: WhisperModel) {
        let modelPath = modelsDirectory.appendingPathComponent(model.fileName)
        
        do {
            try FileManager.default.removeItem(at: modelPath)
            downloadedModels.removeAll { $0 == model }
            print("🗑️ Deleted model: \(model.displayName)")
            
            // If we deleted the current model, switch to another
            if currentModel == model, let firstAvailable = downloadedModels.first {
                setCurrentModel(firstAvailable)
            }
        } catch {
            print("❌ Failed to delete model \(model.displayName): \(error)")
        }
    }
    
    func getModelRecommendation(for useCase: String) -> WhisperModel {
        return .base
    }
    
    func getStorageInfo() -> (usedMB: Int, totalDownloaded: Int) {
        let usedSpace = downloadedModels.reduce(0) { $0 + $1.sizeInMB }
        return (usedMB: usedSpace, totalDownloaded: downloadedModels.count)
    }
    
    // MARK: - Model Compatibility
    
    func getCompatibleModelsForLanguage(_ languageCode: String) -> [WhisperModel] {
        return WhisperModel.allCases
    }
    
    func validateModelForLanguage(_ model: WhisperModel, language: String) -> Bool {
        return true
    }
}

// MARK: - URLSession Download Extension

extension URLSession {
    func download(from url: URL, progressHandler: @escaping (Int64, Int64, Int64) -> Void) async throws -> (URL, URLResponse) {
        return try await withCheckedThrowingContinuation { continuation in
            let task = downloadTask(with: url) { location, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let location = location, let response = response {
                    continuation.resume(returning: (location, response))
                } else {
                    continuation.resume(throwing: URLError(.unknown))
                }
            }
            
            // Set up progress observation
            let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
                let totalBytes = task.progress.totalUnitCount
                let completedBytes = task.progress.completedUnitCount
                progressHandler(completedBytes, totalBytes, completedBytes)
            }
            
            task.resume()
            
            // Keep observation alive
            withExtendedLifetime(observation) {
                // Observation will be automatically cleaned up
            }
        }
    }
}