#pragma once

#include <AVFoundation/AVFoundation.h>
#include <memory>
#include <functional>

// Forward declarations to avoid heavy includes in main app
namespace Prezefren {
    class Driver;
    class AudioSplitter;
}

/**
 * @brief Lightweight integration bridge for Prezefren Virtual Audio
 * 
 * This class provides a simple interface to integrate virtual audio
 * capabilities with the existing AudioEngine without requiring major
 * architectural changes. It's designed to be completely optional.
 */
class VirtualAudioIntegration {
public:
    /**
     * @brief Configuration for virtual audio integration
     */
    struct Config {
        bool enabled = false;                      // Master switch
        bool useForTranscription = false;        // Route transcription through virtual device
        bool useForPassthrough = false;          // Route passthrough through virtual device
        bool enableStereoSeparation = false;     // Enable L/R channel separation
        
        // Performance settings
        bool enableLowLatencyMode = true;        // Optimize for real-time performance
        bool enableStatistics = false;          // Disable by default to reduce overhead
        
        // Fallback behavior
        bool fallbackToCurrentSystem = true;    // Fall back if virtual audio fails
    };

    VirtualAudioIntegration();
    ~VirtualAudioIntegration();

    /**
     * @brief Initialize virtual audio integration
     * @param config Configuration options
     * @return true if initialization successful, false if should fall back to current system
     */
    bool Initialize(const Config& config);

    /**
     * @brief Shutdown virtual audio integration
     */
    void Shutdown();

    /**
     * @brief Check if virtual audio is available and enabled
     */
    bool IsEnabled() const { return enabled_; }

    /**
     * @brief Process audio buffer through virtual audio system
     * 
     * This method can be called from the existing AudioEngine's audio tap.
     * If virtual audio is disabled or fails, it simply returns false and
     * the existing system continues unchanged.
     * 
     * @param buffer Audio buffer from existing tap
     * @param timeStamp Timing information
     * @return true if processed by virtual audio, false if should use existing system
     */
    bool ProcessAudioBuffer(AVAudioPCMBuffer* buffer, const AudioTimeStamp& timeStamp);

    /**
     * @brief Set callback for transcription audio (replaces existing transcription pipeline)
     */
    void SetTranscriptionCallback(std::function<void(AVAudioPCMBuffer*, const AudioTimeStamp&)> callback);

    /**
     * @brief Set callback for passthrough audio (replaces existing passthrough pipeline)
     */
    void SetPassthroughCallback(std::function<void(AVAudioPCMBuffer*, const AudioTimeStamp&)> callback);

    /**
     * @brief Update configuration at runtime
     */
    void UpdateConfig(const Config& newConfig);

    /**
     * @brief Get current configuration
     */
    Config GetConfig() const { return config_; }

    /**
     * @brief Get simple statistics (only if enabled in config)
     */
    struct SimpleStats {
        bool virtualAudioActive;
        uint64_t buffersProcessed;
        double averageLatency;
        bool hasErrors;
    };
    
    SimpleStats GetStatistics() const;

    /**
     * @brief Static method to check if virtual audio is supported on this system
     */
    static bool IsVirtualAudioSupported();

private:
    Config config_;
    bool enabled_;
    bool initialized_;
    
    // Virtual audio components (using pimpl pattern to avoid heavy includes)
    std::unique_ptr<Prezefren::Driver> driver_;
    std::unique_ptr<Prezefren::AudioSplitter> splitter_;
    
    // Callbacks
    std::function<void(AVAudioPCMBuffer*, const AudioTimeStamp&)> transcriptionCallback_;
    std::function<void(AVAudioPCMBuffer*, const AudioTimeStamp&)> passthroughCallback_;
    
    // Statistics
    mutable std::mutex statsMutex_;
    uint64_t buffersProcessed_;
    std::chrono::high_resolution_clock::time_point lastProcessTime_;
    double totalLatency_;
    bool hasErrors_;
    
    // Helper methods
    bool InitializeVirtualAudioSystem();
    void ShutdownVirtualAudioSystem();
    AVAudioPCMBuffer* ConvertAudioBufferList(const AudioBufferList& bufferList, AVAudioFormat* format);
};

/**
 * @brief Simple factory function to create integration instance
 * 
 * This can be called from AudioEngine to optionally enable virtual audio.
 * If it returns nullptr, the existing system should continue unchanged.
 */
std::unique_ptr<VirtualAudioIntegration> CreateVirtualAudioIntegration(
    const VirtualAudioIntegration::Config& config = VirtualAudioIntegration::Config{}
);