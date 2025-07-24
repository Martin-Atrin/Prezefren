# Contributing to Prezefren

Thank you for considering contributing to Prezefren! This document provides guidelines for contributing to this open-source real-time voice transcription and translation application.

## 🤝 How to Contribute

### 🐛 Bug Reports
1. **Search existing issues** first to avoid duplicates
2. **Use the bug report template** when creating new issues
3. **Include system information**: macOS version, hardware, Prezefren version
4. **Provide reproduction steps** with expected vs actual behavior
5. **Include console output** and error messages when relevant

### 💡 Feature Requests
1. **Check the roadmap** in README.md to see if already planned
2. **Use the feature request template** for new suggestions
3. **Explain the use case** and why it would benefit users
4. **Consider implementation complexity** and maintenance burden

### 🔧 Code Contributions

#### Development Setup
```bash
# Clone the repository
git clone https://github.com/Martin-Atrin/Prezefren.git
cd Prezefren/Prezefren_app

# Install Whisper.cpp dependencies
cd Vendor/whisper.cpp && make && cd ../..

# Download Whisper model
curl -L -o ggml-base.en.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin

# Build and test
./build_distribution.sh debug
open build/Prezefren.app
```

#### Code Guidelines
- **Swift Style**: Follow Swift API Design Guidelines
- **SwiftUI**: Use native SwiftUI patterns and components
- **Documentation**: Comment complex logic and public APIs
- **Testing**: Test changes thoroughly before submitting
- **Performance**: Maintain resource efficiency and memory management

#### Pull Request Process
1. **Fork the repository** and create a feature branch
2. **Make focused changes** - one feature/fix per PR
3. **Test thoroughly** on different macOS versions if possible
4. **Update documentation** if adding new features
5. **Write clear commit messages** following conventional commits
6. **Submit PR** with detailed description of changes

### 📚 Documentation
- **User guides**: Improve clarity and add missing information
- **API documentation**: Document public interfaces and methods
- **Troubleshooting**: Add solutions for new issues discovered
- **Examples**: Provide usage examples and tutorials

## 🎯 Development Focus Areas

### High Priority
- **Performance optimization** - memory usage, CPU efficiency
- **Bug fixes** - stability issues, edge cases
- **Accessibility** - VoiceOver support, keyboard navigation
- **Translation accuracy** - language support improvements

### Medium Priority
- **New features** - additional window templates, audio modes
- **UI enhancements** - visual improvements, user experience
- **Advanced features** - local models, batch processing
- **Platform support** - additional macOS versions

### Future Considerations
- **iOS companion app** - remote control functionality
- **Plugin system** - extensible architecture
- **Enterprise features** - team management, analytics
- **Advanced AI** - context awareness, speaker diarization

## 🏗️ Architecture Guidelines

### Core Principles
1. **Native Performance**: Leverage Swift and SwiftUI for optimal macOS integration
2. **Resource Efficiency**: Maintain low memory and CPU usage for long sessions
3. **Thread Safety**: Use actors and proper synchronization for audio processing
4. **Privacy First**: Local processing by default, optional cloud services
5. **User Control**: Feature toggles and configuration options

### Technical Standards
- **Minimum Target**: macOS 12.0 (Monterey)
- **Swift Version**: 5.9+
- **Dependencies**: Minimize external dependencies, prefer system frameworks
- **Build System**: CLI-based with swiftc for rapid iteration
- **Code Signing**: Proper entitlements for microphone and network access

### File Organization
```
Prezefren_app/
├── Core/                   # Business logic
│   ├── Models/            # Data models, state management
│   ├── Engine/            # Audio processing, AI integration
│   └── Services/          # External services, networking
├── UI/                    # User interface
│   ├── Views/            # SwiftUI views and components
│   └── Windows/          # Floating window management
├── Vendor/               # Third-party dependencies
└── docs/                 # Documentation
```

## 🔍 Code Review Guidelines

### What We Look For
- **Functionality**: Does the code work as intended?
- **Performance**: Any memory leaks or inefficient operations?
- **Safety**: Thread safety and proper error handling?
- **Style**: Consistent with existing codebase?
- **Documentation**: Clear comments and updated docs?

### Review Process
1. **Automated checks** must pass (build, basic tests)
2. **Maintainer review** for technical correctness
3. **User testing** for significant UI/UX changes
4. **Documentation review** for feature additions
5. **Final approval** and merge

## 🚀 Release Process

### Version Numbering
- **Major (X.0.0)**: Breaking changes, major features
- **Minor (1.X.0)**: New features, enhancements
- **Patch (1.0.X)**: Bug fixes, minor improvements

### Release Criteria
- [ ] All tests passing
- [ ] Documentation updated
- [ ] Performance benchmarks maintained
- [ ] Security review completed
- [ ] User testing feedback incorporated

## 📋 Issue Templates

### Bug Report Template
```markdown
**Describe the bug**
A clear description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. See error

**Expected behavior**
What you expected to happen.

**System Information**
- macOS version:
- Prezefren version:
- Hardware model:
- Audio hardware:

**Console Output**
Include relevant error messages from Console.app
```

### Feature Request Template
```markdown
**Is your feature request related to a problem?**
A clear description of what the problem is.

**Describe the solution you'd like**
A clear description of what you want to happen.

**Describe alternatives you've considered**
Other solutions or features you've considered.

**Use case**
How would this feature be used? Who would benefit?

**Implementation considerations**
Any thoughts on how this might be implemented?
```

## 💬 Communication

### Channels
- **GitHub Issues**: Bug reports, feature requests
- **GitHub Discussions**: General questions, ideas, showcase
- **Pull Requests**: Code contributions and reviews
- **Email**: Security issues, private matters

### Guidelines
- **Be respectful** and constructive in all interactions
- **Stay on topic** and provide helpful information
- **Search before posting** to avoid duplicates
- **Use clear titles** and detailed descriptions
- **Tag appropriately** for better organization

## 🏆 Recognition

### Contributors
All contributors will be recognized in:
- **README.md acknowledgments** section
- **Release notes** for significant contributions
- **Contributor graphs** on GitHub
- **Special recognition** for major features

### Types of Contributions
- **Code**: Bug fixes, features, performance improvements
- **Documentation**: Guides, tutorials, API docs
- **Testing**: Bug reports, user testing, QA
- **Design**: UI/UX improvements, icons, assets
- **Community**: Support, moderation, advocacy

## 📜 Code of Conduct

### Our Pledge
We pledge to make participation in our project a harassment-free experience for everyone, regardless of age, body size, visible or invisible disability, ethnicity, sex characteristics, gender identity and expression, level of experience, education, socio-economic status, nationality, personal appearance, race, religion, or sexual identity and orientation.

### Our Standards
**Positive behavior includes:**
- Using welcoming and inclusive language
- Being respectful of differing viewpoints and experiences
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

**Unacceptable behavior includes:**
- Trolling, insulting/derogatory comments, and personal or political attacks
- Public or private harassment
- Publishing others' private information without explicit permission
- Other conduct which could reasonably be considered inappropriate

### Enforcement
Project maintainers are responsible for clarifying standards and will take appropriate action in response to any behavior that they deem inappropriate, threatening, offensive, or harmful.

## 📞 Contact

- **Project Maintainers**: GitHub @Hangry-eggplant
- **Security Issues**: Create private security advisory on GitHub
- **General Questions**: GitHub Discussions
- **Bug Reports**: GitHub Issues

---

Thank you for contributing to Prezefren! Together we can break down language barriers and make communication accessible to everyone. 🌍🎤