# Prezefren Installation Guide

## 🚀 Quick Installation (Recommended)

### Download & Install
1. **Download** the latest release from [GitHub Releases](https://github.com/Martin-Atrin/Prezefren/releases)
2. **Choose your format**:
   - `Prezefren-1.0.15.dmg` - Professional installer (recommended)
   - `Prezefren-1.0.15.zip` - App bundle archive

### DMG Installation (macOS)
1. **Open** the downloaded `Prezefren-1.0.15.dmg` file
2. **Drag** Prezefren.app to the Applications folder
3. **Eject** the DMG when complete
4. **Launch** Prezefren from Applications or Launchpad

### ZIP Installation (Alternative)
1. **Extract** the downloaded `Prezefren-1.0.15.zip` file
2. **Move** Prezefren.app to Applications folder
3. **Launch** from Applications or Launchpad

## 🔐 First Launch Setup

### 1. Security & Permissions
When you first launch Prezefren, macOS will request permissions:

#### Microphone Permission (Required)
- **Prompt**: "Prezefren would like to access your microphone"
- **Action**: Click **"OK"** or **"Allow"**
- **Purpose**: Required for voice transcription

#### Gatekeeper Warning (Possible)
If you see "Prezefren can't be opened because it's from an unidentified developer":
1. **Right-click** on Prezefren.app
2. Select **"Open"**
3. Click **"Open"** in the confirmation dialog
4. App will launch and be trusted for future opens

### 2. Initial Configuration
On first launch, Prezefren automatically:
- ✅ **Loads AI model** (Whisper base.en - bundled)
- ✅ **Initializes audio engine** 
- ✅ **Sets up default configuration**
- ✅ **Creates sample window templates**

No additional setup required - you can start transcribing immediately!

## 🌍 Optional: Translation Setup

Translation is **optional** but enhances Prezefren's capabilities:

### 1. Get Free API Key
1. Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with Google account
3. Click **"Create API key"**
4. Copy the generated key

### 2. Configure API Key
Create a `.env` file in your Prezefren app directory:

#### Option A: Manual Setup
1. Open **Terminal**
2. Navigate to Prezefren:
   ```bash
   cd /Applications/Prezefren.app/Contents/MacOS
   ```
3. Create `.env` file:
   ```bash
   echo "GEMINI_API_KEY=your_key_here" > .env
   ```

#### Option B: Text Editor
1. Open **TextEdit** or any text editor
2. Create new file with content:
   ```
   GEMINI_API_KEY=your_api_key_here
   ```
3. Save as `.env` in `/Applications/Prezefren.app/Contents/MacOS/`

### 3. Verify Translation Setup
1. Launch Prezefren
2. Go to **Translation tab**
3. Look for **green checkmark** in API Configuration
4. If configured correctly, you'll see "✅ API key configured"

## 🔧 System Requirements

### Minimum Requirements
- **macOS**: 12.0 (Monterey) or later
- **Processor**: Apple Silicon or Intel (64-bit)
- **Memory**: 4 GB RAM
- **Storage**: 500 MB available space
- **Audio**: Built-in or external microphone

### Recommended Requirements
- **macOS**: 13.0 (Ventura) or later
- **Processor**: Apple Silicon (M1/M2) for best performance
- **Memory**: 8 GB RAM or more
- **Storage**: 1 GB available space
- **Audio**: High-quality external microphone
- **Network**: Internet connection for translation services

### Supported Devices
- **MacBook Air** (2018 or later)
- **MacBook Pro** (2018 or later)  
- **iMac** (2019 or later)
- **iMac Pro** (all models)
- **Mac Pro** (2019 or later)
- **Mac Studio** (all models)
- **Mac mini** (2018 or later)

## 🧪 Verification & Testing

### 1. Installation Verification
Use the included verification script:
```bash
# Download and run verification script
curl -O https://github.com/Martin-Atrin/Prezefren/releases/download/v1.0.15/verify_installation.sh
chmod +x verify_installation.sh
./verify_installation.sh
```

Expected output:
```
✅ Prezefren.app found in Applications
✅ Code signature valid
✅ Executable found
✅ Whisper model found
✅ Required frameworks found
🚀 Installation verification complete!
```

### 2. Functionality Test
1. **Launch** Prezefren
2. **Click** microphone button in Audio tab
3. **Speak** a few words
4. **Verify** transcription appears in real-time
5. **Stop** recording - you're ready to go!

## 🚨 Troubleshooting Installation

### Common Issues

#### ❌ **"Prezefren is damaged and can't be opened"**
**Cause**: Gatekeeper restriction or corrupted download
**Solution**:
1. Delete the app from Applications
2. Re-download from official GitHub releases
3. Verify download integrity with checksums
4. Try the "Right-click → Open" method

#### ❌ **Microphone Permission Denied**
**Cause**: macOS privacy settings
**Solution**:
1. Go to **System Preferences → Security & Privacy → Privacy**
2. Select **Microphone** in left sidebar
3. Check the box next to **Prezefren**
4. Restart Prezefren

#### ❌ **"No Whisper model found"**
**Cause**: Incomplete installation or corrupted app bundle
**Solution**:
1. Re-download and reinstall from DMG
2. Verify app bundle integrity
3. Check available disk space (need 500MB+)

#### ❌ **Poor Audio Quality**
**Cause**: System audio settings or hardware
**Solution**:
1. Check **System Preferences → Sound → Input**
2. Select correct microphone
3. Adjust input volume levels
4. Test with different microphone if available

#### ❌ **App Won't Launch**
**Cause**: System compatibility or permissions
**Solution**:
1. Verify macOS version (12.0+ required)
2. Check system architecture (64-bit required)
3. Try launching from Terminal for error messages
4. Reset app permissions and try again

### Getting Help
If problems persist:
1. **Check Console**: Look for error messages in Console.app
2. **GitHub Issues**: [Report installation problems](https://github.com/Martin-Atrin/Prezefren/issues)
3. **System Info**: Include macOS version and hardware details
4. **Error Messages**: Copy exact error text when reporting

## 🔄 Updating Prezefren

### Automatic Updates (Future)
Future versions may include automatic update checking.

### Manual Updates (Current)
1. **Download** latest release from GitHub
2. **Quit** Prezefren completely
3. **Replace** old app with new version in Applications
4. **Launch** new version
5. **Verify** new features and functionality

### Update Verification
- Check **About Prezefren** for version number
- Verify new features are available
- Test core functionality after update

## 🗑️ Uninstalling Prezefren

### Complete Removal
1. **Quit** Prezefren
2. **Move to Trash**: Drag Prezefren.app from Applications to Trash
3. **Empty Trash**: Permanently remove

### Optional: Remove Preferences
```bash
# Remove user preferences (optional)
rm -rf ~/Library/Preferences/com.prezefren.app.plist
rm -rf ~/Library/Application\ Support/Prezefren
```

### Clean Uninstall Verification
- No Prezefren.app in Applications
- No related processes in Activity Monitor
- Microphone permission automatically removed from System Preferences

---

## ✅ Installation Complete!

You're now ready to use Prezefren for real-time voice transcription and translation. 

**Next Steps**:
1. Read the [User Guide](USER_GUIDE.md) for detailed usage instructions
2. Explore window templates and audio modes
3. Set up translation if desired
4. Start transcribing and enjoy!

**Happy transcribing!** 🎉