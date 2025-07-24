#include "../Headers/VirtualAudioIntegration.h"
#include "../Headers/PrezefrenDriver.h"
#include "../Headers/AudioSplitter.h"
#include <chrono>

VirtualAudioIntegration::VirtualAudioIntegration()
    : enabled_(false)
    , initialized_(false)
    , buffersProcessed_(0)
    , totalLatency_(0.0)
    , hasErrors_(false)
{
}

VirtualAudioIntegration::~VirtualAudioIntegration() {
    Shutdown();
}

bool VirtualAudioIntegration::Initialize(const Config& config) {
    if (initialized_) {
        return enabled_;
    }
    
    config_ = config;
    
    if (!config_.enabled) {
        NSLog(@"🎵 VirtualAudioIntegration: Disabled via configuration");
        return false;
    }
    
    if (!IsVirtualAudioSupported()) {
        NSLog(@"❌ VirtualAudioIntegration: Virtual audio not supported on this system");
        return false;
    }
    
    if (InitializeVirtualAudioSystem()) {
        initialized_ = true;
        enabled_ = true;
        
        NSLog(@"✅ VirtualAudioIntegration: Initialized successfully");
        NSLog(@"   - Transcription: %s", config_.useForTranscription ? "enabled" : "disabled");
        NSLog(@"   - Passthrough: %s", config_.useForPassthrough ? "enabled" : "disabled");
        NSLog(@"   - Stereo separation: %s", config_.enableStereoSeparation ? "enabled" : "disabled");
        
        return true;
    } else {
        NSLog(@"❌ VirtualAudioIntegration: Initialization failed");
        
        if (config_.fallbackToCurrentSystem) {
            NSLog(@"🔄 VirtualAudioIntegration: Falling back to current system");
            return false; // Signal to use existing system
        }
        
        return false;
    }
}

void VirtualAudioIntegration::Shutdown() {
    if (!initialized_) {
        return;
    }
    
    ShutdownVirtualAudioSystem();
    
    initialized_ = false;
    enabled_ = false;
    
    NSLog(@"✅ VirtualAudioIntegration: Shutdown completed");
}

bool VirtualAudioIntegration::ProcessAudioBuffer(AVAudioPCMBuffer* buffer, const AudioTimeStamp& timeStamp) {
    if (!enabled_ || !buffer) {
        return false;
    }
    
    auto startTime = std::chrono::high_resolution_clock::now();
    
    try {
        // Convert AVAudioPCMBuffer to AudioBufferList
        AudioBufferList bufferList;
        bufferList.mNumberBuffers = buffer.format.channelCount;
        
        // For simplicity, assume non-interleaved format
        for (UInt32 i = 0; i < buffer.format.channelCount; ++i) {
            bufferList.mBuffers[i].mNumberChannels = 1;
            bufferList.mBuffers[i].mDataByteSize = buffer.frameLength * sizeof(Float32);
            bufferList.mBuffers[i].mData = buffer.floatChannelData[i];
        }
        
        // Process through virtual audio system
        if (driver_) {
            driver_->FeedAudioFromCurrentEngine(bufferList, timeStamp);
        }
        
        // Update statistics
        {
            std::lock_guard<std::mutex> lock(statsMutex_);
            buffersProcessed_++;
            
            auto endTime = std::chrono::high_resolution_clock::now();
            auto duration = std::chrono::duration_cast<std::chrono::microseconds>(endTime - startTime);
            totalLatency_ += duration.count() / 1000.0; // Convert to milliseconds
            lastProcessTime_ = endTime;
        }
        
        return true;
        
    } catch (const std::exception& e) {
        NSLog(@"❌ VirtualAudioIntegration: Error processing audio buffer: %s", e.what());
        
        {
            std::lock_guard<std::mutex> lock(statsMutex_);
            hasErrors_ = true;
        }
        
        if (config_.fallbackToCurrentSystem) {
            return false; // Signal to use existing system
        }
        
        return true; // Continue trying to use virtual audio
    }
}

