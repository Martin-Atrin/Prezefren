# Prezefren Virtual Audio System v1.1.0

Professional virtual audio architecture for crystal-clear passthrough and optimized transcription processing.

## 🎯 **Goal: Professional Audio Routing**

Replace the current complex tap-based audio routing with a clean, professional virtual audio device system that provides:

- **Zero-loss passthrough audio** (native macOS routing)
- **Optimized transcription processing** (16kHz mono virtual device)
- **Stereo channel separation** (dual-language support)
- **Scalable architecture** (easy to add more transcription engines)

## 🏗️ **Architecture Overview**

```
Physical Input → [Audio Splitter] → Virtual Input 1 (Transcription @16kHz)
                                  → Virtual Input 2 (Passthrough @48kHz)  
                                  → Virtual Input 3 (Left Channel)
                                  → Virtual Input 4 (Right Channel)
```

### **Benefits over Current System:**
- ✅ **Native passthrough** - Zero audio quality degradation
- ✅ **Separated concerns** - Transcription independent of audio routing  
- ✅ **Professional grade** - Same approach as Loopback/BlackHole
- ✅ **Scalable** - Easy to add more transcription engines
- ✅ **System integration** - Devices appear in Audio MIDI Setup

## 🚀 **Quick Start**

### 1. Build Virtual Audio Plugin
```bash
cd VirtualAudioDevice
./build_virtual_audio.sh --install
```

### 2. Integrate with Existing AudioEngine
Add virtual audio as an **optional alternative route**:

```cpp
// In AudioEngine - completely optional
if PreferencesManager.shared.enableVirtualAudio {
    virtualAudio = CreateVirtualAudioIntegration()
    if virtualAudio.processBuffer(buffer) {
        return // Virtual audio handled it
    }
}
// Existing system continues unchanged
```

### 3. Add UI Controls
New preference card for enabling virtual audio system.

## 📁 **Project Structure**

```
VirtualAudioDevice/
├── Headers/
│   ├── PrezefrenVirtualDevice.h    # Virtual audio device implementation  
│   ├── AudioSplitter.h             # Splits audio to multiple destinations
│   ├── PrezefrenDriver.h           # Main driver for virtual audio system
│   └── VirtualAudioIntegration.h   # Lightweight integration with AudioEngine
├── Source/                         # Implementation files (C++)
├── Examples/
│   └── AudioEngineIntegration.md   # Integration guide
├── Build/                          # CMake build directory
├── CMakeLists.txt                  # Build configuration
├── build_virtual_audio.sh          # Build script
└── README.md                       # This file
```

## 🔧 **Technical Details**

### **Audio Server Plugin Approach**
- Uses traditional Core Audio HAL (not AudioDriverKit)
- Based on libASPL library for simplified development
- Same approach as BlackHole and other professional audio tools
- Installs to `/Library/Audio/Plug-Ins/HAL/`

### **Integration Strategy**
- **Non-disruptive**: Existing audio system continues to work
- **Optional**: Can be enabled/disabled in preferences  
- **Fallback**: Automatically falls back to current system if virtual audio fails
- **Modular**: Clean separation between old and new systems

### **Device Types**
1. **Transcription Device** - 16kHz mono optimized for speech recognition
2. **Passthrough Device** - 48kHz stereo for native quality routing
3. **Left Channel Device** - Stereo left channel for dual-language processing
4. **Right Channel Device** - Stereo right channel for dual-language processing

## 🎛️ **Configuration Options**

```cpp
VirtualAudioIntegration::Config {
    .enabled = false,                    // Master switch
    .useForTranscription = false,       // Route transcription through virtual device
    .useForPassthrough = false,         // Route passthrough through virtual device  
    .enableStereoSeparation = false,    // Enable L/R channel separation
    .fallbackToCurrentSystem = true     // Always fall back if virtual audio fails
}
```

## 🔄 **Migration Path**

### **Phase 1: Side-by-side (Current)**
- Virtual audio as optional alternative
- Both systems coexist
- Users choose which to use

### **Phase 2: Gradual Transition**  
- Virtual audio becomes default for new users
- Existing users can opt-in
- Traditional system remains as fallback

### **Phase 3: Full Professional**
- Virtual audio becomes primary system
- Traditional system only for compatibility
- Professional-grade audio routing throughout

## 🧪 **Testing**

### **Build and Test:**
```bash
# Build plugin
./build_virtual_audio.sh --debug

# Install to system
./build_virtual_audio.sh --install

# Check devices in Audio MIDI Setup
open "/Applications/Utilities/Audio MIDI Setup.app"
```

### **Integration Testing:**
1. Enable virtual audio in Prezefren preferences
2. Start recording - should see "Virtual Audio enabled" in logs
3. Test transcription quality and passthrough audio
4. Disable virtual audio - should fall back seamlessly

## 📊 **Performance Characteristics**

- **Latency**: Sub-10ms for real-time applications
- **CPU Usage**: Minimal overhead when disabled, optimized when enabled
- **Memory**: Efficient buffer management with automatic cleanup
- **Quality**: Native 32-bit float processing (same as macOS Core Audio)

## 🔧 **Development**

### **Dependencies:**
- macOS 12.0+
- Xcode 13+  
- CMake 3.20+
- libASPL (automatically downloaded)

### **Build System:**
- CMake-based build
- Universal binary (Intel + Apple Silicon)
- Automatic libASPL integration
- System plugin installation

## 🎵 **What This Enables**

### **Immediate Benefits:**
- Crystal clear passthrough audio (no quality loss)
- Optimized transcription processing  
- Professional audio routing

### **Future Possibilities:**
- Multiple transcription engines running simultaneously
- Language-specific audio routing
- Advanced audio effects and processing
- Integration with professional audio software
- Multi-user audio scenarios

## 🤝 **Contributing**

This virtual audio system is designed to be the foundation for professional-grade audio features in Prezefren v1.1.0+. The modular architecture makes it easy to add new features while maintaining compatibility with existing functionality.

---

**🎯 Result: Professional virtual audio routing that coexists with current system, providing a clean upgrade path to professional-grade audio processing.**