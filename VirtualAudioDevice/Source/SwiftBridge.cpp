#include "../Headers/VirtualAudioIntegration.h"
#include <AVFoundation/AVFoundation.h>

// C interface for Swift integration
extern "C" {

/**
 * @brief Statistics structure for Swift bridge
 */
struct VirtualAudioStatistics {
    bool virtualAudioActive;
    uint64_t buffersProcessed;
    double averageLatency;
    bool hasErrors;
};

/**
 * @brief Create virtual audio integration instance
 */
void* createVirtualAudioIntegration(
    bool enabled,
    bool useForTranscription,
    bool useForPassthrough,
    bool enableStereoSeparation,
    bool enableLowLatencyMode,
    bool enableStatistics,
    bool fallbackToCurrentSystem
) {
    try {
        VirtualAudioIntegration::Config config;
        config.enabled = enabled;
        config.useForTranscription = useForTranscription;
        config.useForPassthrough = useForPassthrough;
        config.enableStereoSeparation = enableStereoSeparation;
        config.enableLowLatencyMode = enableLowLatencyMode;
        config.enableStatistics = enableStatistics;
        config.fallbackToCurrentSystem = fallbackToCurrentSystem;
        
        auto integration = CreateVirtualAudioIntegration(config);
        
        if (integration) {
            // Return raw pointer for C interface (Swift will manage lifetime)
            return integration.release();
        } else {
            NSLog(@"❌ createVirtualAudioIntegration: Failed to create integration");
            return nullptr;
        }
        
    } catch (const std::exception& e) {
        NSLog(@"❌ createVirtualAudioIntegration: Exception: %s", e.what());
        return nullptr;
    }
}

/**
 * @brief Destroy virtual audio integration instance
 */
void destroyVirtualAudioIntegration(void* integration) {
    if (integration) {
        try {
            delete static_cast<VirtualAudioIntegration*>(integration);
        } catch (const std::exception& e) {
            NSLog(@"❌ destroyVirtualAudioIntegration: Exception: %s", e.what());
        }
    }
}

/**
 * @brief Process audio buffer through virtual audio system
 */
bool processAudioBufferC(void* integration, AVAudioPCMBuffer* buffer, AudioTimeStamp timeStamp) {
    if (!integration || !buffer) {
        return false;
    }
    
    try {
        auto* virtualAudio = static_cast<VirtualAudioIntegration*>(integration);
        return virtualAudio->ProcessAudioBuffer(buffer, timeStamp);
        
    } catch (const std::exception& e) {
        NSLog(@"❌ processAudioBufferC: Exception: %s", e.what());
        return false;
    }
}

/**
 * @brief Callback storage for transcription
 */
static std::function<void(AVAudioPCMBuffer*, const AudioTimeStamp&)> g_transcriptionCallback;

/**
 * @brief Set transcription callback
 */
void setTranscriptionCallbackC(void* integration, void(*callback)(AVAudioPCMBuffer*, AudioTimeStamp)) {
    if (!integration) {
        return;
    }
    
    try {
        auto* virtualAudio = static_cast<VirtualAudioIntegration*>(integration);
        
        if (callback) {
            g_transcriptionCallback = [callback](AVAudioPCMBuffer* buffer, const AudioTimeStamp& timeStamp) {
                callback(buffer, timeStamp);
            };
            virtualAudio->SetTranscriptionCallback(g_transcriptionCallback);
        } else {
            g_transcriptionCallback = nullptr;
            virtualAudio->SetTranscriptionCallback(nullptr);
        }
        
    } catch (const std::exception& e) {
        NSLog(@"❌ setTranscriptionCallbackC: Exception: %s", e.what());
    }
}

/**
 * @brief Callback storage for passthrough
 */
static std::function<void(AVAudioPCMBuffer*, const AudioTimeStamp&)> g_passthroughCallback;

/**
 * @brief Set passthrough callback
 */
void setPassthroughCallbackC(void* integration, void(*callback)(AVAudioPCMBuffer*, AudioTimeStamp)) {
    if (!integration) {
        return;
    }
    
    try {
        auto* virtualAudio = static_cast<VirtualAudioIntegration*>(integration);
        
        if (callback) {
            g_passthroughCallback = [callback](AVAudioPCMBuffer* buffer, const AudioTimeStamp& timeStamp) {
                callback(buffer, timeStamp);
            };
            virtualAudio->SetPassthroughCallback(g_passthroughCallback);
        } else {
            g_passthroughCallback = nullptr;
            virtualAudio->SetPassthroughCallback(nullptr);
        }
        
    } catch (const std::exception& e) {
        NSLog(@"❌ setPassthroughCallbackC: Exception: %s", e.what());
    }
}

/**
 * @brief Update configuration
 */
void updateConfigurationC(
    void* integration,
    bool enabled,
    bool useForTranscription,
    bool useForPassthrough,
    bool enableStereoSeparation,
    bool enableLowLatencyMode,
    bool enableStatistics,
    bool fallbackToCurrentSystem
) {
    if (!integration) {
        return;
    }
    
    try {
        auto* virtualAudio = static_cast<VirtualAudioIntegration*>(integration);
        
        VirtualAudioIntegration::Config config;
        config.enabled = enabled;
        config.useForTranscription = useForTranscription;
        config.useForPassthrough = useForPassthrough;
        config.enableStereoSeparation = enableStereoSeparation;
        config.enableLowLatencyMode = enableLowLatencyMode;
        config.enableStatistics = enableStatistics;
        config.fallbackToCurrentSystem = fallbackToCurrentSystem;
        
        virtualAudio->UpdateConfig(config);
        
    } catch (const std::exception& e) {
        NSLog(@"❌ updateConfigurationC: Exception: %s", e.what());
    }
}

/**
 * @brief Get statistics
 */
VirtualAudioStatistics getStatisticsC(void* integration) {
    VirtualAudioStatistics stats = {false, 0, 0.0, false};
    
    if (!integration) {
        return stats;
    }
    
    try {
        auto* virtualAudio = static_cast<VirtualAudioIntegration*>(integration);
        auto simpleStats = virtualAudio->GetStatistics();
        
        stats.virtualAudioActive = simpleStats.virtualAudioActive;
        stats.buffersProcessed = simpleStats.buffersProcessed;
        stats.averageLatency = simpleStats.averageLatency;
        stats.hasErrors = simpleStats.hasErrors;
        
    } catch (const std::exception& e) {
        NSLog(@"❌ getStatisticsC: Exception: %s", e.what());
        stats.hasErrors = true;
    }
    
    return stats;
}

} // extern "C"