void VirtualAudioIntegration::SetTranscriptionCallback(std::function<void(AVAudioPCMBuffer*, const AudioTimeStamp&)> callback) {
    transcriptionCallback_ = std::move(callback);
    
    if (driver_ && transcriptionCallback_) {
        // Set up bridge callback that converts AudioBufferList back to AVAudioPCMBuffer
        driver_->SetTranscriptionCallback(
            [this](const AudioBufferList& bufferList, const AudioTimeStamp& timeStamp) {
                if (transcriptionCallback_) {
                    // Create AVAudioFormat for the transcription audio (16kHz mono)
                    AVAudioFormat* format = [[AVAudioFormat alloc] 
                        initWithCommonFormat:AVAudioPCMFormatFloat32
                                  sampleRate:16000.0
                                    channels:1
                                 interleaved:NO];
                    
                    // Convert AudioBufferList back to AVAudioPCMBuffer
                    AVAudioPCMBuffer* buffer = ConvertAudioBufferList(bufferList, format);
                    if (buffer) {
                        transcriptionCallback_(buffer, timeStamp);
                        [buffer release];
                    }
                    
                    [format release];
                }
            }
        );
    }
}

void VirtualAudioIntegration::SetPassthroughCallback(std::function<void(AVAudioPCMBuffer*, const AudioTimeStamp&)> callback) {
    passthroughCallback_ = std::move(callback);
    
    if (driver_ && passthroughCallback_) {
        // Set up bridge callback that converts AudioBufferList back to AVAudioPCMBuffer
        driver_->SetPassthroughCallback(
            [this](const AudioBufferList& bufferList, const AudioTimeStamp& timeStamp) {
                if (passthroughCallback_) {
                    // Create AVAudioFormat for the passthrough audio (48kHz stereo)
                    AVAudioFormat* format = [[AVAudioFormat alloc] 
                        initWithCommonFormat:AVAudioPCMFormatFloat32
                                  sampleRate:48000.0
                                    channels:2
                                 interleaved:NO];
                    
                    // Convert AudioBufferList back to AVAudioPCMBuffer
                    AVAudioPCMBuffer* buffer = ConvertAudioBufferList(bufferList, format);
                    if (buffer) {
                        passthroughCallback_(buffer, timeStamp);
                        [buffer release];
                    }
                    
                    [format release];
                }
            }
        );
    }
}

void VirtualAudioIntegration::UpdateConfig(const Config& newConfig) {
    Config oldConfig = config_;
    config_ = newConfig;
    
    if (driver_) {
        // Update driver configuration
        Prezefren::Driver::Configuration driverConfig;
        driverConfig.enableVirtualAudio = config_.enabled;
        driverConfig.enableTranscriptionDevice = config_.useForTranscription;
        driverConfig.enablePassthroughDevice = config_.useForPassthrough;
        driverConfig.enableStereoSeparation = config_.enableStereoSeparation;
        
        driver_->UpdateConfiguration(driverConfig);
    }
    
    // Handle enable/disable changes
    if (oldConfig.enabled != newConfig.enabled) {
        if (newConfig.enabled) {
            if (!enabled_ && Initialize(newConfig)) {
                NSLog(@"✅ VirtualAudioIntegration: Re-enabled via configuration update");
            }
        } else {
            if (enabled_) {
                enabled_ = false;
                NSLog(@"✅ VirtualAudioIntegration: Disabled via configuration update");
            }
        }
    }
}

VirtualAudioIntegration::SimpleStats VirtualAudioIntegration::GetStatistics() const {
    std::lock_guard<std::mutex> lock(statsMutex_);
    
    SimpleStats stats;
    stats.virtualAudioActive = enabled_;
    stats.buffersProcessed = buffersProcessed_;
    stats.averageLatency = buffersProcessed_ > 0 ? totalLatency_ / buffersProcessed_ : 0.0;
    stats.hasErrors = hasErrors_;
    
    return stats;
}

bool VirtualAudioIntegration::IsVirtualAudioSupported() {
    // Check macOS version and other system requirements
    NSProcessInfo* processInfo = [NSProcessInfo processInfo];
    NSOperatingSystemVersion version = [processInfo operatingSystemVersion];
    
    // Require macOS 12.0+ for virtual audio support
    bool versionSupported = (version.majorVersion >= 12);
    
    if (!versionSupported) {
        NSLog(@"❌ VirtualAudioIntegration: macOS 12.0+ required (current: %ld.%ld.%ld)", 
              version.majorVersion, version.minorVersion, version.patchVersion);
        return false;
    }
    
    // Check if Core Audio is available
    // Additional checks could be added here
    
    return true;
}

