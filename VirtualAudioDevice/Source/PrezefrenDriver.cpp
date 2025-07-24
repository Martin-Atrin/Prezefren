#include "../Headers/PrezefrenDriver.h"
#include <memory>

namespace Prezefren {

Driver::Driver(const Configuration& config)
    : config_(config)
    , isInitialized_(false)
    , virtualAudioEnabled_(false)
    , audioSplitter_(nullptr)
{
    NSLog(@"🎵 PrezefrenDriver: Initializing with virtual audio %s", 
          config_.enableVirtualAudio ? "enabled" : "disabled");
}

Driver::~Driver() {
    if (isInitialized_) {
        Teardown();
    }
}

OSStatus Driver::Initialize() {
    std::lock_guard<std::mutex> lock(driverMutex_);
    
    if (isInitialized_) {
        return noErr;
    }
    
    try {
        // Initialize base driver
        OSStatus result = aspl::Driver::Initialize();
        if (result != noErr) {
            NSLog(@"❌ PrezefrenDriver: Base driver initialization failed: %d", (int)result);
            return result;
        }
        
        // Create virtual devices if enabled
        if (config_.enableVirtualAudio) {
            CreateVirtualDevices();
            SetupAudioSplitter();
            ConnectDeviceCallbacks();
        }
        
        isInitialized_ = true;
        
        NSLog(@"✅ PrezefrenDriver: Initialized successfully with %zu virtual devices", 
              virtualDevices_.size());
        
        return noErr;
        
    } catch (const std::exception& e) {
        NSLog(@"❌ PrezefrenDriver: Initialization failed: %s", e.what());
        return kAudioHardwareUnspecifiedError;
    }
}

OSStatus Driver::Teardown() {
    std::lock_guard<std::mutex> lock(driverMutex_);
    
    if (!isInitialized_) {
        return noErr;
    }
    
    // Disable virtual audio
    DisableVirtualAudio();
    
    // Destroy virtual devices
    DestroyVirtualDevices();
    
    // Cleanup audio splitter
    audioSplitter_.reset();
    
    // Teardown base driver
    OSStatus result = aspl::Driver::Teardown();
    
    isInitialized_ = false;
    
    NSLog(@"✅ PrezefrenDriver: Teardown completed");
    return result;
}

bool Driver::EnableVirtualAudio() {
    std::lock_guard<std::mutex> lock(driverMutex_);
    
    if (!isInitialized_ || virtualAudioEnabled_) {
        return virtualAudioEnabled_;
    }
    
    try {
        // Start all virtual devices
        for (auto& device : virtualDevices_) {
            if (device) {
                OSStatus result = device->StartIO();
                if (result != noErr) {
                    NSLog(@"⚠️ PrezefrenDriver: Failed to start device %s: %d", 
                          device->GetDeviceName().c_str(), (int)result);
                }
            }
        }
        
        virtualAudioEnabled_ = true;
        
        NSLog(@"✅ PrezefrenDriver: Virtual audio enabled with %zu active devices", 
              virtualDevices_.size());
        
        return true;
        
    } catch (const std::exception& e) {
        NSLog(@"❌ PrezefrenDriver: Failed to enable virtual audio: %s", e.what());
        return false;
    }
}

void Driver::DisableVirtualAudio() {
    std::lock_guard<std::mutex> lock(driverMutex_);
    
    if (!virtualAudioEnabled_) {
        return;
    }
    
    // Stop all virtual devices
    for (auto& device : virtualDevices_) {
        if (device) {
            device->StopIO();
        }
    }
    
    virtualAudioEnabled_ = false;
    
    NSLog(@"✅ PrezefrenDriver: Virtual audio disabled");
}

void Driver::SetAudioSplitter(std::shared_ptr<AudioSplitter> splitter) {
    std::lock_guard<std::mutex> lock(driverMutex_);
    audioSplitter_ = splitter;
    
    if (audioSplitter_) {
        NSLog(@"✅ PrezefrenDriver: Audio splitter connected");
    }
}

std::vector<std::shared_ptr<VirtualDevice>> Driver::GetVirtualDevices() const {
    std::lock_guard<std::mutex> lock(driverMutex_);
    return virtualDevices_;
}

std::shared_ptr<VirtualDevice> Driver::GetDeviceByType(VirtualDevice::DeviceType type) const {
    std::lock_guard<std::mutex> lock(driverMutex_);
    
    for (const auto& device : virtualDevices_) {
        if (device && device->GetDeviceType() == type) {
            return device;
        }
    }
    
    return nullptr;
}

void Driver::SetTranscriptionCallback(std::function<void(const AudioBufferList&, const AudioTimeStamp&)> callback) {
    std::lock_guard<std::mutex> lock(driverMutex_);
    transcriptionCallback_ = std::move(callback);
    
    // Connect to transcription device if it exists
    if (transcriptionDevice_) {
        transcriptionDevice_->SetAudioCallback(transcriptionCallback_);
    }
}

void Driver::SetPassthroughCallback(std::function<void(const AudioBufferList&, const AudioTimeStamp&)> callback) {
    std::lock_guard<std::mutex> lock(driverMutex_);
    passthroughCallback_ = std::move(callback);
    
    // Connect to passthrough device if it exists
    if (passthroughDevice_) {
        passthroughDevice_->SetAudioCallback(passthroughCallback_);
    }
}

Driver::DriverStatistics Driver::GetStatistics() const {
    std::lock_guard<std::mutex> lock(driverMutex_);
    
    DriverStatistics stats;
    stats.virtualAudioActive = virtualAudioEnabled_;
    stats.activeDevices = virtualDevices_.size();
    
    if (audioSplitter_) {
        stats.splitterStats = audioSplitter_->GetStatistics();
    }
    
    // Collect device status
    for (const auto& device : virtualDevices_) {
        if (device) {
            stats.deviceStatus.emplace_back(device->GetDeviceType(), device->IsActive());
        }
    }
    
    return stats;
}

void Driver::FeedAudioFromCurrentEngine(const AudioBufferList& bufferList, const AudioTimeStamp& timeStamp) {
    if (!virtualAudioEnabled_ || !audioSplitter_) {
        return;
    }
    
    try {
        audioSplitter_->ProcessAudioBuffer(bufferList, timeStamp);
    } catch (const std::exception& e) {
        NSLog(@"❌ PrezefrenDriver: Error processing audio from current engine: %s", e.what());
    }
}

void Driver::UpdateConfiguration(const Configuration& newConfig) {
    std::lock_guard<std::mutex> lock(driverMutex_);
    
    Configuration oldConfig = config_;
    config_ = newConfig;
    
    // Handle configuration changes
    if (oldConfig.enableVirtualAudio != newConfig.enableVirtualAudio) {
        if (newConfig.enableVirtualAudio) {
            if (isInitialized_ && virtualDevices_.empty()) {
                CreateVirtualDevices();
                SetupAudioSplitter();
                ConnectDeviceCallbacks();
            }
            EnableVirtualAudio();
        } else {
            DisableVirtualAudio();
        }
    }
    
    NSLog(@"✅ PrezefrenDriver: Configuration updated");
}

void Driver::CreateVirtualDevices() {
    virtualDevices_.clear();
    
    try {
        // Create transcription device if enabled
        if (config_.enableTranscriptionDevice) {
            transcriptionDevice_ = CreateTranscriptionDevice();
            if (transcriptionDevice_) {
                virtualDevices_.push_back(transcriptionDevice_);
                AddDevice(transcriptionDevice_);
            }
        }
        
        // Create passthrough device if enabled
        if (config_.enablePassthroughDevice) {
            passthroughDevice_ = CreatePassthroughDevice();
            if (passthroughDevice_) {
                virtualDevices_.push_back(passthroughDevice_);
                AddDevice(passthroughDevice_);
            }
        }
        
        // Create stereo separation devices if enabled
        if (config_.enableStereoSeparation) {
            leftChannelDevice_ = CreateChannelDevice(VirtualDevice::DeviceType::StereoLeft);
            rightChannelDevice_ = CreateChannelDevice(VirtualDevice::DeviceType::StereoRight);
            
            if (leftChannelDevice_) {
                virtualDevices_.push_back(leftChannelDevice_);
                AddDevice(leftChannelDevice_);
            }
            
            if (rightChannelDevice_) {
                virtualDevices_.push_back(rightChannelDevice_);
                AddDevice(rightChannelDevice_);
            }
        }
        
        NSLog(@"✅ PrezefrenDriver: Created %zu virtual devices", virtualDevices_.size());
        
    } catch (const std::exception& e) {
        NSLog(@"❌ PrezefrenDriver: Failed to create virtual devices: %s", e.what());
    }
}

void Driver::DestroyVirtualDevices() {
    // Stop all devices first
    for (auto& device : virtualDevices_) {
        if (device) {
            device->StopIO();
        }
    }
    
    // Clear references
    transcriptionDevice_.reset();
    passthroughDevice_.reset();
    leftChannelDevice_.reset();
    rightChannelDevice_.reset();
    virtualDevices_.clear();
    
    NSLog(@"✅ PrezefrenDriver: Virtual devices destroyed");
}

void Driver::SetupAudioSplitter() {
    if (!audioSplitter_) {
        audioSplitter_ = std::make_shared<AudioSplitter>();
        
        // Initialize with a default format (will be updated when audio starts)
        AVAudioFormat* defaultFormat = [[AVAudioFormat alloc] 
            initWithCommonFormat:AVAudioPCMFormatFloat32
                      sampleRate:config_.passthroughSampleRate
                        channels:2
                     interleaved:NO];
        
        if (audioSplitter_->Initialize(defaultFormat)) {
            NSLog(@"✅ PrezefrenDriver: Audio splitter initialized");
        } else {
            NSLog(@"❌ PrezefrenDriver: Failed to initialize audio splitter");
            audioSplitter_.reset();
        }
        
        [defaultFormat release];
    }
}

void Driver::ConnectDeviceCallbacks() {
    if (!audioSplitter_) {
        return;
    }
    
    // Connect transcription device
    if (transcriptionDevice_) {
        int destinationId = audioSplitter_->CreateTranscriptionDestination(
            [this](const AudioBufferList& bufferList, const AudioTimeStamp& timeStamp) {
                if (transcriptionCallback_) {
                    transcriptionCallback_(bufferList, timeStamp);
                }
                transcriptionDevice_->FeedAudioData(bufferList, timeStamp);
            }
        );
        
        if (destinationId >= 0) {
            NSLog(@"✅ PrezefrenDriver: Connected transcription device to splitter");
        }
    }
    
    // Connect passthrough device
    if (passthroughDevice_) {
        int destinationId = audioSplitter_->CreatePassthroughDestination(
            [this](const AudioBufferList& bufferList, const AudioTimeStamp& timeStamp) {
                if (passthroughCallback_) {
                    passthroughCallback_(bufferList, timeStamp);
                }
                passthroughDevice_->FeedAudioData(bufferList, timeStamp);
            }
        );
        
        if (destinationId >= 0) {
            NSLog(@"✅ PrezefrenDriver: Connected passthrough device to splitter");
        }
    }
    
    // Connect channel devices
    if (leftChannelDevice_) {
        int destinationId = audioSplitter_->CreateChannelDestination(0, // Left channel
            [this](const AudioBufferList& bufferList, const AudioTimeStamp& timeStamp) {
                leftChannelDevice_->FeedAudioData(bufferList, timeStamp);
            }
        );
        
        if (destinationId >= 0) {
            NSLog(@"✅ PrezefrenDriver: Connected left channel device to splitter");
        }
    }
    
    if (rightChannelDevice_) {
        int destinationId = audioSplitter_->CreateChannelDestination(1, // Right channel
            [this](const AudioBufferList& bufferList, const AudioTimeStamp& timeStamp) {
                rightChannelDevice_->FeedAudioData(bufferList, timeStamp);
            }
        );
        
        if (destinationId >= 0) {
            NSLog(@"✅ PrezefrenDriver: Connected right channel device to splitter");
        }
    }
}

std::shared_ptr<VirtualDevice> Driver::CreateTranscriptionDevice() {
    try {
        auto device = std::make_shared<VirtualDevice>(
            GetContext(),
            VirtualDevice::DeviceType::TranscriptionInput,
            config_.transcriptionSampleRate,
            1 // Mono for transcription
        );
        
        NSLog(@"✅ PrezefrenDriver: Created transcription device");
        return device;
        
    } catch (const std::exception& e) {
        NSLog(@"❌ PrezefrenDriver: Failed to create transcription device: %s", e.what());
        return nullptr;
    }
}

std::shared_ptr<VirtualDevice> Driver::CreatePassthroughDevice() {
    try {
        auto device = std::make_shared<VirtualDevice>(
            GetContext(),
            VirtualDevice::DeviceType::PassthroughMirror,
            config_.passthroughSampleRate,
            2 // Stereo for passthrough
        );
        
        NSLog(@"✅ PrezefrenDriver: Created passthrough device");
        return device;
        
    } catch (const std::exception& e) {
        NSLog(@"❌ PrezefrenDriver: Failed to create passthrough device: %s", e.what());
        return nullptr;
    }
}

std::shared_ptr<VirtualDevice> Driver::CreateChannelDevice(VirtualDevice::DeviceType type) {
    try {
        auto device = std::make_shared<VirtualDevice>(
            GetContext(),
            type,
            config_.passthroughSampleRate,
            1 // Mono for single channel
        );
        
        NSLog(@"✅ PrezefrenDriver: Created channel device (%s)", 
              type == VirtualDevice::DeviceType::StereoLeft ? "Left" : "Right");
        return device;
        
    } catch (const std::exception& e) {
        NSLog(@"❌ PrezefrenDriver: Failed to create channel device: %s", e.what());
        return nullptr;
    }
}

// C interface for plugin factory
extern "C" void* PrezefrenDriverFactory(CFAllocatorRef allocator, CFUUIDRef typeUUID) {
    try {
        // Create default configuration
        Driver::Configuration config;
        config.enableVirtualAudio = true;
        config.enableTranscriptionDevice = true;
        config.enablePassthroughDevice = true;
        config.enableStereoSeparation = false; // Disabled by default
        
        auto driver = std::make_shared<Driver>(config);
        
        if (driver->Initialize() == noErr) {
            NSLog(@"✅ PrezefrenDriverFactory: Driver created successfully");
            return driver.get(); // Return raw pointer for C interface
        } else {
            NSLog(@"❌ PrezefrenDriverFactory: Driver initialization failed");
            return nullptr;
        }
        
    } catch (const std::exception& e) {
        NSLog(@"❌ PrezefrenDriverFactory: Exception creating driver: %s", e.what());
        return nullptr;
    }
}

} // namespace Prezefren