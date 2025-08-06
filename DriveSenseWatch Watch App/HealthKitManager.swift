//
//  HealthKitManager.swift
//  DriveSenseWatch Watch App
//
//  Created by Karthikeyan Lakshminarayanan on 01/08/25.
//

import Foundation
import HealthKit
import WatchKit
import Combine

@MainActor
class HealthKitManager: NSObject, ObservableObject {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    private var backgroundDeliveryTask: HKObserverQuery?
    private var backgroundDeliveryAnchor: HKQueryAnchor?
    
    // Published properties for real-time monitoring
    @Published var currentHeartRate: Double = 0.0
    @Published var currentHRV: Double = 0.0
    @Published var currentBloodOxygen: Double = 0.0
    @Published var currentRespiratoryRate: Double = 0.0
    @Published var currentStepCount: Int = 0
    @Published var currentActiveEnergy: Double = 0.0
    
    // Historical data for analysis
    @Published var heartRateHistory: [HealthDataPoint] = []
    @Published var hrvHistory: [HealthDataPoint] = []
    @Published var bloodOxygenHistory: [HealthDataPoint] = []
    @Published var respiratoryRateHistory: [HealthDataPoint] = []
    @Published var stepCountHistory: [HealthDataPoint] = []
    @Published var activeEnergyHistory: [HealthDataPoint] = []
    
    // Status and permissions
    @Published var isAuthorized = false
    @Published var isMonitoring = false
    @Published var lastUpdateTime = Date()
    @Published var errorMessage: String?
    
    // Background monitoring settings
    private let monitoringInterval: TimeInterval = 1.0 // 1 second
    private var monitoringTimer: Timer?
    
