#pragma once

#include <CoreAudio/CoreAudio.h>
#include <AVFoundation/AVFoundation.h>
#include <memory>
#include <vector>
#include <functional>

namespace Prezefren {

/**
 * @brief Audio Stream Splitter for Prezefren Virtual Audio Architecture
 * 
 * This class serves as a bridge between the current Prezefren AudioEngine
 * and the new virtual audio device system. It can operate alongside the
 * existing tap-based approach as an alternative routing mechanism.
 */
class AudioSplitter {
public:
    /**
     * @brief Output destination for split audio streams
     */
    struct OutputDestination {
        std::string name;
        std::function<void(const AudioBufferList&, const AudioTimeStamp&)> callback;
        AVAudioFormat* format;
        bool enabled;
        
        OutputDestination(
            const std::string& n,
            std::function<void(const AudioBufferList&, const AudioTimeStamp&)> cb,
            AVAudioFormat* fmt
        ) : name(n), callback(std::move(cb)), format(fmt), enabled(true) {}
    };

    AudioSplitter();
    ~AudioSplitter();

    /**
     * @brief Initialize the audio splitter
     * @param inputFormat The format of incoming audio
     * @return true if initialization successful
     */
    bool Initialize(AVAudioFormat* inputFormat);

    /**
     * @brief Add an output destination for split audio
     * @param destination The output destination to add
     * @return Unique ID for this destination
     */
    int AddOutputDestination(std::unique_ptr<OutputDestination> destination);

    /**
     * @brief Remove an output destination
     * @param destinationId The ID of the destination to remove
     */
    void RemoveOutputDestination(int destinationId);

    /**
     * @brief Enable/disable a specific output destination
     * @param destinationId The destination ID
     * @param enabled Whether to enable or disable
     */
    void SetDestinationEnabled(int destinationId, bool enabled);

    /**
     * @brief Process incoming audio and split to all destinations
     * @param bufferList The audio data to split
     * @param timeStamp Timing information
     */
    void ProcessAudioBuffer(const AudioBufferList& bufferList, const AudioTimeStamp& timeStamp);

    /**
     * @brief Create a transcription-optimized output destination
     * @param callback Function to receive processed audio
     * @return Destination ID
     */
    int CreateTranscriptionDestination(std::function<void(const AudioBufferList&, const AudioTimeStamp&)> callback);

    /**
     * @brief Create a passthrough destination (maintains original quality)
     * @param callback Function to receive original audio
     * @return Destination ID
     */
    int CreatePassthroughDestination(std::function<void(const AudioBufferList&, const AudioTimeStamp&)> callback);

    /**
     * @brief Create a channel-specific destination for stereo processing
     * @param channel The channel to extract (0 = left, 1 = right)
     * @param callback Function to receive channel audio
     * @return Destination ID
     */
    int CreateChannelDestination(int channel, std::function<void(const AudioBufferList&, const AudioTimeStamp&)> callback);

    /**
     * @brief Check if splitter is currently active
     */
    bool IsActive() const { return isInitialized_ && !destinations_.empty(); }

    /**
     * @brief Get statistics about processed audio
     */
    struct Statistics {
        uint64_t totalFramesProcessed;
        uint64_t activeDestinations;
        double averageProcessingTime;
        double inputSampleRate;
        uint32_t inputChannels;
    };
    
    Statistics GetStatistics() const;

private:
    bool isInitialized_;
    AVAudioFormat* inputFormat_;
    
    // Output destinations
    std::vector<std::unique_ptr<OutputDestination>> destinations_;
    int nextDestinationId_;
    
    // Audio format converters for different output formats
    std::map<int, AVAudioConverter*> formatConverters_;
    
    // Performance monitoring
    mutable std::mutex statsMutex_;
    uint64_t totalFramesProcessed_;
    std::chrono::high_resolution_clock::time_point lastProcessTime_;
    double totalProcessingTime_;
    
    // Thread safety
    mutable std::mutex destinationsMutex_;
    
    // Helper methods
    AVAudioFormat* CreateTranscriptionFormat() const;
    AVAudioFormat* CreateChannelFormat(int channelCount) const;
    void ConvertAndSendToDestination(
        const OutputDestination& dest,
        const AudioBufferList& bufferList,
        const AudioTimeStamp& timeStamp
    );
    
    // Cleanup
    void CleanupConverters();
};

} // namespace Prezefren