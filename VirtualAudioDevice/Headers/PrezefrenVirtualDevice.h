#pragma once

#include <aspl/aspl.hpp>
#include <CoreAudio/CoreAudio.h>
#include <memory>
#include <atomic>

namespace Prezefren {

/**
 * @brief Virtual Audio Device for Prezefren
 * 
 * Creates virtual input devices that can receive duplicated audio streams
 * for transcription processing while maintaining native passthrough quality.
 */
class VirtualDevice : public aspl::Device {
public:
    /**
     * @brief Device types supported by Prezefren
     */
    enum class DeviceType {
        TranscriptionInput,  // Virtual input optimized for transcription (16kHz mono)
        PassthroughMirror,   // Mirror device for native passthrough
        StereoLeft,          // Left channel for dual-language processing
        StereoRight          // Right channel for dual-language processing
    };

    /**
     * @brief Construct a new Virtual Device
     * 
     * @param context The ASPL context
     * @param type The type of virtual device to create
     * @param sampleRate Sample rate for the device
     * @param channelCount Number of audio channels
     */
    VirtualDevice(
        std::shared_ptr<aspl::Context> context,
        DeviceType type,
        Float64 sampleRate = 48000.0,
        UInt32 channelCount = 2
    );

    virtual ~VirtualDevice() = default;

    // Device identification
    OSStatus GetManufacturer(CFStringRef* outName) const override;
    OSStatus GetModelName(CFStringRef* outName) const override;
    OSStatus GetSerialNumber(CFStringRef* outName) const override;
    OSStatus GetFirmwareVersion(CFStringRef* outName) const override;

    // Device capabilities
    OSStatus GetZeroTimeStampPeriod(UInt32* outPeriod) const override;
    OSStatus GetIsRunning(Boolean* outIsRunning) const override;
    OSStatus GetLatency(UInt32 inDirection, UInt32* outLatency) const override;

    // Stream management
    OSStatus GetStreamConfiguration(UInt32 inDirection, AudioBufferList** outBufferList) const override;
    
    // Audio I/O
    OSStatus StartIO() override;
    OSStatus StopIO() override;
    OSStatus GetCurrentTime(AudioTimeStamp* outTime) const override;

    // Custom methods for Prezefren
    /**
     * @brief Set the callback for receiving processed audio data
     * @param callback Function to call with audio data
     */
    void SetAudioCallback(std::function<void(const AudioBufferList&, const AudioTimeStamp&)> callback);

    /**
     * @brief Feed audio data to this virtual device
     * @param bufferList Audio data to process
     * @param timeStamp Timing information
     */
    void FeedAudioData(const AudioBufferList& bufferList, const AudioTimeStamp& timeStamp);

    /**
     * @brief Get the device type
     */
    DeviceType GetDeviceType() const { return deviceType_; }

    /**
     * @brief Check if device is currently active
     */
    bool IsActive() const { return isRunning_.load(); }

private:
    DeviceType deviceType_;
    Float64 sampleRate_;
    UInt32 channelCount_;
    std::atomic<bool> isRunning_{false};
    
    // Audio processing
    std::function<void(const AudioBufferList&, const AudioTimeStamp&)> audioCallback_;
    
    // Thread safety
    mutable std::mutex deviceMutex_;
    
    // Performance monitoring
    std::atomic<UInt64> frameCounter_{0};
    AudioTimeStamp lastProcessedTime_{};

    // Helper methods
    void InitializeStreams();
    OSStatus ProcessAudioBuffer(const AudioBufferList& bufferList, const AudioTimeStamp& timeStamp);
    std::string GetDeviceName() const;
    std::string GetDeviceUID() const;
};

} // namespace Prezefren