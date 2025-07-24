import Foundation

class EnvironmentConfig {
    static let shared = EnvironmentConfig()
    
    private var envVariables: [String: String] = [:]
    
    private init() {
        loadEnvironmentFile()
    }
    
    private func loadEnvironmentFile() {
        let envPath = "./.env"
        
        guard let envContent = try? String(contentsOfFile: envPath, encoding: .utf8) else {
            print("📝 No .env file found. Create one with GEMINI_API_KEY=your_key")
            return
        }
        
        let lines = envContent.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip comments and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            // Parse KEY=VALUE format
            let parts = trimmed.components(separatedBy: "=")
            if parts.count >= 2 {
                let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespacesAndNewlines)
                envVariables[key] = value
            }
        }
        
        print("✅ Loaded \(envVariables.count) environment variables from .env")
    }
    
    func getValue(for key: String) -> String? {
        return envVariables[key]
    }
    
    func getGeminiAPIKey() -> String? {
        return getValue(for: "GEMINI_API_KEY")
    }
    
    func setAPIKey(_ key: String) {
        envVariables["GEMINI_API_KEY"] = key
        saveEnvironmentFile()
    }
    
    private func saveEnvironmentFile() {
        let envPath = "./.env"
        var content = "# Prezefren Environment Configuration\n"
        content += "# Generated automatically - do not edit manually\n\n"
        
        for (key, value) in envVariables {
            content += "\(key)=\(value)\n"
        }
        
        do {
            try content.write(toFile: envPath, atomically: true, encoding: .utf8)
            print("✅ Saved API key to .env file")
        } catch {
            print("❌ Failed to save .env file: \(error)")
        }
    }
}