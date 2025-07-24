#include "../Headers/AudioSplitter.h"
#include <algorithm>
#include <chrono>
#include <cstring>

namespace Prezefren {

AudioSplitter::AudioSplitter()
    : isInitialized_(false)
    , inputFormat_(nullptr)
    , nextDestinationId_(1)
    , totalFramesProcessed_(0)
    , totalProcessingTime_(0.0)
{
}

AudioSplitter::~AudioSplitter() {
    CleanupConverters();
    if (inputFormat_) {
        [inputFormat_ release];
    }
}

bool AudioSplitter::Initialize(AVAudioFormat* inputFormat) {
    std::lock_guard<std::mutex> lock(destinationsMutex_);
    
    if (isInitialized_) {
        return true;
    }
    
    if (!inputFormat) {
        NSLog(@"❌ AudioSplitter: Cannot initialize with null input format");
        return false;
    }
    
    inputFormat_ = [inputFormat retain];
    isInitialized_ = true;
    
    NSLog(@"✅ AudioSplitter initialized: %.0fHz, %u channels", 
          inputFormat.sampleRate, inputFormat.channelCount);
    
    return true;
}

int AudioSplitter::AddOutputDestination(std::unique_ptr<OutputDestination> destination) {
    std::lock_guard<std::mutex> lock(destinationsMutex_);
    
    if (!destination) {
        return -1;
    }
    
    int id = nextDestinationId_++;
    destination->enabled = true;
    
    // Create format converter if needed
    if (destination->format && ![destination->format isEqual:inputFormat_]) {
        NSError* error = nil;
        AVAudioConverter* converter = [[AVAudioConverter alloc] 
            initFromFormat:inputFormat_ toFormat:destination->format];
        
        if (converter && !error) {
            formatConverters_[id] = converter;
            NSLog(@"✅ AudioSplitter: Created format converter for destination '%s': %.0fHz %uch -> %.0fHz %uch",
                  destination->name.c_str(),
                  inputFormat_.sampleRate, inputFormat_.channelCount,
                  destination->format.sampleRate, destination->format.channelCount);
        } else {
            NSLog(@"❌ AudioSplitter: Failed to create format converter for destination '%s'", 
                  destination->name.c_str());
            [converter release];
            return -1;
        }
    }
    
    destinations_.push_back(std::move(destination));
    
    NSLog(@"✅ AudioSplitter: Added destination '%s' with ID %d", 
          destinations_.back()->name.c_str(), id);
    
    return id;
}

void AudioSplitter::RemoveOutputDestination(int destinationId) {
    std::lock_guard<std::mutex> lock(destinationsMutex_);
    
    // Remove format converter
    auto converterIt = formatConverters_.find(destinationId);
    if (converterIt != formatConverters_.end()) {
        [converterIt->second release];
        formatConverters_.erase(converterIt);
    }
    
    // Find and remove destination
    auto it = std::find_if(destinations_.begin(), destinations_.end(),
        [destinationId](const std::unique_ptr<OutputDestination>& dest) {
            return dest.get() != nullptr; // Simple check since we don't store ID in destination
        });
    
    if (it != destinations_.end()) {
        NSLog(@"✅ AudioSplitter: Removed destination '%s'", (*it)->name.c_str());
        destinations_.erase(it);
    }
}

void AudioSplitter::SetDestinationEnabled(int destinationId, bool enabled) {
    std::lock_guard<std::mutex> lock(destinationsMutex_);
    
    // Note: In a real implementation, we'd need to store destination ID
    // For now, we'll enable/disable all destinations of a certain type
    for (auto& dest : destinations_) {
        if (dest) {
            dest->enabled = enabled;
        }
    }
}

void AudioSplitter::ProcessAudioBuffer(const AudioBufferList& bufferList, const AudioTimeStamp& timeStamp) {
    if (!isInitialized_) {
        return;
    }
    
    auto startTime = std::chrono::high_resolution_clock::now();
    
    std::lock_guard<std::mutex> lock(destinationsMutex_);
    
    // Process for each enabled destination
    for (const auto& dest : destinations_) {
        if (dest && dest->enabled && dest->callback) {
            ConvertAndSendToDestination(*dest, bufferList, timeStamp);
        }
    }
    
    // Update statistics
    {
        std::lock_guard<std::mutex> statsLock(statsMutex_);
        totalFramesProcessed_ += bufferList.mBuffers[0].mDataByteSize / sizeof(float);
        
        auto endTime = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::microseconds>(endTime - startTime);
        totalProcessingTime_ += duration.count() / 1000.0; // Convert to milliseconds
        lastProcessTime_ = endTime;
    }
}

int AudioSplitter::CreateTranscriptionDestination(std::function<void(const AudioBufferList&, const AudioTimeStamp&)> callback) {
    auto format = CreateTranscriptionFormat();
    auto destination = std::make_unique<OutputDestination>(
        "Transcription",
        std::move(callback),
        format
    );
    
    return AddOutputDestination(std::move(destination));
}

int AudioSplitter::CreatePassthroughDestination(std::function<void(const AudioBufferList&, const AudioTimeStamp&)> callback) {
    // Use original format for passthrough (no conversion)
    auto destination = std::make_unique<OutputDestination>(
        "Passthrough",
        std::move(callback),
        inputFormat_
    );
    
    return AddOutputDestination(std::move(destination));
}

int AudioSplitter::CreateChannelDestination(int channel, std::function<void(const AudioBufferList&, const AudioTimeStamp&)> callback) {
    auto format = CreateChannelFormat(1); // Mono output for single channel
    auto destination = std::make_unique<OutputDestination>(
        channel == 0 ? "Left Channel" : "Right Channel",
        std::move(callback),
        format
    );
    
    return AddOutputDestination(std::move(destination));
}

AudioSplitter::Statistics AudioSplitter::GetStatistics() const {
    std::lock_guard<std::mutex> lock(statsMutex_);
    
    Statistics stats;
    stats.totalFramesProcessed = totalFramesProcessed_;
    stats.activeDestinations = destinations_.size();
    stats.averageProcessingTime = totalFramesProcessed_ > 0 ? 
        totalProcessingTime_ / totalFramesProcessed_ : 0.0;
    stats.inputSampleRate = inputFormat_ ? inputFormat_.sampleRate : 0.0;
    stats.inputChannels = inputFormat_ ? inputFormat_.channelCount : 0;
    
    return stats;
}

AVAudioFormat* AudioSplitter::CreateTranscriptionFormat() const {
    // Optimized format for speech recognition: 16kHz mono
    return [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                            sampleRate:16000.0
                                              channels:1
                                           interleaved:NO];
}

AVAudioFormat* AudioSplitter::CreateChannelFormat(int channelCount) const {
    // Use input sample rate but specified channel count
    double sampleRate = inputFormat_ ? inputFormat_.sampleRate : 48000.0;
    return [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                            sampleRate:sampleRate
                                              channels:channelCount
                                           interleaved:NO];
}

void AudioSplitter::ConvertAndSendToDestination(
    const OutputDestination& dest,
    const AudioBufferList& bufferList, 
    const AudioTimeStamp& timeStamp
) {
    // Find converter for this destination
    AVAudioConverter* converter = nullptr;
    for (const auto& pair : formatConverters_) {
        // In a real implementation, we'd match by destination ID
        converter = pair.second;
        break; // For now, use first available converter
    }
    
    if (converter) {
        // Create input buffer from AudioBufferList
        AVAudioPCMBuffer* inputBuffer = [[AVAudioPCMBuffer alloc] 
            initWithPCMFormat:inputFormat_ 
               frameCapacity:bufferList.mBuffers[0].mDataByteSize / sizeof(float)];
        
        if (inputBuffer) {
            // Copy data to input buffer
            inputBuffer.frameLength = bufferList.mBuffers[0].mDataByteSize / sizeof(float);
            memcpy(inputBuffer.floatChannelData[0], 
                   bufferList.mBuffers[0].mData, 
                   bufferList.mBuffers[0].mDataByteSize);
            
            // Create output buffer
            AVAudioPCMBuffer* outputBuffer = [[AVAudioPCMBuffer alloc] 
                initWithPCMFormat:dest.format 
                   frameCapacity:inputBuffer.frameLength * 2]; // Allow for sample rate conversion
            
            if (outputBuffer) {
                NSError* error = nil;
                AVAudioConverterInputStatus status = [converter convertToBuffer:outputBuffer
                                                                          error:&error
                                                             withInputFromBlock:^AVAudioBuffer* _Nullable(AVAudioPacketCount inNumberOfPackets, AVAudioConverterInputStatus* _Nonnull outStatus) {
                    *outStatus = AVAudioConverterInputStatus_HaveData;
                    return inputBuffer;
                }];
                
                if (status == AVAudioConverterInputStatus_HaveData && !error) {
                    // Convert AVAudioPCMBuffer back to AudioBufferList for callback
                    AudioBufferList convertedBufferList;
                    convertedBufferList.mNumberBuffers = 1;
                    convertedBufferList.mBuffers[0].mNumberChannels = dest.format.channelCount;
                    convertedBufferList.mBuffers[0].mDataByteSize = outputBuffer.frameLength * sizeof(float);
                    convertedBufferList.mBuffers[0].mData = outputBuffer.floatChannelData[0];
                    
                    dest.callback(convertedBufferList, timeStamp);
                } else {
                    NSLog(@"❌ AudioSplitter: Format conversion failed for destination '%s': %@", 
                          dest.name.c_str(), error.localizedDescription);
                }
                
                [outputBuffer release];
            }
            
            [inputBuffer release];
        }
    } else {
        // No conversion needed, send original buffer
        dest.callback(bufferList, timeStamp);
    }
}

void AudioSplitter::CleanupConverters() {
    for (auto& pair : formatConverters_) {
        [pair.second release];
    }
    formatConverters_.clear();
}

} // namespace Prezefren