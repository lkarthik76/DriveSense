//
//  WatchDataReceiver.swift
//  DriveSense
//
//  Created by Karthikeyan Lakshminarayanan on 01/08/25.
//

import Foundation
import WatchConnectivity
import SwiftUI

@MainActor
class WatchDataReceiver: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchDataReceiver()
    
    @Published var lastReceivedData: HealthDataFromWatch?
    @Published var isWatchConnected = false
    @Published var lastUpdateTime = Date()
    @Published var connectionStatus = "Disconnected"
    
    private var session: WCSession?
    
    override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            connectionStatus = "Watch Connectivity not supported"
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    // MARK: - WCSessionDelegate
    
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("📱 [WatchDataReceiver] WCSession activation completed")
        if let error = error {
            print("❌ [WatchDataReceiver] WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("✅ [WatchDataReceiver] WCSession activation successful")
        }
        
        Task { @MainActor in
            switch activationState {
            case .activated:
                print("✅ [WatchDataReceiver] WCSession state: Activated")
                self.connectionStatus = "Connected"
                self.isWatchConnected = true
            case .inactive:
                print("⚠️ [WatchDataReceiver] WCSession state: Inactive")
                self.connectionStatus = "Inactive"
                self.isWatchConnected = false
            case .notActivated:
                print("❌ [WatchDataReceiver] WCSession state: Not Activated")
                self.connectionStatus = "Not Activated"
                self.isWatchConnected = false
            @unknown default:
                print("❓ [WatchDataReceiver] WCSession state: Unknown")
                self.connectionStatus = "Unknown"
                self.isWatchConnected = false
            }
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            self.connectionStatus = "Inactive"
            self.isWatchConnected = false
        }
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            self.connectionStatus = "Deactivated"
            self.isWatchConnected = false
        }
        // Reactivate for future communications
        WCSession.default.activate()
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            self.handleReceivedMessage(message)
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        Task { @MainActor in
            self.handleReceivedMessageWithReply(message, replyHandler: replyHandler)
        }
    }
    
    // MARK: - Message Handling
    
    private func handleReceivedMessage(_ message: [String: Any]) {
        guard let messageType = message["type"] as? String else { return }
        
        switch messageType {
        case "health_data":
            handleHealthData(message)
        case "risk_assessment_request":
            handleRiskAssessmentRequest(message)
        default:
            print("Unknown message type: \(messageType)")
        }
    }
    
    private func handleReceivedMessageWithReply(_ message: [String: Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("📨 [WatchDataReceiver] Received message from Watch")
        print("📋 [WatchDataReceiver] Message keys: \(message.keys)")
        
        guard let messageType = message["type"] as? String else { 
            print("❌ [WatchDataReceiver] Invalid message type")
            replyHandler(["status": "error", "message": "Invalid message type"])
            return 
        }
        
        print("📝 [WatchDataReceiver] Message type: \(messageType)")
        
        switch messageType {
        case "health_data":
            print("🏥 [WatchDataReceiver] Handling health data message...")
            handleHealthDataWithReply(message, replyHandler: replyHandler)
        case "risk_assessment_request":
            print("🔍 [WatchDataReceiver] Handling risk assessment request...")
            handleRiskAssessmentRequestWithReply(message, replyHandler: replyHandler)
        default:
            print("❌ [WatchDataReceiver] Unknown message type: \(messageType)")
            replyHandler(["status": "error", "message": "Unknown message type"])
        }
    }
    
    private func handleHealthData(_ message: [String: Any]) {
        let healthData = parseHealthDataFromMessage(message)
        lastReceivedData = healthData
        lastUpdateTime = Date()
        
        // Check if risk assessment was requested
        let requestRiskAssessment = message["requestRiskAssessment"] as? Bool ?? false
        
        if requestRiskAssessment {
            // Analyze with Gemma and send back to Watch
            analyzeHealthDataWithGemmaAndSendBack(healthData)
        } else {
            // Just analyze locally
            analyzeHealthDataWithGemma(healthData)
        }
    }
    
    private func handleHealthDataWithReply(_ message: [String: Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("🏥 [WatchDataReceiver] Parsing health data from message...")
        let healthData = parseHealthDataFromMessage(message)
        lastReceivedData = healthData
        lastUpdateTime = Date()
        
        print("📊 [WatchDataReceiver] Parsed health data:")
        print("   - Heart Rate points: \(healthData.heartRate.count)")
        print("   - HRV points: \(healthData.hrv.count)")
        print("   - Blood Oxygen points: \(healthData.bloodOxygen.count)")
        print("   - Respiratory Rate points: \(healthData.respiratoryRate.count)")
        print("   - Step Count points: \(healthData.stepCount.count)")
        print("   - Active Energy points: \(healthData.activeEnergy.count)")
        
        // Check if risk assessment was requested
        let requestRiskAssessment = message["requestRiskAssessment"] as? Bool ?? false
        print("🔍 [WatchDataReceiver] Risk assessment requested: \(requestRiskAssessment)")
        
        if requestRiskAssessment {
            // Analyze with Gemma and send back to Watch
            print("🤖 [WatchDataReceiver] Starting Gemma analysis...")
            analyzeHealthDataWithGemmaAndSendBack(healthData, replyHandler: replyHandler)
        } else {
            // Just send acknowledgment
            print("✅ [WatchDataReceiver] Sending acknowledgment...")
            replyHandler(["status": "received"])
        }
    }
    
    private func handleRiskAssessmentRequest(_ message: [String: Any]) {
        // Handle risk assessment requests from Watch
        if let healthData = lastReceivedData {
            analyzeHealthDataWithGemma(healthData)
        }
    }
    
    private func handleRiskAssessmentRequestWithReply(_ message: [String: Any], replyHandler: @escaping ([String : Any]) -> Void) {
        // Handle risk assessment requests from Watch with reply
        if let healthData = lastReceivedData {
            analyzeHealthDataWithGemmaAndSendBack(healthData, replyHandler: replyHandler)
        } else {
            replyHandler(["status": "error", "message": "No health data available"])
        }
    }
    
    private func parseHealthDataFromMessage(_ message: [String: Any]) -> HealthDataFromWatch {
        let timestamp = Date(timeIntervalSince1970: message["timestamp"] as? TimeInterval ?? 0)
        
        let heartRate = parseDataPoints(from: message["heartRate"] as? [[String: Any]] ?? [])
        let hrv = parseDataPoints(from: message["hrv"] as? [[String: Any]] ?? [])
        let bloodOxygen = parseDataPoints(from: message["bloodOxygen"] as? [[String: Any]] ?? [])
        let respiratoryRate = parseDataPoints(from: message["respiratoryRate"] as? [[String: Any]] ?? [])
        let stepCount = parseDataPoints(from: message["stepCount"] as? [[String: Any]] ?? [])
        let activeEnergy = parseDataPoints(from: message["activeEnergy"] as? [[String: Any]] ?? [])
        
        return HealthDataFromWatch(
            timestamp: timestamp,
            heartRate: heartRate,
            hrv: hrv,
            bloodOxygen: bloodOxygen,
            respiratoryRate: respiratoryRate,
            stepCount: stepCount,
            activeEnergy: activeEnergy
        )
    }
    
    private func parseDataPoints(from array: [[String: Any]]) -> [HealthDataPoint] {
        return array.compactMap { dict in
            guard let value = dict["value"] as? Double,
                  let timestamp = dict["timestamp"] as? TimeInterval,
                  let unit = dict["unit"] as? String else {
                return nil
            }
            
            return HealthDataPoint(
                value: value,
                timestamp: Date(timeIntervalSince1970: timestamp),
                unit: unit
            )
        }
    }
    
    // MARK: - Gemma Integration
    
    private func analyzeHealthDataWithGemma(_ healthData: HealthDataFromWatch) {
        Task {
            do {
                let riskAssessment = try await GemmaService.shared.analyzeDrivingRisk(healthData)
                
                // Store the assessment
                await MainActor.run {
                    self.storeRiskAssessment(riskAssessment)
                }
                
            } catch {
                print("Error analyzing health data with Gemma: \(error)")
            }
        }
    }
    
    private func analyzeHealthDataWithGemmaAndSendBack(_ healthData: HealthDataFromWatch, replyHandler: (([String: Any]) -> Void)? = nil) {
        print("📱 [WatchDataReceiver] Starting health data analysis with Gemma...")
        print("📊 [WatchDataReceiver] Health data received from Watch:")
        print("   - Heart Rate: \(healthData.latestHeartRate) BPM")
        print("   - HRV: \(healthData.latestHRV) ms")
        print("   - Blood Oxygen: \(String(format: "%.1f", healthData.latestBloodOxygen * 100))%")
        print("   - Respiratory Rate: \(healthData.latestRespiratoryRate) breaths/min")
        print("   - Step Count: \(healthData.latestStepCount) steps")
        print("   - Active Energy: \(healthData.latestActiveEnergy) kcal")
        
        Task {
            do {
                print("🤖 [WatchDataReceiver] Calling GemmaService for analysis...")
                let riskAssessment = try await GemmaService.shared.analyzeDrivingRisk(healthData)
                
                print("✅ [WatchDataReceiver] Risk assessment received from Gemma:")
                print("   - Risk Level: \(riskAssessment.riskLevel)")
                print("   - Risk Factors: \(riskAssessment.riskFactors.count)")
                print("   - Recommendations: \(riskAssessment.recommendations.count)")
                
                // Store the assessment
                await MainActor.run {
                    self.storeRiskAssessment(riskAssessment)
                }
                
                // Send results back to Watch
                print("📤 [WatchDataReceiver] Preparing to send results back to Watch...")
                let riskAssessmentData: [String: Any] = [
                    "riskLevel": riskAssessment.riskLevel.rawValue,
                    "riskFactors": riskAssessment.riskFactors.map { factor in [
                        "type": factor.type.rawValue,
                        "severity": factor.severity.rawValue,
                        "description": factor.description,
                        "value": factor.value
                    ] },
                    "recommendations": riskAssessment.recommendations,
                    "timestamp": Date().timeIntervalSince1970
                ]
                
                if let replyHandler = replyHandler {
                    // Send via reply handler
                    print("📤 [WatchDataReceiver] Sending results via reply handler...")
                    replyHandler(["riskAssessment": riskAssessmentData])
                    print("✅ [WatchDataReceiver] Results sent via reply handler")
                } else {
                    // Send via message
                    print("📤 [WatchDataReceiver] Sending results via message...")
                    sendRiskAssessmentToWatch(riskAssessment)
                }
                
            } catch {
                print("Error analyzing health data with Gemma: \(error)")
                if let replyHandler = replyHandler {
                    replyHandler(["status": "error", "message": error.localizedDescription])
                }
            }
        }
    }
    
    private func storeRiskAssessment(_ assessment: DrivingRiskAssessment) {
        // Store in SwiftData for persistence (commented out until SwiftData is implemented)
        // let conversation = Conversation(
        //     prompt: "Health data analysis request",
        //     response: assessment.formattedResponse,
        //     timestamp: Date(),
        //     isFavorite: false,
        //     tags: ["risk_assessment", "health_analysis"]
        // )
        // 
        // Save to model context (you'll need to inject this)
        // modelContext.insert(conversation)
        
        // For now, just log the assessment
        print("📊 [WatchDataReceiver] Risk assessment stored: \(assessment.riskLevel.rawValue)")
    }
    
    private func sendRiskAssessmentToWatch(_ assessment: DrivingRiskAssessment) {
        guard let session = session, session.isReachable else { return }
        
        let message: [String: Any] = [
            "type": "risk_assessment_result",
            "riskLevel": assessment.riskLevel.rawValue,
            "riskFactors": assessment.riskFactors.map { factor in [
                "type": factor.type.rawValue,
                "severity": factor.severity.rawValue,
                "description": factor.description,
                "value": factor.value
            ] },
            "recommendations": assessment.recommendations,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        session.sendMessage(message, replyHandler: { reply in
            print("Risk assessment sent to Watch successfully")
        }, errorHandler: { error in
            print("Failed to send risk assessment to Watch: \(error)")
        })
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

struct HealthDataFromWatch: Codable {
    let timestamp: Date
    let heartRate: [HealthDataPoint]
    let hrv: [HealthDataPoint]
    let bloodOxygen: [HealthDataPoint]
    let respiratoryRate: [HealthDataPoint]
    let stepCount: [HealthDataPoint]
    let activeEnergy: [HealthDataPoint]
    
    var latestHeartRate: Double {
        heartRate.last?.value ?? 0.0
    }
    
    var latestHRV: Double {
        hrv.last?.value ?? 0.0
    }
    
    var latestBloodOxygen: Double {
        bloodOxygen.last?.value ?? 0.0
    }
    
    var latestRespiratoryRate: Double {
        respiratoryRate.last?.value ?? 0.0
    }
    
    var latestStepCount: Int {
        Int(stepCount.last?.value ?? 0.0)
    }
    
    var latestActiveEnergy: Double {
        activeEnergy.last?.value ?? 0.0
    }
    
    // Format data for Gemma analysis
    var formattedForGemma: String {
        """
        Current Health Data:
        - Heart Rate: \(latestHeartRate) BPM
        - Heart Rate Variability: \(latestHRV) ms
        - Blood Oxygen: \(latestBloodOxygen * 100)%%
        - Respiratory Rate: \(latestRespiratoryRate) breaths/min
        - Step Count: \(latestStepCount) steps
        - Active Energy: \(latestActiveEnergy) kcal
        
        Please analyze this data for driving risk assessment and provide recommendations.
        """
    }
}

// MARK: - Risk Assessment Extension

extension DrivingRiskAssessment {
    var formattedResponse: String {
        var response = "Driving Risk Assessment:\n\n"
        response += "Risk Level: \(riskLevel.rawValue)\n\n"
        
        if !riskFactors.isEmpty {
            response += "Risk Factors:\n"
            for factor in riskFactors {
                response += "- \(factor.description) (\(String(format: "%.1f", factor.value)))\n"
            }
            response += "\n"
        }
        
        if !recommendations.isEmpty {
            response += "Recommendations:\n"
            for (index, recommendation) in recommendations.enumerated() {
                response += "\(index + 1). \(recommendation)\n"
            }
        }
        
        return response
    }
}

// MARK: - Risk Factor Type Extension

extension RiskFactorType {
    var rawValue: String {
        switch self {
        case .elevatedHeartRate:
            return "elevated_heart_rate"
        case .lowHRV:
            return "low_hrv"
        case .lowBloodOxygen:
            return "low_blood_oxygen"
        case .elevatedRespiratoryRate:
            return "elevated_respiratory_rate"
        case .fatigue:
            return "fatigue"
        }
    }
} 