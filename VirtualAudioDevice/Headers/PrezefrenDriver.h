#pragma once

#include <aspl/aspl.hpp>
#include "PrezefrenVirtualDevice.h"
#include "AudioSplitter.h"
#include <memory>
#include <vector>

namespace Prezefren {

/**
 * @brief Main driver for Prezefren Virtual Audio System
 * 
 * This driver manages virtual audio devices and provides an alternative
 * audio architecture that can coexist with the current AudioEngine approach.
 * It's designed to be opt-in and non-disruptive to existing functionality.
 */
class Driver : public aspl::Driver {
public:
    /**
     * @brief Configuration for virtual audio system
     */
    struct Configuration {
        bool enableVirtualAudio = false;           // Master switch for virtual audio
        bool enableTranscriptionDevice = true;    // Create transcription-optimized device
        bool enablePassthroughDevice = true;      // Create passthrough mirror device
        bool enableStereoSeparation = false;      // Create separate L/R devices
        Float64 transcriptionSampleRate = 16000;  // Optimal for speech recognition
        Float64 passthroughSampleRate = 48000;    // High quality for passthrough
        
        // Device naming
        std::string devicePrefix = "Prezefren";
        
        // Performance settings
        UInt32 bufferFrameSize = 512;             // Balance latency vs performance
        bool enableStatistics = true;             // Performance monitoring
    };

    Driver(const Configuration& config = Configuration{});
    virtual ~Driver();

    // Driver interface implementation
    OSStatus Initialize() override;
    OSStatus Teardown() override;

    // Virtual device management
    /**
     * @brief Enable virtual audio routing (alternative to current system)
     * @return true if virtual audio was successfully enabled
     */
    bool EnableVirtualAudio();

    /**
     * @brief Disable virtual audio and return to traditional routing
     */
    void DisableVirtualAudio();

    /**
     * @brief Check if virtual audio is currently enabled
     */
    bool IsVirtualAudioEnabled() const { return virtualAudioEnabled_; }

    /**
     * @brief Set the audio splitter for feeding audio to virtual devices
     * @param splitter The audio splitter instance
     */
    void SetAudioSplitter(std::shared_ptr<AudioSplitter> splitter);

    /**
     * @brief Get available virtual devices
     */
    std::vector<std::shared_ptr<VirtualDevice>> GetVirtualDevices() const;

    /**
     * @brief Get device by type
     */
    std::shared_ptr<VirtualDevice> GetDeviceByType(VirtualDevice::DeviceType type) const;

    /**
     * @brief Set callback for transcription audio data
     */
    void SetTranscriptionCallback(std::function<void(const AudioBufferList&, const AudioTimeStamp&)> callback);

    /**
     * @brief Set callback for passthrough audio data
     */
    void SetPassthroughCallback(std::function<void(const AudioBufferList&, const AudioTimeStamp&)> callback);

    /**
     * @brief Get driver statistics
     */
    struct DriverStatistics {
        bool virtualAudioActive;
        size_t activeDevices;
        AudioSplitter::Statistics splitterStats;
        std::vector<std::pair<VirtualDevice::DeviceType, bool>> deviceStatus;
    };
    
    DriverStatistics GetStatistics() const;

    // Integration with existing AudioEngine
    /**
     * @brief Bridge method: Feed audio from existing AudioEngine tap
     * This allows the virtual audio system to work alongside the current system
     */
    void FeedAudioFromCurrentEngine(const AudioBufferList& bufferList, const AudioTimeStamp& timeStamp);

    /**
     * @brief Get configuration that can be saved to preferences
     */
    Configuration GetConfiguration() const { return config_; }

    /**
     * @brief Update configuration (can be called while running)
     */
    void UpdateConfiguration(const Configuration& newConfig);

private:
    Configuration config_;
    bool isInitialized_;
    bool virtualAudioEnabled_;
    
    // Virtual devices
    std::vector<std::shared_ptr<VirtualDevice>> virtualDevices_;
    std::shared_ptr<VirtualDevice> transcriptionDevice_;
    std::shared_ptr<VirtualDevice> passthroughDevice_;
    std::shared_ptr<VirtualDevice> leftChannelDevice_;
    std::shared_ptr<VirtualDevice> rightChannelDevice_;
    
    // Audio processing
    std::shared_ptr<AudioSplitter> audioSplitter_;
    
    // Callbacks for integration with existing system
    std::function<void(const AudioBufferList&, const AudioTimeStamp&)> transcriptionCallback_;
    std::function<void(const AudioBufferList&, const AudioTimeStamp&)> passthroughCallback_;
    
    // Thread safety
    mutable std::mutex driverMutex_;
    
    // Helper methods
    void CreateVirtualDevices();
    void DestroyVirtualDevices();
    void SetupAudioSplitter();
    void ConnectDeviceCallbacks();
    
    // Device factory methods
    std::shared_ptr<VirtualDevice> CreateTranscriptionDevice();
    std::shared_ptr<VirtualDevice> CreatePassthroughDevice();
    std::shared_ptr<VirtualDevice> CreateChannelDevice(VirtualDevice::DeviceType type);
};

// C interface for plugin factory
extern "C" {
    /**
     * @brief Plugin factory function for Core Audio HAL
     */
    void* PrezefrenDriverFactory(CFAllocatorRef allocator, CFUUIDRef typeUUID);
}

} // namespace Prezefren