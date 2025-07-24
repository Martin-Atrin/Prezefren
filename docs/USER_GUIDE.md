# Prezefren User Guide

## 🎉 Welcome to Prezefren!

Prezefren is your powerful companion for real-time voice transcription and translation. Transform your voice into instant subtitles with floating windows that work with any application.

## 🚀 Quick Start (2 Minutes)

### 1. First Launch
1. **Open Prezefren** from Applications or Launchpad
2. **Grant microphone permission** when prompted (required for transcription)
3. The app will automatically initialize with the built-in AI model

### 2. Start Transcribing
1. Click the **microphone button** in the Audio tab
2. **Start speaking** - transcription appears instantly!
3. Click the microphone again to stop

### 3. Add Floating Windows
1. Go to the **Windows tab**
2. Click **"Add Window"** 
3. Choose a **template** (Top Banner, Side Panel, etc.)
4. Click **"Show"** to display the floating subtitle window

🎯 **That's it!** You're now transcribing speech in real-time with floating subtitles.

## 📱 Interface Overview

### Audio Tab
- **Live Transcription Preview**: See transcription in real-time
- **Audio Mode Selection**: Choose Mono or Stereo processing
- **Recording Controls**: Start/stop transcription with visual feedback

### Windows Tab  
- **Window Templates**: Pre-configured layouts for different use cases
- **Window Management**: Create, configure, and control floating windows
- **Batch Controls**: Show/hide all windows at once

### Translation Tab
- **API Configuration**: Set up translation services (optional)
- **Translation Engine**: Choose between different translation modes
- **Advanced Features**: Toggle experimental translation features

## 🪟 Floating Subtitle Windows

### Window Templates

#### 🎯 **Top Banner**
- **Best for**: Presentations, video calls
- **Position**: Top of screen, full width
- **Use case**: Unobtrusive subtitles that don't block content

#### 📱 **Side Panel** 
- **Best for**: Dual monitor setups, wide screens
- **Position**: Right side of screen
- **Use case**: Persistent subtitles alongside main content

#### 🖼️ **Picture-in-Picture**
- **Best for**: Streaming, recording
- **Position**: Corner overlay
- **Use case**: Compact subtitles over video content

#### 🎭 **Center Stage**
- **Best for**: Accessibility, large text needs
- **Position**: Center of screen
- **Use case**: Maximum visibility and readability

#### ⚙️ **Custom**
- **Best for**: Specific requirements
- **Position**: User-defined
- **Use case**: Tailored positioning and sizing

### Window Controls
- **👁️ Show/Hide**: Toggle window visibility
- **🔄 Mode**: Switch between Simple and Additive text
- **🌍 Translation**: Enable real-time translation
- **🎨 Opacity**: Adjust window transparency
- **📏 Position/Size**: Customize placement and dimensions

## 🎤 Audio Features

### Audio Modes

#### 🎵 **Mono Mode** (Default)
- **Input**: Single microphone
- **Processing**: Standard audio processing
- **Best for**: Most users, simple setup

#### 🎧 **Stereo Mode** (Advanced)
- **Input**: Left and right channels separately  
- **Processing**: Independent channel transcription
- **Best for**: Dual-language audio, professional setups

### Stereo Mode Use Cases
- **Dual-language earbuds**: English in left ear, Spanish in right
- **Multi-speaker scenarios**: Different speakers on different channels
- **Professional audio**: Advanced stereo separation

### Channel Assignment
In Stereo mode, assign windows to specific audio channels:
- **Mixed**: Combined left+right audio (default)
- **Left**: Only left channel audio
- **Right**: Only right channel audio

## 🌍 Translation Features

### Basic Translation Setup

#### 1. Get API Key (Free)
1. Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in and create a free API key
3. Create a `.env` file in Prezefren folder with:
   ```
   GEMINI_API_KEY=your_key_here
   ```

#### 2. Enable Translation
1. Go to **Windows tab**
2. Select a window and click **"Translation"**
3. Choose target language
4. Translation appears in real-time!

### Supported Languages
- **English** ↔ Spanish, French, German
- **Chinese**, Japanese, Korean
- **Portuguese**, Italian, Russian
- More languages available with API

### Translation Modes

#### 🌐 **Gemini API** (Default)
- **Quality**: High accuracy
- **Speed**: ~500ms latency
- **Languages**: 10+ supported
- **Requirement**: Internet connection

#### 🤖 **Local NLLB** (Experimental)
- **Quality**: Good accuracy
- **Speed**: Very fast
- **Languages**: 200+ supported
- **Requirement**: None (offline)
- **Status**: Toggle to enable (experimental)

