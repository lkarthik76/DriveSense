//
//  DashboardView.swift
//  DriveSense
//
//  Created by Karthikeyan Lakshminarayanan on 01/08/25.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @StateObject private var watchReceiver = WatchDataReceiver.shared
    @StateObject private var gemmaService = GemmaService.shared
    @Environment(\.modelContext) private var modelContext
    @State private var currentRiskAssessment: DrivingRiskAssessment?
    @State private var showingDetailedAnalytics = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Driving Risk Section
                    drivingRiskSection
                    
                    // Health Insights Section
                    healthInsightsSection
                    
                    // AI Recommendations Section
                    aiRecommendationsSection
                    
                    // Wellness Advice Section
                    wellnessAdviceSection
                    
                    // Driving Score Section
                    drivingScoreSection
                }
                .padding()
            }
            .navigationTitle("Gemma DriveSense")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
            .onReceive(watchReceiver.$lastReceivedData) { healthData in
                if let data = healthData {
                    analyzeHealthData(data)
                }
            }
            .sheet(isPresented: $showingDetailedAnalytics) {
                DetailedAnalyticsView()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Gemma DriveSense")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("AI-Powered Driving Safety")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Watch Connection Status
            HStack(spacing: 8) {
                Image(systemName: watchReceiver.isWatchConnected ? "applewatch" : "applewatch.slash")
                    .foregroundColor(watchReceiver.isWatchConnected ? .green : .red)
                    .font(.title2)
                
                if watchReceiver.isWatchConnected {
                    Text("Connected")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Driving Risk Section
    
    private var drivingRiskSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "car.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("Driving Risk")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Risk Level Card
            HStack {
                Spacer()
                
                VStack(spacing: 8) {
                    Text(riskLevelText)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(riskLevelColor)
                    
                    Text(riskLevelDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .padding()
            .background(riskLevelColor.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(riskLevelColor, lineWidth: 2)
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Health Insights Section
    
    private var healthInsightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.title2)
                
                Text("Health Insights")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                healthMetricRow(
                    title: "Heart Rate",
                    value: "\(Int(watchReceiver.lastReceivedData?.latestHeartRate ?? 0)) bpm",
                    icon: "heart.fill",
                    color: heartRateColor
                )
                
                healthMetricRow(
                    title: "HRV",
                    value: hrvStatus,
                    icon: "waveform.path.ecg",
                    color: hrvColor
                )
                
                healthMetricRow(
                    title: "Oxygen",
                    value: "\(Int((watchReceiver.lastReceivedData?.latestBloodOxygen ?? 0) * 100))%",
                    icon: "lungs.fill",
                    color: bloodOxygenColor
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func healthMetricRow(title: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 24)
            
            Text("• \(title): \(value)")
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
    
    // MARK: - AI Recommendations Section
    
    private var aiRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                Text("AI Analysis")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // AI Status Indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(gemmaService.isGenerating ? .orange : .green)
                        .frame(width: 8, height: 8)
                    
                    Text(gemmaService.isGenerating ? "Analyzing..." : "AI Ready")
                        .font(.caption)
                        .foregroundColor(gemmaService.isGenerating ? .orange : .green)
                }
            }
            
            if let assessment = currentRiskAssessment {
                // Risk Factors
                if !assessment.riskFactors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🚨 Risk Factors")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                        
                        ForEach(assessment.riskFactors, id: \.description) { factor in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .padding(.top, 2)
                                
                                Text(factor.description)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // AI Recommendations
                if !assessment.recommendations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("💡 AI Recommendations")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        ForEach(Array(assessment.recommendations.enumerated()), id: \.offset) { index, recommendation in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1).")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                    .frame(width: 20, alignment: .leading)
                                
                                Text(recommendation)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            } else {
                // No AI analysis yet
                VStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.gray)
                        .font(.title)
                    
                    Text("AI Analysis Pending")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Connect your Apple Watch to receive AI-powered driving risk analysis")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Wellness Advice Section
    
    private var wellnessAdviceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundColor(.purple)
                    .font(.title2)
                
                Text("Wellness Advice")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(wellnessAdvice)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                if let assessment = currentRiskAssessment, !assessment.recommendations.isEmpty {
                    Text("💡 \(assessment.recommendations.first ?? "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Driving Score Section
    
    private var drivingScoreSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text("Driving Score")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                HStack {
                    Text("\(drivingScore)/100")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(drivingScoreColor)
                    
                    Spacer()
                    
                    // Score Circle
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .trim(from: 0, to: drivingScoreProgress)
                            .stroke(drivingScoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(drivingScore)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(drivingScoreColor)
                    }
                }
                
                Button(action: { showingDetailedAnalytics = true }) {
                    HStack {
                        Text("View Detailed Analytics")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.body)
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Methods
    
    private func analyzeHealthData(_ healthData: HealthDataFromWatch) {
        Task {
            do {
                let assessment = try await gemmaService.analyzeDrivingRisk(healthData)
                await MainActor.run {
                    currentRiskAssessment = assessment
                }
            } catch {
                print("Error analyzing health data: \(error)")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var riskLevelText: String {
        guard let assessment = currentRiskAssessment else { return "Analyzing..." }
        
        switch assessment.riskLevel {
        case .low:
            return "Low"
        case .medium:
            return "Moderate"
        case .high:
            return "High"
        }
    }
    
    private var riskLevelDescription: String {
        guard let assessment = currentRiskAssessment else { return "Analyzing your health data..." }
        
        switch assessment.riskLevel {
        case .low:
            return "Safe to drive"
        case .medium:
            return "Exercise caution"
        case .high:
            return "Consider stopping"
        }
    }
    
    private var riskLevelColor: Color {
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
    
    private var heartRateColor: Color {
        let hr = watchReceiver.lastReceivedData?.latestHeartRate ?? 0
        if hr < 60 { return .blue }
        if hr < 100 { return .green }
        if hr < 120 { return .orange }
        return .red
    }
    
    private var hrvStatus: String {
        let hrv = watchReceiver.lastReceivedData?.latestHRV ?? 0
        if hrv > 50 { return "Good" }
        if hrv > 30 { return "Fair" }
        return "Poor"
    }
    
    private var hrvColor: Color {
        let hrv = watchReceiver.lastReceivedData?.latestHRV ?? 0
        if hrv > 50 { return .green }
        if hrv > 30 { return .orange }
        return .red
    }
    
    private var bloodOxygenColor: Color {
        let spo2 = (watchReceiver.lastReceivedData?.latestBloodOxygen ?? 0) * 100
        if spo2 >= 95 { return .green }
        if spo2 >= 90 { return .orange }
        return .red
    }
    
    private var wellnessAdvice: String {
        guard let assessment = currentRiskAssessment else {
            return "Monitoring your health data for personalized advice..."
        }
        
        switch assessment.riskLevel {
        case .low:
            return "You're showing good health indicators. Continue safe driving practices."
        case .medium:
            return "You're showing mild stress. Take a deep breath and stay alert."
        case .high:
            return "You're showing elevated stress levels. Consider taking a break."
        }
    }
    
    private var drivingScore: Int {
        guard let assessment = currentRiskAssessment else { return 0 }
        
        switch assessment.riskLevel {
        case .low:
            return Int.random(in: 85...100)
        case .medium:
            return Int.random(in: 70...84)
        case .high:
            return Int.random(in: 50...69)
        }
    }
    
    private var drivingScoreColor: Color {
        if drivingScore >= 85 { return .green }
        if drivingScore >= 70 { return .orange }
        return .red
    }
    
    private var drivingScoreProgress: Double {
        return Double(drivingScore) / 100.0
    }
}

// MARK: - Detailed Analytics View

struct DetailedAnalyticsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Detailed Analytics")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Coming Soon...")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text("This section will show detailed health trends, driving patterns, and AI insights over time.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .padding()
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: Conversation.self, inMemory: true)
} 