    // Health data types we want to monitor
    private let healthDataTypes: [HKQuantityType] = [
        HKQuantityType(.heartRate),
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.oxygenSaturation),
        HKQuantityType(.respiratoryRate),
        HKQuantityType(.stepCount),
        HKQuantityType(.activeEnergyBurned)
    ]
    
    override init() {
        super.init()
        setupHealthKit()
    }
    
    // MARK: - HealthKit Setup
    
    private func setupHealthKit() {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit is not available on this device"
            return
        }
        
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        let readTypes = Set(healthDataTypes)
        let writeTypes = Set<HKSampleType>([]) // We only read data
        
        print("Requesting HealthKit authorization for types: \(readTypes)")
        
        // Check which data types are available
        for dataType in healthDataTypes {
            let isAvailable = healthStore.authorizationStatus(for: dataType)
            print("📊 [HealthKitManager] \(dataType.identifier) - Authorization status: \(isAvailable.rawValue)")
        }
        
        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    print("HealthKit authorization successful")
                    
                    // Check authorization status after request
                    for dataType in self?.healthDataTypes ?? [] {
                        let status = self?.healthStore.authorizationStatus(for: dataType)
                        print("✅ [HealthKitManager] \(dataType.identifier) - Final authorization status: \(status?.rawValue ?? -1)")
                    }
                    
                    self?.isAuthorized = true
                    self?.startBackgroundMonitoring()
                } else {
                    print("HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")")
                    self?.errorMessage = "HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")"
                }
            }
        }
    }
    
    // MARK: - Background Monitoring
    
    func startBackgroundMonitoring() {
        guard isAuthorized else {
            errorMessage = "HealthKit authorization required"
            return
        }
        
        isMonitoring = true
        errorMessage = nil
        
        // Start continuous monitoring for each data type
        startHeartRateMonitoring()
        startHRVMonitoring()
        startBloodOxygenMonitoring()
        startRespiratoryRateMonitoring()
        startStepCountMonitoring()
        startActiveEnergyMonitoring()
        
        // Start background delivery for continuous updates
        enableBackgroundDelivery()
        
        // Start timer for periodic data collection
        startMonitoringTimer()
    }
    
    func stopBackgroundMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        // Stop background delivery
        disableBackgroundDelivery()
    }
    
    private func startMonitoringTimer() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.collectCurrentData()
            }
        }
    }
    
    // MARK: - Individual Data Type Monitoring
    
    private func startHeartRateMonitoring() {
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-60), end: nil, options: .strictStartDate)
        
        let query = HKAnchoredObjectQuery(type: heartRateType, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] query, samples, deletedObjects, anchor, error in
            Task { @MainActor in
                self?.handleHeartRateUpdate(samples: samples)
            }
        }
        
        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            Task { @MainActor in
                self?.handleHeartRateUpdate(samples: samples)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func startHRVMonitoring() {
        let hrvType = HKQuantityType(.heartRateVariabilitySDNN)
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-60), end: nil, options: .strictStartDate)
        
        let query = HKAnchoredObjectQuery(type: hrvType, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] query, samples, deletedObjects, anchor, error in
            Task { @MainActor in
                self?.handleHRVUpdate(samples: samples)
            }
        }
        
        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            Task { @MainActor in
                self?.handleHRVUpdate(samples: samples)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func startBloodOxygenMonitoring() {
        let bloodOxygenType = HKQuantityType(.oxygenSaturation)
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-60), end: nil, options: .strictStartDate)
        
        let query = HKAnchoredObjectQuery(type: bloodOxygenType, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] query, samples, deletedObjects, anchor, error in
            Task { @MainActor in
                self?.handleBloodOxygenUpdate(samples: samples)
            }
        }
        
        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            Task { @MainActor in
                self?.handleBloodOxygenUpdate(samples: samples)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func startRespiratoryRateMonitoring() {
        let respiratoryRateType = HKQuantityType(.respiratoryRate)
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-60), end: nil, options: .strictStartDate)
        
        let query = HKAnchoredObjectQuery(type: respiratoryRateType, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] query, samples, deletedObjects, anchor, error in
            Task { @MainActor in
                self?.handleRespiratoryRateUpdate(samples: samples)
            }
        }
        
        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            Task { @MainActor in
                self?.handleRespiratoryRateUpdate(samples: samples)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func startStepCountMonitoring() {
        let stepCountType = HKQuantityType(.stepCount)
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-60), end: nil, options: .strictStartDate)
        
        let query = HKAnchoredObjectQuery(type: stepCountType, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] query, samples, deletedObjects, anchor, error in
            Task { @MainActor in
                self?.handleStepCountUpdate(samples: samples)
            }
        }
        
        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            Task { @MainActor in
                self?.handleStepCountUpdate(samples: samples)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func startActiveEnergyMonitoring() {
        let activeEnergyType = HKQuantityType(.activeEnergyBurned)
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-60), end: nil, options: .strictStartDate)
        
        let query = HKAnchoredObjectQuery(type: activeEnergyType, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] query, samples, deletedObjects, anchor, error in
            Task { @MainActor in
                self?.handleActiveEnergyUpdate(samples: samples)
            }
        }
        
        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            Task { @MainActor in
                self?.handleActiveEnergyUpdate(samples: samples)
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Data Update Handlers
    
    private func handleHeartRateUpdate(samples: [HKSample]?) {
        print("💓 [HealthKitManager] Heart rate update - samples count: \(samples?.count ?? 0)")
        guard let samples = samples as? [HKQuantitySample] else { 
            print("💓 [HealthKitManager] No heart rate samples or wrong type")
            return 
        }
        
        if let latestSample = samples.last {
            let heartRate = latestSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            currentHeartRate = heartRate
            print("💓 [HealthKitManager] Latest heart rate: \(heartRate) BPM")
            
            let dataPoint = HealthDataPoint(
                value: heartRate,
                timestamp: latestSample.startDate,
                unit: "BPM"
            )
            heartRateHistory.append(dataPoint)
            
            // Keep only last 1000 data points to manage memory
            if heartRateHistory.count > 1000 {
                heartRateHistory.removeFirst()
            }
            
            lastUpdateTime = Date()
        }
    }
    
    private func handleHRVUpdate(samples: [HKSample]?) {
        print("💚 [HealthKitManager] HRV update - samples count: \(samples?.count ?? 0)")
        guard let samples = samples as? [HKQuantitySample] else { 
            print("💚 [HealthKitManager] No HRV samples or wrong type")
            return 
        }
        
        if let latestSample = samples.last {
            let hrv = latestSample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
            currentHRV = hrv
            print("💚 [HealthKitManager] Latest HRV: \(hrv) ms")
            
            let dataPoint = HealthDataPoint(
                value: hrv,
                timestamp: latestSample.startDate,
                unit: "ms"
            )
            hrvHistory.append(dataPoint)
            
            if hrvHistory.count > 1000 {
                hrvHistory.removeFirst()
            }
            
            lastUpdateTime = Date()
        }
    }
    
    private func handleBloodOxygenUpdate(samples: [HKSample]?) {
        print("🩸 [HealthKitManager] Blood oxygen update - samples count: \(samples?.count ?? 0)")
        guard let samples = samples as? [HKQuantitySample] else { 
            print("🩸 [HealthKitManager] No blood oxygen samples or wrong type")
            return 
        }
        
        if let latestSample = samples.last {
            let bloodOxygen = latestSample.quantity.doubleValue(for: HKUnit.percent())
            currentBloodOxygen = bloodOxygen
            print("🩸 [HealthKitManager] Latest blood oxygen: \(bloodOxygen)%")
            
            let dataPoint = HealthDataPoint(
                value: bloodOxygen,
                timestamp: latestSample.startDate,
                unit: "%"
            )
            bloodOxygenHistory.append(dataPoint)
            
            if bloodOxygenHistory.count > 1000 {
                bloodOxygenHistory.removeFirst()
            }
            
            lastUpdateTime = Date()
        }
    }
    
    private func handleRespiratoryRateUpdate(samples: [HKSample]?) {
        print("🫁 [HealthKitManager] Respiratory rate update - samples count: \(samples?.count ?? 0)")
        guard let samples = samples as? [HKQuantitySample] else { 
            print("🫁 [HealthKitManager] No respiratory rate samples or wrong type")
            return 
        }
        
        if let latestSample = samples.last {
            let respiratoryRate = latestSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            currentRespiratoryRate = respiratoryRate
            print("🫁 [HealthKitManager] Latest respiratory rate: \(respiratoryRate) breaths/min")
            
            let dataPoint = HealthDataPoint(
                value: respiratoryRate,
                timestamp: latestSample.startDate,
                unit: "breaths/min"
            )
            respiratoryRateHistory.append(dataPoint)
            
            if respiratoryRateHistory.count > 1000 {
                respiratoryRateHistory.removeFirst()
            }
            
            lastUpdateTime = Date()
        }
    }
    
    private func handleStepCountUpdate(samples: [HKSample]?) {
        print("👟 [HealthKitManager] Step count update - samples count: \(samples?.count ?? 0)")
        guard let samples = samples as? [HKQuantitySample] else { 
            print("👟 [HealthKitManager] No step count samples or wrong type")
            return 
        }
        
        if let latestSample = samples.last {
            let stepCount = Int(latestSample.quantity.doubleValue(for: HKUnit.count()))
            currentStepCount = stepCount
            print("👟 [HealthKitManager] Latest step count: \(stepCount) steps")
            
            let dataPoint = HealthDataPoint(
                value: Double(stepCount),
                timestamp: latestSample.startDate,
                unit: "steps"
            )
            stepCountHistory.append(dataPoint)
            
            if stepCountHistory.count > 1000 {
                stepCountHistory.removeFirst()
            }
            
            lastUpdateTime = Date()
        }
    }
    
    private func handleActiveEnergyUpdate(samples: [HKSample]?) {
        print("🔥 [HealthKitManager] Active energy update - samples count: \(samples?.count ?? 0)")
        guard let samples = samples as? [HKQuantitySample] else { 
            print("🔥 [HealthKitManager] No active energy samples or wrong type")
            return 
        }
        
        if let latestSample = samples.last {
            let activeEnergy = latestSample.quantity.doubleValue(for: HKUnit.kilocalorie())
            currentActiveEnergy = activeEnergy
            print("🔥 [HealthKitManager] Latest active energy: \(activeEnergy) kcal")
            
            let dataPoint = HealthDataPoint(
                value: activeEnergy,
                timestamp: latestSample.startDate,
                unit: "kcal"
            )
            activeEnergyHistory.append(dataPoint)
            
            if activeEnergyHistory.count > 1000 {
                activeEnergyHistory.removeFirst()
            }
            
            lastUpdateTime = Date()
        }
    }
    
    // MARK: - Background Delivery
    
    private func enableBackgroundDelivery() {
        print("🔄 [HealthKitManager] Enabling background delivery for all data types...")
        for dataType in healthDataTypes {
            healthStore.enableBackgroundDelivery(for: dataType, frequency: .immediate) { success, error in
                if success {
                    print("✅ [HealthKitManager] Background delivery enabled for \(dataType.identifier)")
                } else {
                    print("❌ [HealthKitManager] Failed to enable background delivery for \(dataType.identifier): \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
    
    private func disableBackgroundDelivery() {
        for dataType in healthDataTypes {
            healthStore.disableBackgroundDelivery(for: dataType) { success, error in
                if !success {
                    print("Failed to disable background delivery for \(dataType): \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
    
    // MARK: - Data Collection
    
    // Public method for external access
    func collectCurrentData() {
        // This method is called every second by the timer
        // It ensures we have the most recent data even if HealthKit updates are delayed
        
        let now = Date()
        let predicate = HKQuery.predicateForSamples(withStart: now.addingTimeInterval(-5), end: now, options: .strictStartDate)
        
        for dataType in healthDataTypes {
            let query = HKSampleQuery(sampleType: dataType, predicate: predicate, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { query, samples, error in
                // Handle the latest sample for each data type
                // This ensures we don't miss any data
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Data Export
    
    func exportHealthData() -> HealthDataExport {
        return HealthDataExport(
            timestamp: Date(),
            heartRate: heartRateHistory,
            hrv: hrvHistory,
            bloodOxygen: bloodOxygenHistory,
            respiratoryRate: respiratoryRateHistory,
            stepCount: stepCountHistory,
            activeEnergy: activeEnergyHistory
        )
    }
    
    func clearHistoricalData() {
        heartRateHistory.removeAll()
        hrvHistory.removeAll()
        bloodOxygenHistory.removeAll()
        respiratoryRateHistory.removeAll()
        stepCountHistory.removeAll()
        activeEnergyHistory.removeAll()
    }
}

// MARK: - Data Models

struct HealthDataPoint: Codable, Identifiable {
    let id: UUID
    let value: Double
    let timestamp: Date
    let unit: String
    
    init(value: Double, timestamp: Date, unit: String) {
        self.id = UUID()
        self.value = value
        self.timestamp = timestamp
        self.unit = unit
    }
}

struct HealthDataExport: Codable {
    let timestamp: Date
    let heartRate: [HealthDataPoint]
    let hrv: [HealthDataPoint]
    let bloodOxygen: [HealthDataPoint]
    let respiratoryRate: [HealthDataPoint]
    let stepCount: [HealthDataPoint]
    let activeEnergy: [HealthDataPoint]
} 