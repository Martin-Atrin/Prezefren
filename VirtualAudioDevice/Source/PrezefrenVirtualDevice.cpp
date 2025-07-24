#include "../Headers/PrezefrenVirtualDevice.h"
#include <CoreFoundation/CoreFoundation.h>
#include <mach/mach_time.h>

namespace Prezefren {

VirtualDevice::VirtualDevice(
    std::shared_ptr<aspl::Context> context,
    DeviceType type,
    Float64 sampleRate,
    UInt32 channelCount
) : aspl::Device(context), 
    deviceType_(type), 
    sampleRate_(sampleRate), 
    channelCount_(channelCount) {
    
    // Initialize streams based on device type
    InitializeStreams();
    
    NSLog(@"✅ VirtualDevice created: %s (%.0fHz, %uch)", 
          GetDeviceName().c_str(), sampleRate_, channelCount_);
}

OSStatus VirtualDevice::GetManufacturer(CFStringRef* outName) const {
    if (!outName) return kAudioHardwareIllegalOperationError;
    
    *outName = CFStringCreateWithCString(kCFAllocatorDefault, 
                                        "Prezefren Audio", 
                                        kCFStringEncodingUTF8);
    return noErr;
}

OSStatus VirtualDevice::GetModelName(CFStringRef* outName) const {
    if (!outName) return kAudioHardwareIllegalOperationError;
    
    *outName = CFStringCreateWithCString(kCFAllocatorDefault, 
                                        GetDeviceName().c_str(), 
                                        kCFStringEncodingUTF8);
    return noErr;
}

OSStatus VirtualDevice::GetSerialNumber(CFStringRef* outName) const {
    if (!outName) return kAudioHardwareIllegalOperationError;
    
    std::string serial = GetDeviceUID() + "_v110";
    *outName = CFStringCreateWithCString(kCFAllocatorDefault, 
                                        serial.c_str(), 
                                        kCFStringEncodingUTF8);
    return noErr;
}

OSStatus VirtualDevice::GetFirmwareVersion(CFStringRef* outName) const {
    if (!outName) return kAudioHardwareIllegalOperationError;
    
    *outName = CFStringCreateWithCString(kCFAllocatorDefault, 
                                        "1.1.0", 
                                        kCFStringEncodingUTF8);
    return noErr;
}

OSStatus VirtualDevice::GetZeroTimeStampPeriod(UInt32* outPeriod) const {
    if (!outPeriod) return kAudioHardwareIllegalOperationError;
    
    // Zero latency for virtual device
    *outPeriod = 0;
    return noErr;
}

OSStatus VirtualDevice::GetIsRunning(Boolean* outIsRunning) const {
    if (!outIsRunning) return kAudioHardwareIllegalOperationError;
    
    *outIsRunning = isRunning_.load();
    return noErr;
}

OSStatus VirtualDevice::GetLatency(UInt32 inDirection, UInt32* outLatency) const {
    if (!outLatency) return kAudioHardwareIllegalOperationError;
    
    // Minimal latency for virtual device
    *outLatency = deviceType_ == DeviceType::TranscriptionInput ? 0 : 32; // Frames
    return noErr;
}

OSStatus VirtualDevice::GetStreamConfiguration(UInt32 inDirection, AudioBufferList** outBufferList) const {
    if (!outBufferList) return kAudioHardwareIllegalOperationError;
    
    // Allocate buffer list
    UInt32 bufferListSize = offsetof(AudioBufferList, mBuffers) + sizeof(AudioBuffer) * channelCount_;
    AudioBufferList* bufferList = static_cast<AudioBufferList*>(calloc(1, bufferListSize));
    
    if (!bufferList) {
        return kAudioHardwareNoMemoryError;
    }
    
    bufferList->mNumberBuffers = channelCount_;
    for (UInt32 i = 0; i < channelCount_; ++i) {
        bufferList->mBuffers[i].mNumberChannels = 1;
        bufferList->mBuffers[i].mDataByteSize = 0; // Size will be set during I/O
        bufferList->mBuffers[i].mData = nullptr;
    }
    
    *outBufferList = bufferList;
    return noErr;
}

OSStatus VirtualDevice::StartIO() {
    std::lock_guard<std::mutex> lock(deviceMutex_);
    
    if (isRunning_.load()) {
        return noErr; // Already running
    }
    
    // Initialize timing
    mach_timebase_info_data_t timebaseInfo;
    mach_timebase_info(&timebaseInfo);
    
    lastProcessedTime_.mFlags = kAudioTimeStampSampleTimeValid | kAudioTimeStampHostTimeValid;
    lastProcessedTime_.mSampleTime = 0;
    lastProcessedTime_.mHostTime = mach_absolute_time();
    
    isRunning_.store(true);
    frameCounter_.store(0);
    
    NSLog(@"✅ VirtualDevice started: %s", GetDeviceName().c_str());
    return noErr;
}

OSStatus VirtualDevice::StopIO() {
    std::lock_guard<std::mutex> lock(deviceMutex_);
    
    if (!isRunning_.load()) {
        return noErr; // Already stopped
    }
    
    isRunning_.store(false);
    
    NSLog(@"✅ VirtualDevice stopped: %s (processed %llu frames)", 
          GetDeviceName().c_str(), frameCounter_.load());
    return noErr;
}

OSStatus VirtualDevice::GetCurrentTime(AudioTimeStamp* outTime) const {
    if (!outTime) return kAudioHardwareIllegalOperationError;
    
    std::lock_guard<std::mutex> lock(deviceMutex_);
    *outTime = lastProcessedTime_;
    return noErr;
}

void VirtualDevice::SetAudioCallback(std::function<void(const AudioBufferList&, const AudioTimeStamp&)> callback) {
    std::lock_guard<std::mutex> lock(deviceMutex_);
    audioCallback_ = std::move(callback);
}

void VirtualDevice::FeedAudioData(const AudioBufferList& bufferList, const AudioTimeStamp& timeStamp) {
    if (!isRunning_.load()) {
        return;
    }
    
    // Process the audio buffer
    OSStatus result = ProcessAudioBuffer(bufferList, timeStamp);
    if (result != noErr) {
        NSLog(@"⚠️ VirtualDevice: Audio processing error %d for %s", 
              (int)result, GetDeviceName().c_str());
    }
}

void VirtualDevice::InitializeStreams() {
    // Create input stream for this device type
    try {
        auto inputStream = std::make_shared<aspl::Stream>(
            GetContext(),
            aspl::Direction::Input,
            aspl::StreamFormat{
                .sampleRate = sampleRate_,
                .formatID = kAudioFormatLinearPCM,
                .formatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
                .bytesPerPacket = sizeof(Float32) * channelCount_,
                .framesPerPacket = 1,
                .bytesPerFrame = sizeof(Float32) * channelCount_,
                .channelsPerFrame = channelCount_,
                .bitsPerChannel = 32
            }
        );
        
        AddStream(inputStream);
        
        NSLog(@"✅ VirtualDevice: Created input stream for %s", GetDeviceName().c_str());
        
    } catch (const std::exception& e) {
        NSLog(@"❌ VirtualDevice: Failed to create stream for %s: %s", 
              GetDeviceName().c_str(), e.what());
    }
}

OSStatus VirtualDevice::ProcessAudioBuffer(const AudioBufferList& bufferList, const AudioTimeStamp& timeStamp) {
    if (!isRunning_.load() || !audioCallback_) {
        return noErr;
    }
    
    // Update timing information
    {
        std::lock_guard<std::mutex> lock(deviceMutex_);
        lastProcessedTime_ = timeStamp;
        
        // Update frame counter
        if (bufferList.mNumberBuffers > 0) {
            UInt32 frameCount = bufferList.mBuffers[0].mDataByteSize / (sizeof(Float32) * channelCount_);
            frameCounter_.fetch_add(frameCount);
        }
    }
    
    // Call the audio callback
    try {
        audioCallback_(bufferList, timeStamp);
    } catch (const std::exception& e) {
        NSLog(@"❌ VirtualDevice: Audio callback exception for %s: %s", 
              GetDeviceName().c_str(), e.what());
        return kAudioHardwareUnspecifiedError;
    }
    
    return noErr;
}

std::string VirtualDevice::GetDeviceName() const {
    switch (deviceType_) {
        case DeviceType::TranscriptionInput:
            return "Prezefren Transcription";
        case DeviceType::PassthroughMirror:
            return "Prezefren Passthrough";
        case DeviceType::StereoLeft:
            return "Prezefren Left Channel";
        case DeviceType::StereoRight:
            return "Prezefren Right Channel";
        default:
            return "Prezefren Virtual Device";
    }
}

std::string VirtualDevice::GetDeviceUID() const {
    switch (deviceType_) {
        case DeviceType::TranscriptionInput:
            return "com.prezefren.virtualaudio.transcription";
        case DeviceType::PassthroughMirror:
            return "com.prezefren.virtualaudio.passthrough";
        case DeviceType::StereoLeft:
            return "com.prezefren.virtualaudio.left";
        case DeviceType::StereoRight:
            return "com.prezefren.virtualaudio.right";
        default:
            return "com.prezefren.virtualaudio.device";
    }
}

} // namespace Prezefren