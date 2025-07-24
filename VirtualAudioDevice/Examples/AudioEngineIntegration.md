# Virtual Audio Integration Example

This document shows how to integrate the new Virtual Audio system with the existing AudioEngine as an **alternative route** that doesn't disrupt current functionality.

## Integration Approach

The virtual audio system is designed to be:
- **Optional**: Can be enabled/disabled via preferences
- **Non-disruptive**: Existing system continues to work if virtual audio fails
- **Modular**: Clean separation between old and new systems
- **Performance-conscious**: Minimal overhead when disabled

## Code Integration Example

### 1. Add Virtual Audio to AudioEngine Header

```cpp
// In AudioEngine.h
#include "../VirtualAudioDevice/Headers/VirtualAudioIntegration.h"

class AudioEngine {
private:
    // Existing members...
    
    // NEW: Virtual audio integration (optional)
    std::unique_ptr<VirtualAudioIntegration> virtualAudio_;
    bool useVirtualAudio_; // Preference setting
};
```

### 2. Initialize Virtual Audio in AudioEngine

```cpp
// In AudioEngine.swift or AudioEngine.cpp
func initialize() async {
    // Existing initialization...
    
    // NEW: Initialize virtual audio if enabled in preferences
    if PreferencesManager.shared.enableVirtualAudio {
        initializeVirtualAudio()
    }
}

private func initializeVirtualAudio() {
    let config = VirtualAudioIntegration::Config{
        .enabled = true,
        .useForTranscription = PreferencesManager.shared.useVirtualTranscription,
        .useForPassthrough = PreferencesManager.shared.useVirtualPassthrough,
        .enableStereoSeparation = PreferencesManager.shared.enableStereoSeparation,
        .fallbackToCurrentSystem = true // Always fall back if virtual audio fails
    };
    
    virtualAudio_ = CreateVirtualAudioIntegration(config);
    
    if (virtualAudio_ && virtualAudio_->IsEnabled()) {
        print("✅ Virtual Audio enabled - using professional audio routing")
        setupVirtualAudioCallbacks()
    } else {
        print("⚠️ Virtual Audio unavailable - using traditional audio routing")
        virtualAudio_.reset() // Clean up
    }
}
```

### 3. Modify Audio Processing Pipeline

```cpp
// In the existing audio tap processing method
private func processAudioBufferSync(_ buffer: AVAudioPCMBuffer, timeStamp: AudioTimeStamp) {
    // NEW: Try virtual audio first (if enabled)
    if let virtualAudio = virtualAudio_, 
       virtualAudio.processAudioBuffer(buffer, timeStamp: timeStamp) {
        // Virtual audio handled the processing - we're done!
        return
    }
    
    // EXISTING: Fall back to current system if virtual audio disabled/failed
    // Process with Whisper if enabled
    if transcriptionEngine == .whisper || transcriptionEngine == .both {
        // Existing Whisper processing...
    }
    
    // Process with Apple Speech if enabled  
    if transcriptionEngine == .appleSpeech || transcriptionEngine == .both {
        // Existing Apple Speech processing...
    }
    
    // Existing passthrough logic...
}
```

### 4. Add Preferences for Virtual Audio

```swift
// In PreferencesManager.swift
@Published var enableVirtualAudio: Bool = false
@Published var useVirtualTranscription: Bool = false
@Published var useVirtualPassthrough: Bool = false
@Published var enableStereoSeparation: Bool = false

// In PreferencesWindow.swift - Add new card
PreferenceCard(title: "Virtual Audio (Professional)", icon: "waveform.path.ecg", iconColor: .purple) {
    VStack(alignment: .leading, spacing: 12) {
        Toggle("Enable Virtual Audio System", isOn: $preferences.enableVirtualAudio)
            .help("Use professional virtual audio devices for better quality and performance")
        
        if preferences.enableVirtualAudio {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Virtual Transcription", isOn: $preferences.useVirtualTranscription)
                    .help("Route transcription through optimized virtual device")
                
                Toggle("Virtual Passthrough", isOn: $preferences.useVirtualPassthrough)
                    .help("Route passthrough through native virtual device for zero quality loss")
                
                Toggle("Stereo Channel Separation", isOn: $preferences.enableStereoSeparation)
                    .help("Create separate virtual devices for left/right channels")
            }
            .padding(.leading, 20)
        }
        
        HStack(spacing: 8) {
            Image(systemName: preferences.enableVirtualAudio ? "checkmark.circle.fill" : "info.circle")
                .foregroundColor(preferences.enableVirtualAudio ? .green : .blue)
            
            Text(preferences.enableVirtualAudio ? 
                 "Professional virtual audio routing enabled" : 
                 "Traditional audio routing (fallback mode)")
                .font(.caption)
                .foregroundColor(preferences.enableVirtualAudio ? .green : .blue)
        }
    }
}
```

## Benefits of This Approach

### 1. **Zero Risk**
- Existing system continues to work unchanged
- Virtual audio is purely additive
- Automatic fallback if virtual audio fails

### 2. **User Choice**
- Users can enable virtual audio for better quality
- Can be toggled on/off in preferences
- Different aspects can be enabled independently

### 3. **Performance**
- No overhead when virtual audio is disabled
- Professional-grade audio routing when enabled
- Better quality than current tap-based approach

### 4. **Future-Proof**
- Clean architecture for adding more virtual devices
- Easy to extend for multi-language scenarios
- Professional foundation for advanced features

## Migration Path

### Phase 1: Side-by-side (Current)
- Virtual audio as optional alternative
- Both systems can coexist
- Users choose which to use

### Phase 2: Gradual transition
- Virtual audio becomes default for new users
- Existing users can opt-in
- Traditional system remains as fallback

### Phase 3: Full transition
- Virtual audio becomes primary system
- Traditional system only for compatibility
- Professional-grade audio routing throughout

This approach ensures we can go professional without breaking existing functionality!