# Prezefren Troubleshooting Guide

## 🔧 Quick Fixes

### 🚨 Most Common Issues

#### ❌ **No Audio Input / Not Recording**
**Symptoms**: Microphone button doesn't respond, no transcription appears
**Solutions**:
1. **Check microphone permission**:
   - System Preferences → Security & Privacy → Privacy → Microphone
   - Ensure Prezefren is checked ✅
2. **Verify microphone selection**:
   - System Preferences → Sound → Input
   - Select correct microphone device
3. **Restart Prezefren** after permission changes

#### ❌ **No Transcription Appearing**
**Symptoms**: Recording indicator active but no text appears
**Solutions**:
1. **Check AI model loading**:
   - Look for "Audio engine initialized successfully" in Console
   - If missing, restart app to reload Whisper model
2. **Verify audio levels**:
   - Speak louder or closer to microphone
   - Check input volume in System Preferences
3. **Test with clear speech**:
   - Use simple words first
   - Avoid background noise

#### ❌ **Translation Not Working**
**Symptoms**: Transcription works but translation doesn't appear
**Solutions**:
1. **Check API key configuration**:
   - Translation tab should show "✅ API key configured"
   - If red ❌, create `.env` file with `GEMINI_API_KEY=your_key`
2. **Verify internet connection** for cloud translation
3. **Enable translation** for specific windows in Windows tab

#### ❌ **Floating Windows Not Appearing**
**Symptoms**: Windows created but not visible on screen
**Solutions**:
1. **Check window visibility**:
   - Windows tab → click "Show" button
   - Verify windows aren't positioned off-screen
2. **Adjust window positioning**:
   - Use window templates to reset positions
   - Manually drag windows to visible area
3. **Check multiple monitors**:
   - Windows may appear on different displays

## 🎤 Audio & Recording Issues

### Microphone Problems

#### **Microphone Not Detected**
```
🔍 Diagnosis:
- System Preferences → Sound → Input
- Check if microphone appears in list

✅ Solutions:
1. Reconnect external microphone
2. Restart macOS audio service:
   sudo killall coreaudiod
3. Reset NVRAM/PRAM on Intel Macs
4. Try different USB port for external mics
```

#### **Poor Audio Quality**
```
🔍 Diagnosis:
- Low transcription accuracy
- Garbled or missing words

✅ Solutions:
1. Adjust input volume (not too high = distortion)
2. Reduce background noise
3. Position microphone 6-12 inches from mouth
4. Use headset microphone for better isolation
5. Check for competing audio applications
```

#### **Audio Cutting Out**
```
🔍 Diagnosis:
- Intermittent transcription
- Recording stops unexpectedly

✅ Solutions:
1. Close other audio applications
2. Reduce CPU load (quit unnecessary apps)
3. Check for USB power issues (external mics)
4. Disable audio enhancements in System Preferences
```

### Recording Issues

#### **Recording Starts But Stops Immediately**
```
🔍 Diagnosis:
- Permission issue or resource conflict

✅ Solutions:
1. Restart Prezefren completely
2. Check Activity Monitor for multiple Prezefren processes
3. Verify sufficient disk space (>500MB)
4. Reset microphone permissions:
   - System Preferences → Security → Privacy → Microphone
   - Uncheck Prezefren, restart, re-enable
```

#### **No Recording Indicator**
```
🔍 Diagnosis:
- UI not responding to audio input

✅ Solutions:
1. Force quit and restart Prezefren
2. Check Console app for error messages
3. Verify macOS version compatibility (12.0+)
4. Try launching from Terminal for debug output
```

## 🤖 AI & Transcription Issues

### Whisper Model Problems

#### **Model Loading Failed**
```
🔍 Symptoms:
- "Failed to initialize Whisper context" in Console
- No transcription despite audio input

✅ Solutions:
1. Verify model file exists:
   /Applications/Prezefren.app/Contents/Resources/ggml-base.en.bin
2. Re-download and reinstall Prezefren
3. Check available storage space (need ~150MB for model)
4. Repair app bundle:
   codesign --verify --deep /Applications/Prezefren.app
```

