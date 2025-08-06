//
//  DrivingRiskView.swift
//  DriveSenseWatch Watch App
//
//  Created by Karthikeyan Lakshminarayanan on 01/08/25.
//

import SwiftUI

struct DrivingRiskView: View {
    @StateObject private var healthManager = HealthKitManager.shared
    @StateObject private var backgroundTaskManager = BackgroundTaskManager.shared

    @State private var currentRiskAssessment: DrivingRiskAssessment?
    @State private var refreshCountdown = 30
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 8) {
            // Driving Risk Header
            drivingRiskHeader
            
            // Location Status
            locationStatusSection
            
            // Health Metrics
            healthMetricsSection
            
            // Wellness Advice
            wellnessAdviceSection
            
            // Voice Stress
            voiceStressSection
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black)
        .onAppear {
            loadStoredRiskAssessment()
            setupNotificationObserver()
        }
        .onReceive(timer) { _ in
            updateCountdown()
        }
        .onReceive(healthManager.$lastUpdateTime) { _ in
            // Health data updated - trigger location-based monitoring
            backgroundTaskManager.sendCurrentHealthData()
        }
    }
    
    // MARK: - Driving Risk Header
    
    private var drivingRiskHeader: some View {
        HStack {
            Image(systemName: "car.fill")
                .foregroundColor(riskColor)
                .font(.title2)
            
            Text("\(riskStatus) Risk!")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(riskColor)
            
            Spacer()
        }
    }
    
    // MARK: - Health Metrics Section
    
    private var healthMetricsSection: some View {
        HStack {
            Image(systemName: "heart.fill")
                .foregroundColor(.red)
                .font(.caption)
            
            Text("HR: \(Int(healthManager.currentHeartRate)) bpm")
                .font(.caption)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
    
    // MARK: - Wellness Advice Section
    
    private var wellnessAdviceSection: some View {
        HStack {
            Image(systemName: "wind")
                .foregroundColor(.blue)
                .font(.caption)
            
            Text("Breath calmly")
                .font(.caption)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
    
    // MARK: - Location Status Section
    
    private var locationStatusSection: some View {
        HStack {
            Image(systemName: "location.fill")
                .foregroundColor(locationStatusColor)
                .font(.caption)
            
            Text("Location: \(locationStatusText)")
                .font(.caption)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
    
    // MARK: - Voice Stress Section
    
    private var voiceStressSection: some View {
        HStack {
            Image(systemName: "mic.fill")
                .foregroundColor(.purple)
                .font(.caption)
            
            Text("Voice Stress: \(voiceStressLevel)")
                .font(.caption)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateCountdown() {
        if refreshCountdown > 0 {
            refreshCountdown -= 1
        } else {
            refreshCountdown = 30
            // Request new risk assessment from iPhone
            backgroundTaskManager.sendCurrentHealthData()
        }
    }
    
    private func loadStoredRiskAssessment() {
        // Load the last risk assessment from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "lastRiskAssessment"),
           let assessment = try? JSONDecoder().decode(DrivingRiskAssessment.self, from: data) {
            currentRiskAssessment = assessment
        }
    }
    
    private func setupNotificationObserver() {
        // Listen for risk assessment updates from BackgroundTaskManager
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RiskAssessmentUpdated"),
            object: nil,
            queue: .main
        ) { notification in
            if let assessment = notification.object as? DrivingRiskAssessment {
                self.currentRiskAssessment = assessment
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var riskScore: Int {
        guard let assessment = currentRiskAssessment else { return 0 }
        
        switch assessment.riskLevel {
        case .low:
            return Int.random(in: 1...3)
        case .medium:
            return Int.random(in: 4...6)
        case .high:
            return Int.random(in: 7...10)
        }
    }
    
    private var riskStatus: String {
        guard let assessment = currentRiskAssessment else { return "Analyzing" }
        
        switch assessment.riskLevel {
        case .low:
            return "Low"
        case .medium:
            return "Moderate"
        case .high:
            return "High"
        }
    }
    
    private var voiceStressLevel: String {
        guard let assessment = currentRiskAssessment else { return "Analyzing" }
        
        switch assessment.riskLevel {
        case .low:
            return "Low"
        case .medium:
            return "Mild"
        case .high:
            return "High"
        }
    }
    
    private var locationStatusText: String {
        // This would need to be connected to BackgroundTaskManager's location status
        return "Active"
    }
    
    private var locationStatusColor: Color {
        // This would need to be connected to BackgroundTaskManager's location status
        return .green
    }
    
    private var riskColor: Color {
        guard let assessment = currentRiskAssessment else { return .gray }
        
        switch assessment.riskLevel {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
    
    private var riskIcon: String {
        guard let assessment = currentRiskAssessment else { return "questionmark.circle" }
        
        switch assessment.riskLevel {
        case .low:
            return "checkmark.circle"
        case .medium:
            return "exclamationmark.triangle"
        case .high:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var lastUpdateTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: healthManager.lastUpdateTime)
    }
    

}

#Preview {
    DrivingRiskView()
} 