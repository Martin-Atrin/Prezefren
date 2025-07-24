import Foundation
import AVFoundation
import CoreAudio

struct AudioDevice: Identifiable, Equatable, Hashable {
    let id: AudioDeviceID
    let name: String
    let isInput: Bool
    let isOutput: Bool
    let channelCount: Int
    let isDefault: Bool
    
    static func == (lhs: AudioDevice, rhs: AudioDevice) -> Bool {
        return lhs.id == rhs.id
    }
}

@MainActor
class AudioDeviceManager: ObservableObject {
    @Published var inputDevices: [AudioDevice] = []
    @Published var outputDevices: [AudioDevice] = []
    @Published var selectedInputDevice: AudioDevice?
    @Published var selectedOutputDevice: AudioDevice?
    @Published var passthroughEnabled = true
    
    // Callback for when devices change - to be set by ContentView or AppState
    var audioEngineUpdateCallback: ((AudioDevice?) async -> Void)?
    var passthroughUpdateCallback: ((Bool) async -> Void)?
    var deviceDisconnectedCallback: (() async -> Void)?
    
    // Device disconnection tracking
    @Published var lastKnownInputDevice: AudioDevice?
    @Published var inputDeviceDisconnected = false
    
    private var deviceListenerAdded = false
    
    init() {
        Task {
            await scanAudioDevices()
            setupDeviceChangeListener()
        }
    }
    
    // MARK: - Device Connection Monitoring
    