#### **Slow Transcription**
```
🔍 Symptoms:
- Long delay between speech and text
- System feels sluggish during use

✅ Solutions:
1. Close other CPU-intensive applications
2. Restart Prezefren to clear memory
3. Reduce number of active windows
4. Check Activity Monitor for high CPU usage
5. Consider using External power (laptops)
```

#### **Poor Transcription Accuracy**
```
🔍 Symptoms:
- Many incorrect words
- Missing phrases

✅ Solutions:
1. Speak more clearly and slower
2. Reduce background noise
3. Use better microphone
4. Avoid overlapping speech
5. Check microphone positioning
6. Try different acoustic environment
```

## 🌍 Translation Issues

### API Configuration

#### **API Key Not Working**
```
🔍 Diagnosis:
- "❌ No API key found" in Translation tab
- Translation requests failing

✅ Solutions:
1. Verify API key format (starts with "AI...")
2. Check .env file location:
   /Applications/Prezefren.app/Contents/MacOS/.env
3. Verify file contents:
   GEMINI_API_KEY=your_actual_key_here
4. No quotes around the key value
5. No extra spaces or characters
```

#### **Translation Rate Limiting**
```
🔍 Symptoms:
- "API limit reached" errors
- Intermittent translation failures

✅ Solutions:
1. Reduce translation frequency
2. Use shorter phrases
3. Wait for rate limit reset (1 minute)
4. Upgrade to paid API plan for higher limits
5. Enable local translation mode (when available)
```

### Translation Quality

#### **Incorrect Translations**
```
🔍 Symptoms:
- Wrong language output
- Nonsensical translations

✅ Solutions:
1. Verify source language setting
2. Check target language selection
3. Use shorter, clearer phrases
4. Avoid technical jargon initially
5. Verify API key has translation permissions
```

## 🪟 Window & UI Issues

### Floating Window Problems

#### **Windows Disappear**
```
🔍 Symptoms:
- Windows created but can't find them
- Windows appear then vanish

✅ Solutions:
1. Check window positioning:
   - May be off-screen on disconnected monitor
   - Use window templates to reset positions
2. Verify window settings:
   - Windows tab → check visibility toggles
   - Ensure windows aren't transparent (0% opacity)
3. Mission Control:
   - Use Mission Control to find hidden windows
```

#### **Windows Don't Stay on Top**
```
🔍 Symptoms:
- Subtitle windows get covered by other apps
- Windows disappear behind other content

✅ Solutions:
1. Restart Prezefren (refreshes window levels)
2. Check System Preferences for window management conflicts
3. Disable third-party window managers temporarily
4. Verify macOS accessibility permissions if needed
```

#### **Window Content Not Updating**
```
🔍 Symptoms:
- Windows visible but text doesn't change
- Frozen or stale content

✅ Solutions:
1. Check window channel assignment:
   - Windows tab → verify audio channel setting
   - Match window channel to active audio mode
2. Restart transcription (stop/start recording)
3. Force refresh by hiding/showing window
```

### UI Responsiveness

#### **App Becomes Unresponsive**
```
🔍 Symptoms:
- UI freezes or becomes slow
- Buttons don't respond

✅ Solutions:
1. Check memory usage in Activity Monitor
2. Force quit and restart Prezefren
3. Reduce number of active windows
4. Clear old transcription data (restart app)
5. Check for macOS updates
```

## ⚡ Performance Issues

### Memory Problems

#### **High Memory Usage**
```
🔍 Symptoms:
- Prezefren using >500MB RAM
- System slowdown during use

✅ Solutions:
1. Restart Prezefren periodically (every few hours)
2. Reduce number of active windows
3. Disable unused translation features
4. Use Simple mode instead of Additive for windows
5. Clear transcription history (restart app)
```

#### **Memory Leaks**
```
🔍 Symptoms:
- Memory usage continuously increases
- App becomes slower over time

✅ Solutions:
1. Close unused windows
2. Restart app after long sessions (>2 hours)
3. Disable experimental features
4. Report issue with memory usage details
```

### CPU Performance

