//
//  BackgroundTaskManager.swift
//  DriveSenseWatch Watch App
//
//  Created by Karthikeyan Lakshminarayanan on 01/08/25.
//

import Foundation
import WatchKit
import HealthKit
import CoreLocation
import WatchConnectivity

@MainActor
class BackgroundTaskManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = BackgroundTaskManager()
    
    private let healthManager = HealthKitManager.shared
    private var backgroundTask: WKRefreshBackgroundTask?
    private var backgroundRefreshTimer: Timer?
    
    // Location-based monitoring
    private var locationManager: CLLocationManager?
    private var isLocationMonitoringActive = false
    private var lastLocation: CLLocation?
    private var locationChangeThreshold: Double = 50.0 // 50 meters
    
    // Background monitoring settings
    private let backgroundRefreshInterval: TimeInterval = 30.0 // 30 seconds
    private let maxBackgroundTime: TimeInterval = 25.0 // 25 seconds to allow for cleanup
    
    override init() {
        super.init()
        print("🔧 [BackgroundTaskManager] Initializing...")
        setupLocationManager()
        setupBackgroundTasks()
        print("✅ [BackgroundTaskManager] Initialization complete")
    }
    
    // MARK: - Location Manager Setup
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.distanceFilter = 10 // Update every 10 meters
        locationManager?.allowsBackgroundLocationUpdates = true
    }
    
    // MARK: - Location-Based Health Monitoring
    
    func startLocationBasedMonitoring() {
        guard !isLocationMonitoringActive else { return }
        
        // Request location permission
        requestLocationPermission()
        
        // Start location updates
        locationManager?.startUpdatingLocation()
        isLocationMonitoringActive = true
        
        print("Location-based health monitoring started")
    }
    
    func stopLocationBasedMonitoring() {
        guard isLocationMonitoringActive else { return }
        
        locationManager?.stopUpdatingLocation()
        isLocationMonitoringActive = false
        
        print("Location-based health monitoring stopped")
    }
    
    private func requestLocationPermission() {
        switch locationManager?.authorizationStatus {
        case .notDetermined:
            locationManager?.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            // Permission already granted
            break
        case .denied, .restricted:
            print("Location permission denied - falling back to time-based monitoring")
        case .none:
            break
        @unknown default:
            break
        }
    }
    
    private func handleLocationChange(_ newLocation: CLLocation) {
        guard let lastLocation = lastLocation else {
            // First location update
            self.lastLocation = newLocation
            return
        }
        
        let distance = newLocation.distance(from: lastLocation)
        
        if distance >= locationChangeThreshold {
            // Significant location change detected - start health monitoring
            print("Location change detected: \(distance)m - Starting health data capture")
            
            // Start health monitoring
            startHealthMonitoringForLocationChange()
            
            // Update last location
            self.lastLocation = newLocation
        }
    }
    
    private func startHealthMonitoringForLocationChange() {
        // Ensure health monitoring is active
        if !healthManager.isMonitoring {
            healthManager.startBackgroundMonitoring()
        }
        
        // Collect health data immediately
        healthManager.collectCurrentData()
        
        // Send data to iPhone and request risk assessment
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.sendHealthDataAndRequestRiskAssessment()
        }
    }
    
    // MARK: - Background Task Setup
    
    private func setupBackgroundTasks() {
        // Register for background refresh
        WKExtension.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date().addingTimeInterval(backgroundRefreshInterval),
            userInfo: nil
        ) { error in
            if let error = error {
                print("Failed to schedule background refresh: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Background Task Handling
    
    func handleBackgroundTask(_ backgroundTask: WKRefreshBackgroundTask) {
        self.backgroundTask = backgroundTask
        
        // Start background monitoring
        startBackgroundMonitoring()
        
        // Schedule the next background refresh
        scheduleNextBackgroundRefresh()
        
        // End the background task after a reasonable time
        DispatchQueue.main.asyncAfter(deadline: .now() + maxBackgroundTime) { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func startBackgroundMonitoring() {
        // Ensure health monitoring is active
        if !healthManager.isMonitoring {
            healthManager.startBackgroundMonitoring()
        }
        
        // Collect current health data
        collectBackgroundHealthData()
        
        // Send data to iPhone if connected
        sendDataToiPhone()
    }
    
    private func collectBackgroundHealthData() {
        // Force a data collection cycle
        Task { @MainActor in
            healthManager.collectCurrentData()
        }
        
        // Export health data for analysis
        let healthData = healthManager.exportHealthData()
        
        // Store data locally for later analysis
        storeHealthDataLocally(healthData)
    }
    
    private func sendDataToiPhone() {
        // Check if iPhone is reachable
        if WCSession.isSupported() {
            let session = WCSession.default
            if session.isReachable {
                // Prepare health data for transmission
                let healthData = healthManager.exportHealthData()
                
                // Send data to iPhone and request risk assessment
                sendHealthDataAndRequestRiskAssessment(healthData)
            }
        }
    }
    
    // Public method to manually send data and request risk assessment
    func sendCurrentHealthData() {
        Task { @MainActor in
            healthManager.collectCurrentData()
        }
        let healthData = healthManager.exportHealthData()
        sendHealthDataAndRequestRiskAssessment(healthData)
    }
    
    private func sendHealthDataAndRequestRiskAssessment(_ healthData: HealthDataExport? = nil) {
        print("📤 [BackgroundTaskManager] Preparing to send health data and request risk assessment...")
        let dataToSend = healthData ?? healthManager.exportHealthData()
        
        print("📊 [BackgroundTaskManager] Health data to send:")
        print("   - Heart Rate points: \(dataToSend.heartRate.count)")
        print("   - HRV points: \(dataToSend.hrv.count)")
        print("   - Blood Oxygen points: \(dataToSend.bloodOxygen.count)")
        print("   - Respiratory Rate points: \(dataToSend.respiratoryRate.count)")
        print("   - Step Count points: \(dataToSend.stepCount.count)")
        print("   - Active Energy points: \(dataToSend.activeEnergy.count)")
        
        // Convert health data to dictionary for transmission
        var dataDict = convertHealthDataToDictionary(dataToSend)
        
        // Add request for risk assessment
        dataDict["requestRiskAssessment"] = true
        print("🔍 [BackgroundTaskManager] Added risk assessment request flag")
        
        // Send via WatchConnectivity
        if WCSession.default.isReachable {
            print("📱 [BackgroundTaskManager] WCSession is reachable, sending message...")
            WCSession.default.sendMessage(dataDict, replyHandler: { reply in
                print("✅ [BackgroundTaskManager] Health data sent and risk assessment requested")
                print("📨 [BackgroundTaskManager] Reply received: \(reply)")
                
                // Handle risk assessment response if provided
                if let riskAssessmentData = reply["riskAssessment"] as? [String: Any] {
                    print("🎯 [BackgroundTaskManager] Risk assessment data received in reply")
                    self.handleRiskAssessmentResponse(riskAssessmentData)
                } else {
                    print("⚠️ [BackgroundTaskManager] No risk assessment data in reply")
                }
            }, errorHandler: { error in
                print("❌ [BackgroundTaskManager] Failed to send health data to iPhone: \(error.localizedDescription)")
            })
        } else {
            print("❌ [BackgroundTaskManager] WCSession is not reachable")
        }
    }
    
    private func sendHealthDataToiPhone(_ healthData: HealthDataExport) {
        // Convert health data to dictionary for transmission
        let dataDict = convertHealthDataToDictionary(healthData)
        
        // Send via WatchConnectivity
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(dataDict, replyHandler: { reply in
                print("Health data sent successfully to iPhone")
            }, errorHandler: { error in
                print("Failed to send health data to iPhone: \(error.localizedDescription)")
            })
        }
    }
    
    private func convertHealthDataToDictionary(_ healthData: HealthDataExport) -> [String: Any] {
        // Convert health data to a format suitable for WatchConnectivity
        var dataDict: [String: Any] = [
            "timestamp": healthData.timestamp.timeIntervalSince1970,
            "type": "health_data"
        ]
        
        // Convert each vital sign to arrays
        dataDict["heartRate"] = healthData.heartRate.map { [
            "value": $0.value,
            "timestamp": $0.timestamp.timeIntervalSince1970,
            "unit": $0.unit
        ] }
        
        dataDict["hrv"] = healthData.hrv.map { [
            "value": $0.value,
            "timestamp": $0.timestamp.timeIntervalSince1970,
            "unit": $0.unit
        ] }
        
        dataDict["bloodOxygen"] = healthData.bloodOxygen.map { [
            "value": $0.value,
            "timestamp": $0.timestamp.timeIntervalSince1970,
            "unit": $0.unit
        ] }
        
        dataDict["respiratoryRate"] = healthData.respiratoryRate.map { [
            "value": $0.value,
            "timestamp": $0.timestamp.timeIntervalSince1970,
            "unit": $0.unit
        ] }
        
        dataDict["stepCount"] = healthData.stepCount.map { [
            "value": $0.value,
            "timestamp": $0.timestamp.timeIntervalSince1970,
            "unit": $0.unit
        ] }
        
        dataDict["activeEnergy"] = healthData.activeEnergy.map { [
            "value": $0.value,
            "timestamp": $0.timestamp.timeIntervalSince1970,
            "unit": $0.unit
        ] }
        
        return dataDict
    }
    
    private func storeHealthDataLocally(_ healthData: HealthDataExport) {
        // Store health data in UserDefaults for local access
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(healthData) {
            UserDefaults.standard.set(data, forKey: "lastHealthDataExport")
            UserDefaults.standard.set(Date(), forKey: "lastHealthDataExportTime")
        }
    }
    
    private func handleRiskAssessmentResponse(_ riskAssessmentData: [String: Any]) {
        // Parse risk assessment data from iPhone
        guard let riskLevelString = riskAssessmentData["riskLevel"] as? String,
              let riskLevel = RiskLevel(rawValue: riskLevelString),
              let timestamp = riskAssessmentData["timestamp"] as? TimeInterval,
              let recommendations = riskAssessmentData["recommendations"] as? [String] else {
            print("Invalid risk assessment data received")
            return
        }
        
        // Create risk assessment object
        let riskAssessment = DrivingRiskAssessment(
            timestamp: Date(timeIntervalSince1970: timestamp),
            riskLevel: riskLevel,
            riskFactors: [], // Parse risk factors if needed
            recommendations: recommendations
        )
        
        // Store risk assessment locally
        storeRiskAssessmentLocally(riskAssessment)
        
        // Notify UI to update
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("RiskAssessmentUpdated"),
                object: riskAssessment
            )
        }
        
        print("Risk assessment received and stored: \(riskLevel.rawValue)")
    }
    
    private func storeRiskAssessmentLocally(_ assessment: DrivingRiskAssessment) {
        // Store risk assessment in UserDefaults
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(assessment) {
            UserDefaults.standard.set(data, forKey: "lastRiskAssessment")
            UserDefaults.standard.set(Date(), forKey: "lastRiskAssessmentTime")
        }
    }
    
    private func scheduleNextBackgroundRefresh() {
        let nextRefreshDate = Date().addingTimeInterval(backgroundRefreshInterval)
        
        WKExtension.shared().scheduleBackgroundRefresh(
            withPreferredDate: nextRefreshDate,
            userInfo: nil
        ) { error in
            if let error = error {
                print("Failed to schedule next background refresh: \(error.localizedDescription)")
            }
        }
    }
    
    private func endBackgroundTask() {
        // Stop background monitoring
        stopBackgroundMonitoring()
        
        // End the background task
        backgroundTask?.setTaskCompletedWithSnapshot(false)
        backgroundTask = nil
    }
    
    private func stopBackgroundMonitoring() {
        // Stop any ongoing background operations
        backgroundRefreshTimer?.invalidate()
        backgroundRefreshTimer = nil
    }
    
    // MARK: - App Lifecycle Handling
    
    func handleAppWillResignActive() {
        // App is about to go to background
        // Start location-based monitoring
        startLocationBasedMonitoring()
    }
    
    func handleAppDidBecomeActive() {
        // App has become active again
        // Resume normal monitoring if needed
        if !healthManager.isMonitoring {
            healthManager.startBackgroundMonitoring()
        }
        
        // Continue location-based monitoring
        if !isLocationMonitoringActive {
            startLocationBasedMonitoring()
        }
    }
    
    // MARK: - Health Data Analysis
    
    func analyzeHealthDataForRisk(_ healthData: HealthDataExport) -> DrivingRiskAssessment {
        var riskFactors: [RiskFactor] = []
        var overallRisk: RiskLevel = .low
        
        // Analyze heart rate
        if let latestHeartRate = healthData.heartRate.last {
            if latestHeartRate.value > 120 {
                riskFactors.append(RiskFactor(
                    type: .elevatedHeartRate,
                    severity: .high,
                    description: "Elevated heart rate detected",
                    value: latestHeartRate.value
                ))
                overallRisk = max(overallRisk, .high)
            } else if latestHeartRate.value > 100 {
                riskFactors.append(RiskFactor(
                    type: .elevatedHeartRate,
                    severity: .medium,
                    description: "Slightly elevated heart rate",
                    value: latestHeartRate.value
                ))
                overallRisk = max(overallRisk, .medium)
            }
        }
        
        // Analyze HRV
        if let latestHRV = healthData.hrv.last {
            if latestHRV.value < 30 {
                riskFactors.append(RiskFactor(
                    type: .lowHRV,
                    severity: .high,
                    description: "Low heart rate variability detected",
                    value: latestHRV.value
                ))
                overallRisk = max(overallRisk, .high)
            } else if latestHRV.value < 50 {
                riskFactors.append(RiskFactor(
                    type: .lowHRV,
                    severity: .medium,
                    description: "Reduced heart rate variability",
                    value: latestHRV.value
                ))
                overallRisk = max(overallRisk, .medium)
            }
        }
        
        // Analyze blood oxygen
        if let latestBloodOxygen = healthData.bloodOxygen.last {
            if latestBloodOxygen.value < 0.90 {
                riskFactors.append(RiskFactor(
                    type: .lowBloodOxygen,
                    severity: .high,
                    description: "Low blood oxygen detected",
                    value: latestBloodOxygen.value * 100
                ))
                overallRisk = max(overallRisk, .high)
            } else if latestBloodOxygen.value < 0.95 {
                riskFactors.append(RiskFactor(
                    type: .lowBloodOxygen,
                    severity: .medium,
                    description: "Slightly reduced blood oxygen",
                    value: latestBloodOxygen.value * 100
                ))
                overallRisk = max(overallRisk, .medium)
            }
        }
        
        return DrivingRiskAssessment(
            timestamp: Date(),
            riskLevel: overallRisk,
            riskFactors: riskFactors,
            recommendations: generateRecommendations(for: riskFactors)
        )
    }
    
    private func generateRecommendations(for riskFactors: [RiskFactor]) -> [String] {
        var recommendations: [String] = []
        
        for factor in riskFactors {
            switch factor.type {
            case .elevatedHeartRate:
                recommendations.append("Consider taking a break and practicing deep breathing exercises")
            case .lowHRV:
                recommendations.append("Try to relax and reduce stress. Consider meditation or gentle stretching")
            case .lowBloodOxygen:
                recommendations.append("Ensure proper ventilation and consider stopping if symptoms persist")
            case .elevatedRespiratoryRate:
                recommendations.append("Focus on slow, deep breathing to reduce respiratory rate")
            case .fatigue:
                recommendations.append("Consider taking a rest break. Fatigue can significantly impact driving safety")
            }
        }
        
        if recommendations.isEmpty {
            recommendations.append("Your vital signs are within normal ranges. Continue safe driving practices.")
        }
        
        return recommendations
    }
}

// MARK: - Risk Assessment Models

struct DrivingRiskAssessment: Codable {
    let timestamp: Date
    let riskLevel: RiskLevel
    let riskFactors: [RiskFactor]
    let recommendations: [String]
}

enum RiskLevel: String, CaseIterable, Codable, Comparable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "orange"
        case .high: return "red"
        }
    }
    
    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        let order: [RiskLevel] = [.low, .medium, .high]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

struct RiskFactor: Codable {
    let type: RiskFactorType
    let severity: RiskLevel
    let description: String
    let value: Double
}

enum RiskFactorType: Codable {
    case elevatedHeartRate
    case lowHRV
    case lowBloodOxygen
    case elevatedRespiratoryRate
    case fatigue
}

// MARK: - CLLocationManagerDelegate

extension BackgroundTaskManager {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Handle location change on main actor
        Task { @MainActor in
            self.handleLocationChange(location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                if self.isLocationMonitoringActive {
                    self.locationManager?.startUpdatingLocation()
                }
            case .denied, .restricted:
                print("Location permission denied - using time-based monitoring")
                // Fall back to time-based monitoring
                self.setupBackgroundTasks()
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
} 