    func startDeviceMonitoring() {
        // Additional monitoring for real-time device status
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.verifyCurrentDeviceConnection()
            }
        }
    }
    
    private func verifyCurrentDeviceConnection() async {
        guard let currentDevice = selectedInputDevice else { return }
        
        // Try to verify the device is still accessible
        let isStillAvailable = checkDeviceAvailability(device: currentDevice)
        
        if !isStillAvailable && !inputDeviceDisconnected {
            print("🚨 Device \(currentDevice.name) appears disconnected during monitoring")
            await checkForDeviceDisconnection(previousDevice: currentDevice)
        }
    }
    
    // MARK: - Device Scanning
    
    func scanAudioDevices() async {
        var devices: [AudioDevice] = []
        
        // Get all audio devices
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var propertySize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize
        )
        
        guard status == noErr else {
            print("❌ Failed to get audio device list size: \(status)")
            return
        }
        
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = Array<AudioDeviceID>(repeating: 0, count: deviceCount)
        
        let getDevicesStatus = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceIDs
        )
        
        guard getDevicesStatus == noErr else {
            print("❌ Failed to get audio devices: \(getDevicesStatus)")
            return
        }
        
        // Process each device
        for deviceID in deviceIDs {
            if let device = getDeviceInfo(deviceID: deviceID) {
                devices.append(device)
            }
        }
        
        // Update published properties on main thread
        let inputDevs = devices.filter { $0.isInput }
        let outputDevs = devices.filter { $0.isOutput }
        
        self.inputDevices = inputDevs
        self.outputDevices = outputDevs
        
        // Set defaults if none selected
        if selectedInputDevice == nil {
            selectedInputDevice = inputDevs.first { $0.isDefault } ?? inputDevs.first
        }
        if selectedOutputDevice == nil {
            selectedOutputDevice = outputDevs.first { $0.isDefault } ?? outputDevs.first
        }
        
        print("🎤 Found \(inputDevs.count) input devices, \(outputDevs.count) output devices")
        
        // Detect potential individual earbud pairs
    }
    
    private func getDeviceInfo(deviceID: AudioDeviceID) -> AudioDevice? {
        // Get device name
        guard let name = getDeviceName(deviceID: deviceID) else { return nil }
        
        // Check input/output capabilities
        let hasInput = getChannelCount(deviceID: deviceID, isInput: true) > 0
        let hasOutput = getChannelCount(deviceID: deviceID, isInput: false) > 0
        
        // Get channel count (prioritize input for input devices)
        let channelCount = hasInput ? 
            getChannelCount(deviceID: deviceID, isInput: true) :
            getChannelCount(deviceID: deviceID, isInput: false)
        
        // Check if default device
        let isDefaultInput = isDefaultDevice(deviceID: deviceID, isInput: true)
        let isDefaultOutput = isDefaultDevice(deviceID: deviceID, isInput: false)
        let isDefault = isDefaultInput || isDefaultOutput
        
        return AudioDevice(
            id: deviceID,
            name: name,
            isInput: hasInput,
            isOutput: hasOutput,
            channelCount: channelCount,
            isDefault: isDefault
        )
    }
    
    private func getDeviceName(deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var propertySize: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize
        )
        
        guard sizeStatus == noErr else { return nil }
        
        var deviceName: CFString?
        let getStatus = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceName
        )
        
        guard getStatus == noErr, let name = deviceName else { return nil }
        return name as String
    }
    
    private func getChannelCount(deviceID: AudioDeviceID, isInput: Bool) -> Int {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: isInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var propertySize: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize
        )
        
        guard sizeStatus == noErr, propertySize > 0 else { return 0 }
        
        let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferList.deallocate() }
        
        let getStatus = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            bufferList
        )
        
        guard getStatus == noErr else { return 0 }
        
        var totalChannels = 0
        let bufferCount = Int(bufferList.pointee.mNumberBuffers)
        
        for i in 0..<bufferCount {
            let buffer = withUnsafePointer(to: bufferList.pointee.mBuffers) {
                ($0 + i).pointee
            }
            totalChannels += Int(buffer.mNumberChannels)
        }
        
        return totalChannels
    }
    
    private func isDefaultDevice(deviceID: AudioDeviceID, isInput: Bool) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: isInput ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var defaultDeviceID: AudioDeviceID = 0
        var propertySize: UInt32 = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &defaultDeviceID
        )
        
        return status == noErr && defaultDeviceID == deviceID
    }
    
    // MARK: - Device Change Monitoring
    
    private func setupDeviceChangeListener() {
        guard !deviceListenerAdded else { return }
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let listener: AudioObjectPropertyListenerProc = { _, _, _, _ in
            Task { @MainActor in
                // Store current device before rescan
                let previousInputDevice = AudioDeviceManager.shared.selectedInputDevice
                
                // Rescan devices when hardware changes
                await AudioDeviceManager.shared.scanAudioDevices()
                
                // Check if previously selected device is still available
                await AudioDeviceManager.shared.checkForDeviceDisconnection(previousDevice: previousInputDevice)
            }
            return noErr
        }
        
        let status = AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            listener,
            nil
        )
        
        if status == noErr {
            deviceListenerAdded = true
            print("🔊 Audio device change listener setup successfully")
        } else {
            print("❌ Failed to setup device change listener: \(status)")
        }
    }
    
    // MARK: - Device Disconnection Detection
    
    private func checkForDeviceDisconnection(previousDevice: AudioDevice?) async {
        guard let previousDevice = previousDevice else { return }
        
        // Check if the previously selected device is still in the list
        let deviceStillExists = inputDevices.contains { $0.id == previousDevice.id }
        
        if !deviceStillExists {
            print("🚨 DEVICE DISCONNECTED: \(previousDevice.name) is no longer available")
            
            // Mark disconnection
            inputDeviceDisconnected = true
            lastKnownInputDevice = previousDevice
            
            // Automatically fallback to default device
            await performAutoFallback(from: previousDevice)
            
            // Notify about disconnection
            await deviceDisconnectedCallback?()
        } else {
            // Device reconnected or still connected
            inputDeviceDisconnected = false
        }
    }
    
    private func performAutoFallback(from disconnectedDevice: AudioDevice) async {
        print("🔄 Performing automatic fallback from \(disconnectedDevice.name)...")
        
        // Find the best fallback device
        let fallbackDevice = findBestFallbackDevice(excluding: disconnectedDevice)
        
        if let fallback = fallbackDevice {
            print("✅ Auto-fallback to: \(fallback.name)")
            selectedInputDevice = fallback
            
            // Notify AudioEngine of device change
            await audioEngineUpdateCallback?(fallback)
        } else {
            print("❌ No suitable fallback device found")
            selectedInputDevice = nil
        }
    }
    
    private func findBestFallbackDevice(excluding: AudioDevice) -> AudioDevice? {
        // Priority: Default device > Built-in device > Any available device
        
        // 1. Try default input device first
        if let defaultDevice = inputDevices.first(where: { $0.isDefault && $0.id != excluding.id }) {
            return defaultDevice
        }
        
        // 2. Try built-in microphone
        if let builtInDevice = inputDevices.first(where: { 
            $0.name.lowercased().contains("built-in") && $0.id != excluding.id 
        }) {
            return builtInDevice
        }
        
        // 3. Any other available input device
        return inputDevices.first { $0.id != excluding.id }
    }
    
    func checkDeviceAvailability(device: AudioDevice) -> Bool {
        return inputDevices.contains { $0.id == device.id }
    }
    
    func getSystemDefaultInputDevice() -> AudioDevice? {
        return inputDevices.first { $0.isDefault }
    }
    
    func forceRescanDevices() async {
        print("🔄 Force rescanning audio devices...")
        await scanAudioDevices()
    }
    
    // MARK: - Device Selection
    
    func selectInputDevice(_ device: AudioDevice) {
        selectedInputDevice = device
        lastKnownInputDevice = device
        inputDeviceDisconnected = false
        
        print("🎤 Selected input device: \(device.name) (\(device.channelCount) channels)")
        
        // Notify about stereo capability change
        if device.channelCount >= 2 {
            print("✅ Device supports stereo mode")
        } else {
            print("⚠️ Device only supports mono - stereo mode not available")
        }
    }
    
    func selectOutputDevice(_ device: AudioDevice) {
        selectedOutputDevice = device
        print("🔊 Selected output device: \(device.name)")
        
        // Notify AudioEngine of device change
        Task {
            await audioEngineUpdateCallback?(device)
        }
    }
    
    func togglePassthrough() {
        passthroughEnabled.toggle()
        print("🔄 Audio passthrough: \(passthroughEnabled ? "ON" : "OFF")")
        
        // Notify AudioEngine of passthrough change
        Task {
            await passthroughUpdateCallback?(passthroughEnabled)
        }
    }
    
    func setPassthrough(_ enabled: Bool) {
        passthroughEnabled = enabled
        print("🔄 Audio passthrough set to: \(enabled ? "ON" : "OFF")")
        
        // Notify AudioEngine of passthrough change
        Task {
            await passthroughUpdateCallback?(enabled)
        }
    }
    
    func updatePassthrough(_ enabled: Bool) async {
        passthroughEnabled = enabled
        print("🔄 Audio passthrough updated via menu: \(enabled ? "ON" : "OFF")")
        
        // Notify AudioEngine of passthrough change
        await passthroughUpdateCallback?(enabled)
    }
    
    
    // MARK: - Hardware Capability Detection
    
    func getCurrentInputChannelCount() -> Int {
        return selectedInputDevice?.channelCount ?? 0
    }
    
    func supportsStereoMode() -> Bool {
        return getCurrentInputChannelCount() >= 2
    }
    
    func getInputCapabilityStatus() -> String {
        let channelCount = getCurrentInputChannelCount()
        if channelCount >= 2 {
            return "✅ Stereo capable (\(channelCount) channels)"
        } else if channelCount == 1 {
            let deviceType = isSelectedInputBluetooth() ? "Bluetooth" : "Built-in"
            return "⚠️ \(deviceType) mono only (1 channel) - Stereo mode not available"
        } else {
            return "❌ No input device selected"
        }
    }
    
    func isSelectedInputBluetooth() -> Bool {
        guard let selectedDevice = selectedInputDevice else { return false }
        // Check if device name contains common Bluetooth indicators
        let bluetoothIndicators = ["bluetooth", "airpods", "beats", "bose", "sony", "jabra", "sennheiser", "redmi", "buds", "wireless"]
        let deviceNameLower = selectedDevice.name.lowercased()
        return bluetoothIndicators.contains { deviceNameLower.contains($0) }
    }
    
    func getBluetoothGuidance() -> String {
        if isSelectedInputBluetooth() {
            return "🎧 Bluetooth devices typically aggregate microphones into mono streams. For true stereo transcription, consider professional USB audio interfaces."
        } else {
            return ""
        }
    }
    
    func getDeviceConnectionStatus() -> String {
        if inputDeviceDisconnected {
            let deviceName = lastKnownInputDevice?.name ?? "Unknown"
            let currentName = selectedInputDevice?.name ?? "None"
            return "⚠️ \(deviceName) disconnected, using \(currentName)"
        } else if let device = selectedInputDevice {
            return "✅ \(device.name) connected"
        } else {
            return "❌ No input device selected"
        }
    }
    
    // MARK: - Static Shared Instance
    
    static let shared = AudioDeviceManager()
}