#### 🔄 **Hybrid Mode**
- **Behavior**: Try local first, fallback to cloud
- **Best of**: Speed + reliability
- **Requirement**: Optional internet

## ⚙️ Advanced Features

### Window Text Modes

#### 📝 **Simple Mode**
- **Display**: Current transcription only
- **Updates**: Text replaces previous content
- **Best for**: Live subtitles, real-time display

#### 📚 **Additive Mode**  
- **Display**: Continuous text flow
- **Updates**: New text appends to history
- **Best for**: Meeting notes, continuous transcription

### Performance Optimization
- **Smart Memory Management**: Automatic text truncation
- **Resource Efficiency**: Optimized for long sessions
- **Thread Safety**: Stable multi-window operation

### Privacy & Security
- **Local Processing**: Voice transcription on your Mac
- **Optional Cloud**: Translation only when enabled
- **No Telemetry**: Your conversations stay private

## 🔧 Troubleshooting

### Common Issues

#### ❌ **No Audio Input**
- **Check**: Microphone permission granted
- **Fix**: System Preferences → Security → Privacy → Microphone
- **Verify**: Green recording indicator appears

#### ❌ **No Transcription**
- **Check**: AI model loaded successfully
- **Fix**: Restart app if model fails to load
- **Verify**: Console shows "Audio engine initialized"

#### ❌ **Translation Not Working**
- **Check**: API key configured in .env file
- **Check**: Internet connection for cloud translation
- **Fix**: Verify API key is valid

#### ❌ **Windows Not Appearing**
- **Check**: Window visibility enabled
- **Check**: Window positioned on visible screen
- **Fix**: Use window controls to reposition

#### ❌ **Poor Performance**
- **Reduce**: Number of active windows
- **Disable**: Unused translation features
- **Restart**: App if memory usage high

### Getting Help
- **Console Output**: Check for error messages
- **GitHub Issues**: Report bugs and feature requests
- **Documentation**: This guide and built-in help

## 🎯 Use Cases & Tips

### 🏢 **Business Meetings**
- **Setup**: Top Banner template with translation
- **Tip**: Use Additive mode for meeting notes
- **Pro**: Assign different languages to different windows

### 📺 **Content Creation**
- **Setup**: Picture-in-Picture template
- **Tip**: Position away from important content
- **Pro**: Use Simple mode for live subtitles

### 🎓 **Language Learning**
- **Setup**: Side Panel with translation enabled
- **Tip**: Compare original and translated text
- **Pro**: Use Stereo mode for dual-language audio

### ♿ **Accessibility**
- **Setup**: Center Stage template, large text
- **Tip**: Adjust opacity for better contrast
- **Pro**: Use Additive mode for text persistence

### 🎮 **Gaming & Streaming**
- **Setup**: Corner Picture-in-Picture
- **Tip**: Minimize window when not needed
- **Pro**: Quick keyboard shortcuts for control

## 🚀 Advanced Workflows

### Multi-Language Setup
1. Create multiple windows with different target languages
2. Enable translation for each window
3. Assign to different audio channels if needed
4. Position windows for optimal viewing

### Professional Recording
1. Use Additive mode for complete transcripts
2. Set up multiple windows for different audiences
3. Configure opacity to not interfere with recording
4. Save transcriptions for post-processing

### Accessibility Configuration
1. Use large, high-contrast windows
2. Position for comfortable reading
3. Enable text persistence with Additive mode
4. Adjust update rates for reading speed

## 💡 Tips & Best Practices

### 🎤 **Audio Quality**
- **Speak clearly** and at normal pace
- **Minimize background noise** when possible
- **Use good microphone** for better accuracy
- **Position microphone** appropriately

### 🪟 **Window Management**
- **Start small** - add windows as needed
- **Position strategically** - avoid blocking important content
- **Use templates** - they're optimized for common use cases
- **Adjust opacity** - balance visibility and transparency

### 🌍 **Translation Optimization**
- **Short phrases** translate more accurately
- **Clear pronunciation** improves translation quality
- **Context matters** - technical terms may need setup
- **Check translations** - especially for important content

### ⚡ **Performance**
- **Close unused windows** to save resources
- **Restart periodically** for long sessions
- **Monitor memory usage** in Activity Monitor
- **Use appropriate audio mode** (Mono vs Stereo)

---

## 🆘 Need More Help?

- **Built-in Help**: Check app's Help menu
- **GitHub Issues**: [Report problems](https://github.com/Martin-Atrin/Prezefren/issues)
- **Documentation**: Additional guides in docs/ folder
- **Community**: Connect with other users

**Happy transcribing with Prezefren!** 🎉