bool VirtualAudioIntegration::InitializeVirtualAudioSystem() {
    try {
        // Create driver configuration
        Prezefren::Driver::Configuration driverConfig;
        driverConfig.enableVirtualAudio = true;
        driverConfig.enableTranscriptionDevice = config_.useForTranscription;
        driverConfig.enablePassthroughDevice = config_.useForPassthrough;
        driverConfig.enableStereoSeparation = config_.enableStereoSeparation;
        driverConfig.enableStatistics = config_.enableStatistics;
        
        if (config_.enableLowLatencyMode) {
            driverConfig.bufferFrameSize = 256; // Smaller buffer for lower latency
        }
        
        // Create driver
        driver_ = std::make_unique<Prezefren::Driver>(driverConfig);
        
        if (driver_->Initialize() != noErr) {
            NSLog(@"❌ VirtualAudioIntegration: Failed to initialize driver");
            driver_.reset();
            return false;
        }
        
        // Create audio splitter
        splitter_ = std::make_unique<Prezefren::AudioSplitter>();
        
        // Initialize with default format (will be updated when audio starts)
        AVAudioFormat* defaultFormat = [[AVAudioFormat alloc] 
            initWithCommonFormat:AVAudioPCMFormatFloat32
                      sampleRate:48000.0
                        channels:2
                     interleaved:NO];
        
        if (!splitter_->Initialize(defaultFormat)) {
            NSLog(@"❌ VirtualAudioIntegration: Failed to initialize audio splitter");
            [defaultFormat release];
            driver_.reset();
            splitter_.reset();
            return false;
        }
        
        [defaultFormat release];
        
        // Connect splitter to driver
        driver_->SetAudioSplitter(std::shared_ptr<Prezefren::AudioSplitter>(splitter_.get()));
        
        // Enable virtual audio
        if (!driver_->EnableVirtualAudio()) {
            NSLog(@"❌ VirtualAudioIntegration: Failed to enable virtual audio");
            driver_.reset();
            splitter_.reset();
            return false;
        }
        
        NSLog(@"✅ VirtualAudioIntegration: Virtual audio system initialized successfully");
        return true;
        
    } catch (const std::exception& e) {
        NSLog(@"❌ VirtualAudioIntegration: Exception initializing virtual audio system: %s", e.what());
        return false;
    }
}

void VirtualAudioIntegration::ShutdownVirtualAudioSystem() {
    if (driver_) {
        driver_->DisableVirtualAudio();
        driver_->Teardown();
        driver_.reset();
    }
    
    splitter_.reset();
    
    NSLog(@"✅ VirtualAudioIntegration: Virtual audio system shutdown");
}

AVAudioPCMBuffer* VirtualAudioIntegration::ConvertAudioBufferList(const AudioBufferList& bufferList, AVAudioFormat* format) {
    if (bufferList.mNumberBuffers == 0 || !format) {
        return nullptr;
    }
    
    UInt32 frameCount = bufferList.mBuffers[0].mDataByteSize / sizeof(Float32);
    
    AVAudioPCMBuffer* buffer = [[AVAudioPCMBuffer alloc] 
        initWithPCMFormat:format 
           frameCapacity:frameCount];
    
    if (!buffer) {
        return nullptr;
    }
    
    buffer.frameLength = frameCount;
    
    // Copy audio data
    for (UInt32 i = 0; i < MIN(bufferList.mNumberBuffers, format.channelCount); ++i) {
        if (buffer.floatChannelData[i] && bufferList.mBuffers[i].mData) {
            memcpy(buffer.floatChannelData[i], 
                   bufferList.mBuffers[i].mData, 
                   bufferList.mBuffers[i].mDataByteSize);
        }
    }
    
    return buffer;
}

// Factory function
std::unique_ptr<VirtualAudioIntegration> CreateVirtualAudioIntegration(const VirtualAudioIntegration::Config& config) {
    auto integration = std::make_unique<VirtualAudioIntegration>();
    
    if (integration->Initialize(config)) {
        return integration;
    } else {
        // Return nullptr to signal fallback to existing system
        return nullptr;
    }
}