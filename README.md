# Prezefren 🎤➡️🌍

**Free & Open Source Real-Time Voice Transcription & Translation for macOS**

Transform your voice into instant, floating subtitles with professional AI-powered transcription and translation. Completely free with no restrictions - if you have a Mac, you can use Prezefren.

[![Version](https://img.shields.io/badge/version-1.0.15-blue)](https://github.com/Martin-Atrin/Prezefren/releases)
[![Platform](https://img.shields.io/badge/platform-macOS%2012%2B-lightgrey)](https://developer.apple.com/macos)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Swift](https://img.shields.io/badge/swift-5.9-orange)](https://swift.org)

## ✨ What is Prezefren?

Prezefren is a **free and open source** native macOS application that provides **real-time voice transcription** with **floating subtitle windows** and **instant translation**. Perfect for international meetings, content creation, language learning, and accessibility needs.

## 💰 Completely Free

- ✅ **No Cost**: Download and use forever, completely free
- ✅ **No Subscriptions**: No monthly fees or hidden charges  
- ✅ **No Restrictions**: Full functionality available to everyone
- ✅ **Open Source**: MIT licensed - inspect, modify, contribute
- ✅ **Privacy Focused**: Works fully offline, no data collection

### 🎯 Key Features

- **🎤 Real-Time Transcription**: Advanced AI-powered speech recognition (Whisper)
- **🪟 Floating Subtitle Windows**: Always-on-top subtitles that work with any app
- **🌍 Instant Translation**: 10+ languages with Google Gemini API
- **🎧 Dual Audio Mode**: Stereo channel separation for advanced use cases
- **🎨 Professional Templates**: Pre-configured layouts for different scenarios
- **🛡️ Privacy-First**: Local transcription processing, optional cloud translation
- **⚡ Resource Efficient**: Optimized for long sessions with smart memory management

## 🚀 Quick Start

### Installation (2 minutes)
1. **Download** the latest [release](https://github.com/Martin-Atrin/Prezefren/releases)
2. **Open** `Prezefren-1.0.15.dmg`
3. **Drag** Prezefren to Applications
4. **Launch** and grant microphone permission

### First Use (30 seconds)
1. **Click** the microphone button
2. **Start speaking** - transcription appears instantly
3. **Add floating windows** from Windows tab
4. **Enable translation** (optional) in Translation tab

**That's it!** No configuration needed - works out of the box.

## 📱 Screenshots

### Main Interface
![Main Interface](docs/screenshots/main-interface.png)
*Modern card-based interface with Audio, Windows, and Translation tabs*

### Floating Subtitle Windows
![Floating Windows](docs/screenshots/floating-windows.png)
*Professional subtitle windows with customizable templates*

### Real-Time Translation
![Translation](docs/screenshots/translation-demo.png)
*Live translation with multiple language support*

## 🎯 Perfect For

### 🏢 **Business & Professional**
- **International meetings** with real-time translation
- **Presentation subtitles** for global audiences
- **Conference calls** with automatic transcription
- **Client meetings** with language barriers

### 📺 **Content Creation**
- **Live streaming** with multilingual subtitles
- **Video recording** with automated captions
- **Podcast production** with real-time transcripts
- **Educational content** in multiple languages

### 🎓 **Education & Learning**
- **Language learning** with instant translation
- **International classrooms** with live subtitles
- **Study sessions** with transcription notes
- **Academic conferences** with multilingual support

### ♿ **Accessibility**
- **Hearing assistance** with visual subtitles
- **Communication support** for diverse needs
- **Text-based interaction** for speech difficulties
- **Large text display** for visual accessibility

## 🏗️ Architecture & Technology

### Core Technologies
- **Swift + SwiftUI**: Native macOS performance and design
- **OpenAI Whisper**: State-of-the-art speech recognition (base.en model included)
- **Google Gemini API**: High-quality translation services
- **Core Audio**: Real-time audio processing with hardware acceleration
- **NSPanel**: Professional floating window system

### Advanced Features
- **Dual Audio Processing**: Independent left/right channel transcription
- **Smart Memory Management**: Efficient resource usage for long sessions
- **Thread-Safe Architecture**: Stable multi-window operation
- **Enhanced Translation Engine**: Toggle-based advanced features
- **Professional UI**: Modern card-based interface inspired by best practices

### Privacy & Security
- **Local Processing**: Voice transcription happens on your Mac
- **Optional Cloud**: Translation services only when enabled
- **No Telemetry**: Your conversations stay completely private
- **Open Source**: Full transparency and community development

## 📊 System Requirements

### Minimum
- **macOS**: 12.0 (Monterey) or later
- **Processor**: Apple Silicon or Intel (64-bit)
- **Memory**: 4 GB RAM
- **Storage**: 500 MB available space
- **Audio**: Microphone (built-in or external)

### Recommended
- **macOS**: 13.0 (Ventura) or later
- **Processor**: Apple Silicon (M1/M2) for optimal performance
- **Memory**: 8 GB RAM or more
- **Storage**: 1 GB available space
- **Audio**: High-quality external microphone
- **Network**: Internet connection for translation services

## 🌍 Supported Languages

### Transcription
- **English** (optimized with bundled Whisper base.en model)
- Additional languages available with model switching (future feature)

### Translation
- **English** ↔ Spanish, French, German, Chinese
- **Japanese**, Korean, Portuguese, Italian, Russian
- **200+ languages** with local NLLB model (experimental)

## 📖 Documentation

- **[Installation Guide](docs/INSTALLATION.md)** - Complete setup instructions
- **[User Guide](docs/USER_GUIDE.md)** - Detailed feature documentation
- **[Developer Documentation](docs/DEVELOPMENT.md)** - Technical details and API reference
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions

## 🛠️ Development

### Building from Source
```bash
# Clone the repository
git clone https://github.com/Martin-Atrin/Prezefren.git
cd Prezefren/Prezefren_app

# Install dependencies (Whisper.cpp)
cd Vendor/whisper.cpp && make && cd ../..

# Build the application
./build_distribution.sh debug

# Run the app
open build/Prezefren.app
```

### Project Structure
```
Prezefren_app/
├── Core/                   # Core business logic
│   ├── Models/            # Data models and state management
│   ├── Engine/            # Audio processing and AI integration
│   └── Services/          # Translation and external services
├── UI/                    # User interface
│   ├── Views/            # SwiftUI views and components
│   └── Windows/          # Floating window management
├── Vendor/               # Third-party dependencies
│   └── whisper.cpp/     # Speech recognition engine
├── scripts/              # Build and distribution scripts
└── docs/                 # Documentation and guides
```

### Contributing
We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

#### Ways to Contribute
- 🐛 **Bug Reports**: Report issues on GitHub
- 💡 **Feature Requests**: Suggest new capabilities
- 🔧 **Code Contributions**: Submit pull requests
- 📚 **Documentation**: Improve guides and tutorials
- 🌍 **Translations**: Help localize the interface
- 🧪 **Testing**: Help test new features and releases

## 📈 Performance

### Transcription Performance
- **Latency**: < 500ms end-to-end processing
- **Accuracy**: 90-95% for clear speech
- **Throughput**: Real-time continuous processing
- **Resource Usage**: < 5% CPU, ~150MB RAM

### Translation Performance
- **Cloud Translation**: ~500ms average latency
- **Local Translation**: < 100ms (when enabled)
- **Supported Pairs**: 100+ language combinations
- **Accuracy**: Professional-grade translation quality

## 🗂️ Releases

### Current Release: v1.0.15
- ✅ Real-time voice transcription with Whisper base.en
- ✅ Floating subtitle windows with professional templates
- ✅ Instant translation with Google Gemini API
- ✅ Dual audio mode with stereo channel separation
- ✅ Enhanced translation engine with toggle-based features
- ✅ Complete distribution system with DMG installer

### Download Options
- **[Prezefren-1.0.15.dmg](https://github.com/Martin-Atrin/Prezefren/releases/download/v1.0.15/Prezefren-1.0.15.dmg)** (133 MB) - Professional installer
- **[Prezefren-1.0.15.zip](https://github.com/Martin-Atrin/Prezefren/releases/download/v1.0.15/Prezefren-1.0.15.zip)** (136 MB) - App bundle archive

### Checksums
```
SHA256 Checksums:
06dfcb1b2cb0b569be056f1eb7c515173dce276a0ffc9e18a3139dd89251a8fd  Prezefren-1.0.15.dmg
b9e807df304e2e9002790eae3916bce033c4022ca0d2b1ffe41b1cd1dbf16cf7  Prezefren-1.0.15.zip
```

## 🚧 Roadmap

### Version 1.1 (Coming Soon)
- [ ] **Local NLLB Translation**: Meta's No Language Left Behind model integration
- [ ] **Whisper Model Selection**: Choose between tiny, base, small, medium models
- [ ] **Advanced Language Detection**: Automatic source language identification
- [ ] **Enhanced UI**: Improved window customization and themes

### Version 1.2 (Future)
- [ ] **Video File Processing**: Batch transcription and translation
- [ ] **Export Features**: Save transcriptions in various formats
- [ ] **Plugin System**: Extensible architecture for third-party integrations
- [ ] **Mobile Companion**: iOS/iPadOS remote control app

### Version 2.0 (Long-term)
- [ ] **AI-Powered Context**: Smart transcription with context awareness
- [ ] **Multi-Modal Translation**: Text + speech + visual translation
- [ ] **Enterprise Features**: Team management and advanced analytics
- [ ] **Cloud Sync**: Cross-device transcription history

## 🤝 Community & Support

### Getting Help
- **📖 Documentation**: Comprehensive guides and tutorials
- **🐛 GitHub Issues**: [Report bugs and request features](https://github.com/Martin-Atrin/Prezefren/issues)
- **💬 Discussions**: [Community discussions and Q&A](https://github.com/Martin-Atrin/Prezefren/discussions)
- **📧 Email**: Support and questions

### Community Guidelines
We're committed to maintaining a welcoming, inclusive community. Please read our [Code of Conduct](CODE_OF_CONDUCT.md).

## 📄 License

Prezefren is licensed under the [MIT License](LICENSE) - see the LICENSE file for details.

### Third-Party Licenses
This project uses several open-source libraries:
- **OpenAI Whisper**: MIT License
- **SwiftUI**: Apple Developer Agreement
- **Google Gemini API**: Google API Terms of Service

See [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) for complete attribution.

## 🙏 Acknowledgments

Special thanks to:
- **OpenAI** for the incredible Whisper speech recognition models
- **Google** for providing accessible translation APIs
- **Apple** for the excellent SwiftUI framework and development tools
- **Open Source Community** for inspiration, feedback, and contributions
- **Beta Testers** who helped refine and improve Prezefren

---

<div align="center">

**[Download Now - 100% Free](https://github.com/Martin-Atrin/Prezefren/releases) | [Documentation](docs/) | [Community](https://github.com/Martin-Atrin/Prezefren/discussions) | [Support](https://github.com/Martin-Atrin/Prezefren/issues)**

### 🎉 **Always Free & Open Source**
**No subscriptions. No limitations. No restrictions.**  
If you have a Mac, you can use Prezefren - forever.

Made with ❤️ for the global community

**Breaking language barriers, one conversation at a time.**

## 📄 License & Attribution

- **Prezefren**: MIT License © 2025 Prezefren Contributors
- **Whisper.cpp**: MIT License © 2023-2024 The ggml authors  
- **OpenAI Whisper Models**: MIT License © 2022 OpenAI

</div>