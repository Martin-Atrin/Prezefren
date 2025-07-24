import Foundation
import Darwin

/**
 * ResourceMonitor - Critical resource monitoring for Prezefren
 * 
 * Monitors CPU and memory usage to ensure optimal real-time performance
 * Provides automatic cleanup triggers when resources exceed thresholds
 */

actor ResourceMonitor {
    
    // MARK: - Properties
    private var monitoringTimer: Timer?
    private var isMonitoring = false
    
    // Resource thresholds
    private let memoryWarningThreshold: Double = 500.0 // MB
    private let memoryEmergencyThreshold: Double = 800.0 // MB
    private let cpuWarningThreshold: Double = 80.0 // Percentage
    
    // Callbacks for resource warnings
    nonisolated(unsafe) private var memoryWarningCallback: ((Double) -> Void)?
    nonisolated(unsafe) private var cpuWarningCallback: ((Double) -> Void)?
    nonisolated(unsafe) private var emergencyCleanupCallback: (() -> Void)?
    
    // MARK: - Public Interface
    
    func startMonitoring(
        memoryWarning: @escaping (Double) -> Void,
        cpuWarning: @escaping (Double) -> Void,
        emergencyCleanup: @escaping () -> Void
    ) {
        guard !isMonitoring else { return }
        
        memoryWarningCallback = memoryWarning
        cpuWarningCallback = cpuWarning
        emergencyCleanupCallback = emergencyCleanup
        
        isMonitoring = true
        
        // Start monitoring timer - check every 10 seconds
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task {
                await self?.checkResources()
            }
        }
        
        print("🔍 ResourceMonitor: Started monitoring resources")
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        print("🔍 ResourceMonitor: Stopped monitoring resources")
    }
    
    // MARK: - Resource Checking
    
    private func checkResources() async {
        let memoryUsage = getMemoryUsage()
        let cpuUsage = getCPUUsage()
        
        // Memory monitoring
        if memoryUsage > memoryEmergencyThreshold {
            print("🚨 ResourceMonitor: EMERGENCY - Memory usage: \(String(format: "%.1f", memoryUsage))MB")
            emergencyCleanupCallback?()
        } else if memoryUsage > memoryWarningThreshold {
            print("⚠️ ResourceMonitor: High memory usage: \(String(format: "%.1f", memoryUsage))MB")
            memoryWarningCallback?(memoryUsage)
        }
        
        // CPU monitoring
        if cpuUsage > cpuWarningThreshold {
            print("⚠️ ResourceMonitor: High CPU usage: \(String(format: "%.1f", cpuUsage))%")
            cpuWarningCallback?(cpuUsage)
        }
        
        // Periodic debug info (every 6th check = 1 minute)  
        // Note: Using simple modulo for debug logging
        if (Int(Date().timeIntervalSince1970) % 60) == 0 {
            print("📊 ResourceMonitor: Memory: \(String(format: "%.1f", memoryUsage))MB, CPU: \(String(format: "%.1f", cpuUsage))%")
        }
    }
    
    // MARK: - Resource Measurement
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        } else {
            return 0.0
        }
    }
    
    private func getCPUUsage() -> Double {
        var info = task_thread_times_info()
        var count = mach_msg_type_number_t(MemoryLayout<task_thread_times_info>.size) / UInt32(MemoryLayout<natural_t>.size)
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(TASK_THREAD_TIMES_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            // Simple approximation - more complex calculation would require baseline measurement
            let totalTime = info.user_time.seconds + info.user_time.microseconds / 1_000_000 +
                           info.system_time.seconds + info.system_time.microseconds / 1_000_000
            
            // Return a rough percentage (this is simplified - real CPU monitoring requires more work)
            return min(Double(totalTime) * 0.1, 100.0) // Simplified calculation
        } else {
            return 0.0
        }
    }
    
    // MARK: - Optimization Recommendations
    
    nonisolated func getOptimizationRecommendations(memoryUsage: Double, cpuUsage: Double) -> [String] {
        var recommendations: [String] = []
        
        if memoryUsage > memoryWarningThreshold {
            recommendations.append("Reduce transcription history length")
            recommendations.append("Clear translation caches")
            recommendations.append("Close unused subtitle windows")
        }
        
        if cpuUsage > cpuWarningThreshold {
            recommendations.append("Reduce audio processing frequency")
            recommendations.append("Switch to Apple Speech engine (lower CPU)")
            recommendations.append("Disable advanced audio processing")
        }
        
        if memoryUsage > memoryWarningThreshold && cpuUsage > cpuWarningThreshold {
            recommendations.append("Consider restarting the application")
        }
        
        return recommendations
    }
    
    deinit {
        monitoringTimer?.invalidate()
        print("🧹 ResourceMonitor: Cleaned up")
    }
}

// MARK: - Convenience Extensions

extension ResourceMonitor {
    
    // Get current resource snapshot
    nonisolated func getCurrentResourceSnapshot() async -> (memory: Double, cpu: Double) {
        let monitor = self
        return await monitor.getResourceSnapshot()
    }
    
    private func getResourceSnapshot() -> (memory: Double, cpu: Double) {
        return (getMemoryUsage(), getCPUUsage())
    }
}