#### **High CPU Usage**
```
🔍 Symptoms:
- Fan noise increases
- System becomes sluggish
- Battery drains quickly

✅ Solutions:
1. Reduce audio processing quality if option exists
2. Close other applications
3. Use mono instead of stereo mode
4. Reduce window update frequency
5. Check for background processes consuming CPU
```

## 🔍 Diagnostic Tools

### Built-in Diagnostics

#### **Console Output**
```bash
# View Prezefren logs in Console.app
1. Open Console.app
2. Filter for "Prezefren"
3. Look for error messages or warnings
4. Common useful messages:
   - "Audio engine initialized successfully"
   - "Using bundle resource model"
   - Translation API responses
```

#### **Activity Monitor**
```bash
# Check resource usage
1. Open Activity Monitor
2. Find "Prezefren" process
3. Monitor:
   - CPU usage (should be <10% normally)
   - Memory usage (should be <300MB normally)
   - Energy impact (should be low-medium)
```

### Terminal Diagnostics

#### **Launch from Terminal**
```bash
# Get detailed debug output
cd /Applications/Prezefren.app/Contents/MacOS
./Prezefren

# Look for:
- Model loading messages
- Audio initialization
- Permission grants
- Error stack traces
```

#### **Check File Integrity**
```bash
# Verify app bundle
codesign --verify --deep /Applications/Prezefren.app
spctl -a -v /Applications/Prezefren.app

# Check model file
ls -la /Applications/Prezefren.app/Contents/Resources/ggml-base.en.bin
# Should be ~147MB

# Check frameworks
ls -la /Applications/Prezefren.app/Contents/Frameworks/
# Should contain libwhisper.dylib, libggml*.dylib
```

## 📋 Reporting Issues

### Information to Include

When reporting issues, please provide:

#### **System Information**
```
- macOS version (About This Mac)
- Hardware model (Mac type, year)
- Available RAM and storage
- Audio hardware (built-in vs external mic)
```

#### **Prezefren Information**
```
- App version (About Prezefren)
- Installation method (DMG vs ZIP)
- Configuration used (audio mode, windows, etc.)
- Console output (relevant error messages)
```

#### **Reproduction Steps**
```
1. Exact steps to reproduce the issue
2. Expected behavior
3. Actual behavior
4. Frequency (always, sometimes, rare)
```

### Where to Report
- **GitHub Issues**: [Report bugs](https://github.com/Martin-Atrin/Prezefren/issues)
- **Feature Requests**: [Suggest improvements](https://github.com/Martin-Atrin/Prezefren/discussions)
- **Security Issues**: Contact maintainers directly

## 🆘 Emergency Fixes

### Complete Reset

If all else fails, try a complete reset:

```bash
# 1. Quit Prezefren completely
killall Prezefren

# 2. Remove preferences (optional)
rm -rf ~/Library/Preferences/com.prezefren.app.plist
rm -rf ~/Library/Application\ Support/Prezefren

# 3. Reset microphone permissions
# System Preferences → Security & Privacy → Privacy → Microphone
# Uncheck Prezefren, restart system, re-enable

# 4. Reinstall Prezefren
# Download fresh copy from GitHub releases
# Replace existing app in Applications
```

### Safe Mode Testing

Test Prezefren with minimal configuration:
1. **Single window only** (remove others)
2. **Mono audio mode** (disable stereo)
3. **No translation** (disable all translation features)
4. **Default settings** (avoid customizations)

If issues persist in safe mode, report as critical bug.

---

## 💡 Prevention Tips

### Best Practices
- **Restart regularly** for long sessions (every 2-3 hours)
- **Monitor resource usage** in Activity Monitor
- **Keep macOS updated** for compatibility
- **Use quality hardware** (good microphone, sufficient RAM)
- **Backup configurations** before major changes

### Early Warning Signs
- Increasing memory usage over time
- Slower UI response
- Audio quality degradation
- Translation delays increasing

**Address these early to prevent major issues!**

---

**Still having trouble?** [Open an issue](https://github.com/Martin-Atrin/Prezefren/issues) with detailed information and we'll help you get Prezefren working perfectly! 🚀