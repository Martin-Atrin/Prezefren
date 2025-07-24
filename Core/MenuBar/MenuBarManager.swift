import SwiftUI
import AppKit

// MARK: - Menu Bar Manager
// Handles native macOS menu bar integration and preferences window

@MainActor
class MenuBarManager: ObservableObject {
    static let shared = MenuBarManager()
    
    private var preferencesWindow: NSWindow?
    private let preferences = PreferencesManager.shared
    
    private init() {
        setupMenuBar()
        print("🍎 MenuBarManager initialized - native macOS menu integration")
    }
    
    // MARK: - Menu Bar Setup
    
    func setupMenuBar() {
        // Ensure we're on the main thread
        DispatchQueue.main.async { [weak self] in
            self?.createMenuBar()
        }
    }
    
    private func createMenuBar() {
        // Create the main menu if it doesn't exist
        if NSApp.mainMenu == nil {
            NSApp.mainMenu = NSMenu()
        }
        
        guard let mainMenu = NSApp.mainMenu else {
            print("❌ Could not create main menu")
            return
        }
        
        // Clear existing menus to start fresh
        mainMenu.removeAllItems()
        
        // Create the app menu (first menu item)
        let appMenu = NSMenu(title: "Prezefren")
        let appMenuItem = NSMenuItem(title: "Prezefren", action: nil, keyEquivalent: "")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // Add About item
        let aboutItem = NSMenuItem(title: "About Prezefren", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(aboutItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Add Preferences item (native shortcut Cmd+,)
        let preferencesItem = NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        appMenu.addItem(preferencesItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Add Translation submenu
        let translationMenu = createTranslationMenu()
        let translationMenuItem = NSMenuItem(title: "Translation", action: nil, keyEquivalent: "")
        translationMenuItem.submenu = translationMenu
        appMenu.addItem(translationMenuItem)
        
        // Add Audio submenu
        let audioMenu = createAudioMenu()
        let audioMenuItem = NSMenuItem(title: "Audio", action: nil, keyEquivalent: "")
        audioMenuItem.submenu = audioMenu
        appMenu.addItem(audioMenuItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Add Quit item
        let quitItem = NSMenuItem(title: "Quit Prezefren", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quitItem)
        
        print("✅ Menu bar configured with native preferences access")
    }
    
    // MARK: - Translation Menu
    
    private func createTranslationMenu() -> NSMenu {
        let menu = NSMenu(title: "Translation")
        
        // Translation mode selection
        let modeTitle = NSMenuItem(title: "Translation Mode", action: nil, keyEquivalent: "")
        modeTitle.isEnabled = false
        menu.addItem(modeTitle)
        
        // Apple Native option
        let appleItem = NSMenuItem(title: "Apple On-Device", action: #selector(setAppleTranslation), keyEquivalent: "")
        appleItem.target = self
        appleItem.state = preferences.translationMode == .appleNative ? .on : .off
        menu.addItem(appleItem)
        
        // Gemini API option
        let geminiItem = NSMenuItem(title: "Gemini API", action: #selector(setGeminiTranslation), keyEquivalent: "")
        geminiItem.target = self
        geminiItem.state = preferences.translationMode == .geminiAPI ? .on : .off
        menu.addItem(geminiItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Apple Translation downloads
        let downloadItem = NSMenuItem(title: "Download Apple Language Models...", action: #selector(downloadAppleLanguages), keyEquivalent: "")
        downloadItem.target = self
        downloadItem.isEnabled = preferences.canUseAppleTranslation
        menu.addItem(downloadItem)
        
        return menu
    }
    
    // MARK: - Audio Menu
    
    private func createAudioMenu() -> NSMenu {
        let menu = NSMenu(title: "Audio")
        
        // Audio mode selection
        let modeTitle = NSMenuItem(title: "Input Mode", action: nil, keyEquivalent: "")
        modeTitle.isEnabled = false
        menu.addItem(modeTitle)
        
        // Mono option
        let monoItem = NSMenuItem(title: "Mono (Single Channel)", action: #selector(setMonoAudio), keyEquivalent: "")
        monoItem.target = self
        monoItem.state = preferences.audioMode == .mono ? .on : .off
        menu.addItem(monoItem)
        
        // Goobero option (new dual channel mode)
        let gooberoItem = NSMenuItem(title: "Goobero (Dual Channel)", action: #selector(setGooberoAudio), keyEquivalent: "")
        gooberoItem.target = self
        gooberoItem.state = preferences.audioMode == .goobero ? .on : .off
        menu.addItem(gooberoItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Passthrough toggle
        let passthroughItem = NSMenuItem(title: "Enable Audio Passthrough", action: #selector(togglePassthrough), keyEquivalent: "")
        passthroughItem.target = self
        passthroughItem.state = preferences.enablePassthrough ? .on : .off
        menu.addItem(passthroughItem)
        
        return menu
    }
    
    // MARK: - Menu Actions
    
    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
    
    @objc private func showPreferences() {
        showPreferencesWindow()
    }
    
    func showPreferencesWindow() {
        if preferencesWindow == nil {
            createPreferencesWindow()
        }
        
        preferencesWindow?.makeKeyAndOrderFront(nil)
        preferencesWindow?.center()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func setAppleTranslation() {
        preferences.translationMode = .appleNative
        preferences.saveSettings()
        refreshMenus()
        print("🍎 Translation mode set to Apple Native via menu")
    }
    
    @objc private func setGeminiTranslation() {
        preferences.translationMode = .geminiAPI
        preferences.saveSettings()
        refreshMenus()
        print("🤖 Translation mode set to Gemini API via menu")
    }
    
    @objc private func downloadAppleLanguages() {
        Task {
            await preferences.downloadAppleLanguages()
        }
        print("🍎 Apple language download triggered via menu")
    }
    
    @objc private func setMonoAudio() {
        preferences.audioMode = .mono
        preferences.saveSettings()
        refreshMenus()
        print("🎤 Audio mode set to Mono via menu")
    }
    
    @objc private func setGooberoAudio() {
        preferences.audioMode = .goobero
        preferences.saveSettings()
        refreshMenus()
        print("🎧 Audio mode set to Goobero via menu")
    }
    
    @objc private func togglePassthrough() {
        preferences.enablePassthrough.toggle()
        preferences.saveSettings()
        refreshMenus()
        
        // Notify AudioDeviceManager to sync with audio engine
        Task {
            await AudioDeviceManager.shared.updatePassthrough(preferences.enablePassthrough)
        }
        
        print("🔄 Audio passthrough toggled via menu: \(preferences.enablePassthrough)")
    }
    
    // MARK: - Preferences Window
    
    private func createPreferencesWindow() {
        let contentView = PreferencesWindow()
        
        preferencesWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        preferencesWindow?.title = "Prezefren Preferences"
        preferencesWindow?.contentView = NSHostingView(rootView: contentView)
        preferencesWindow?.isReleasedWhenClosed = false
        preferencesWindow?.titlebarAppearsTransparent = false
    }
    
    // MARK: - Menu Updates
    
    func refreshMenus() {
        // Force menu bar refresh
        setupMenuBar()
    }
}