# PMD.md - Project Management Document
## Prezefren: Native macOS Transcription App

### Executive Summary
Prezefren is a resource-critical, native macOS application for real-time audio transcription with floating subtitle windows. Built as the successor to SubmAIvoice (Flutter) and Sub4Seas_beta1 (Swift), this iteration prioritizes stability, performance, and rapid CLI-based development.

### Technical Architecture
- **Platform**: Native macOS (Swift + SwiftUI)
- **Audio**: Core Audio (AVAudioEngine) with real-time capture
- **Transcription**: Whisper.cpp (base model) via C FFI
- **Windows**: NSPanel floating windows with thread-safe management
- **Translation**: Gemini 1.5 Flash API integration
- **Build**: CLI-based with `swiftc` for sub-10-second iteration

### Key Features
1. **Multiple Subtitle Windows**: Pre-recording setup with individual configurations
2. **Dual Display Modes**: Simple (current text) vs Additive (continuous flow)
3. **Dual Audio Sources**: Mono microphone + stereo channel separation
4. **Resource Management**: Smart text truncation and memory optimization
5. **Thread Safety**: Crash-free cleanup and state management

### Development Methodology
- **CLI-First**: Fast iteration with `./build.sh && ./build/Prezefren`
- **Resource Critical**: Lean codebase, essential files only
- **Work Orders**: Structured WE[#]WO[#] tracking with verification
- **Reference Integration**: Learn from Sub4Seas_beta1 and SubmAIvoice

### Current Status
**Phase**: Foundation Recovery (Post-Deletion Rebuild)
**Priority**: Core transcription + floating window functionality
**Next**: Whisper integration and basic translation

### Repository Structure
- **Core**: Business logic and audio engine
- **UI**: SwiftUI views and floating window management  
- **Vendor**: Third-party dependencies (excluded from git)
- **docs**: Work orders and project documentation

---
*This document tracks the overall project vision and progress for Prezefren development.*