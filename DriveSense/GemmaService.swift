//
//  GemmaService.swift
//  DriveSense
//
//  Created by Karthikeyan Lakshminarayanan on 01/08/25.
//

import Foundation
import SwiftUI
@preconcurrency import MediaPipeTasksGenAI

@MainActor
class GemmaService: ObservableObject {
    static let shared = GemmaService()
    
    @Published var isGenerating = false
    @Published var currentResponse = ""
    @Published var errorMessage: String?
    
    // Cache for sharing AI results between concurrent requests
    private var lastAssessment: DrivingRiskAssessment?
    private var lastAssessmentTimestamp: Date = Date.distantPast
    
    // MediaPipe LLM Inference properties
    private var llmInference: LlmInference?
    private var isModelLoaded = false
    private var isLoadingModel = false  // Prevent multiple simultaneous loads
    
    init() {
        // Initialize with default settings
        Task {
            await loadGemmaModel()
        }
    }
    
    // MARK: - MediaPipe Gemma Model Management
    
    private func loadGemmaModel() async {
        // Prevent multiple simultaneous loads
        guard !isLoadingModel else {
            print("🔄 [GemmaService] Model loading already in progress, skipping...")
            return
        }
        
        isLoadingModel = true
        print("🤖 [GemmaService] Loading Gemma model...")
        
        // Clean up memory before loading
        cleanupMemory()
        
        // Step 1: Copy model to writable cache directory
        guard let writableModelPath = copyModelToCachesDirectory() else {
            print("❌ [GemmaService] Failed to copy model to cache directory")
            isModelLoaded = false
            errorMessage = "AI model temporarily unavailable. Using intelligent rule-based analysis for driving safety."
            isLoadingModel = false
            return
        }
        
        print("📁 [GemmaService] Writable model path: \(writableModelPath)")
        
        // Step 2: Try simple initialization with writable path
        do {
            llmInference = try LlmInference(modelPath: writableModelPath)
            isModelLoaded = true
            print("✅ [GemmaService] Gemma model loaded successfully with writable path!")
            return
        } catch {
            print("⚠️ [GemmaService] Simple initialization failed: \(error.localizedDescription)")
            
            // Check if this is a .bin file (different format)
            if writableModelPath.hasSuffix(".bin") {
                print("⚠️ [GemmaService] .bin format detected - this format requires conversion for MediaPipe")
                print("🔄 [GemmaService] Falling back to rule-based analysis")
                isModelLoaded = false
                errorMessage = "AI model format not compatible. Using intelligent rule-based analysis for driving safety."
                return
            }
        }
        
        // Step 3: If simple initialization fails, try with memory-optimized options
        print("🔄 [GemmaService] Trying initialization with memory-optimized options...")
        do {
            let options = LlmInference.Options(modelPath: writableModelPath)
            
                                // Memory optimization settings (using only valid MediaPipe properties)
                    options.maxTokens = 512  // Increased to accommodate longer prompts and responses
                    options.maxTopk = 40     // Match MediaPipe default to avoid conflicts
                    options.waitForWeightUploads = false  // Don't wait for weights to upload
                    options.useSubmodel = true  // Enable submodel for memory optimization
            
            llmInference = try LlmInference(options: options)
            isModelLoaded = true
            print("✅ [GemmaService] Gemma model loaded successfully with memory-optimized options!")
            return
        } catch {
            print("⚠️ [GemmaService] Memory-optimized initialization failed: \(error.localizedDescription)")
        }
        
        // Step 4: Try with minimal settings as last resort
        print("🔄 [GemmaService] Trying initialization with minimal settings...")
        do {
                                let minimalOptions = LlmInference.Options(modelPath: writableModelPath)
                    minimalOptions.maxTokens = 256  // Minimal but sufficient token limit
                    minimalOptions.maxTopk = 40     // Match MediaPipe default to avoid conflicts
                    minimalOptions.useSubmodel = true  // Enable submodel
                    minimalOptions.waitForWeightUploads = false
            
            llmInference = try LlmInference(options: minimalOptions)
            isModelLoaded = true
            print("✅ [GemmaService] Gemma model loaded successfully with minimal settings!")
            return
        } catch {
            print("❌ [GemmaService] Minimal initialization also failed: \(error.localizedDescription)")
        }
        
        // If we reach here, all initialization attempts failed for the larger model
        print("❌ [GemmaService] All initialization attempts failed for larger model")
        
        // Try the smaller model as fallback
        print("🔄 [GemmaService] Trying smaller model as fallback...")
        if let smallerModelPath = copySpecificModelToCache(modelName: "gemma-2b-it-gpu-int4", fileExtension: "bin") {
            print("✅ [GemmaService] Found smaller model: gemma-2b-it-gpu-int4.bin")
            
            // Check if this is a .bin file (different format)
            if smallerModelPath.hasSuffix(".bin") {
                print("✅ [GemmaService] .bin format detected - using MediaPipe .bin initialization")
                
                // Try to load the smaller .bin model with proper MediaPipe initialization
                let options = LlmInference.Options(modelPath: smallerModelPath)
                
                // Configure options for .bin format (using available MediaPipe properties)
                options.maxTokens = 512  // Increased to accommodate longer prompts and responses
                options.maxTopk = 40     // Match MediaPipe default to avoid conflicts
                options.useSubmodel = true  // Enable submodel for memory optimization
                options.waitForWeightUploads = false
                
                do {
                    llmInference = try LlmInference(options: options)
                    isModelLoaded = true
                    print("✅ [GemmaService] Smaller .bin model loaded successfully!")
                    isLoadingModel = false
                    return
                } catch {
                    print("❌ [GemmaService] Smaller .bin model failed: \(error.localizedDescription)")
                }
            } else {
                // Try to load the smaller model (if it's not .bin)
                do {
                    llmInference = try LlmInference(modelPath: smallerModelPath)
                    isModelLoaded = true
                    print("✅ [GemmaService] Smaller model loaded successfully!")
                    isLoadingModel = false
                    return
                } catch {
                    print("❌ [GemmaService] Smaller model also failed: \(error.localizedDescription)")
                }
            }
        } else {
            print("⚠️ [GemmaService] Smaller model not found in bundle")
        }
        
        // If we reach here, all models failed
        print("❌ [GemmaService] All models failed to load")
        print("🔄 [GemmaService] Falling back to rule-based analysis")
        isModelLoaded = false
        
        // Set a user-friendly message
        errorMessage = "AI model temporarily unavailable. Using intelligent rule-based analysis for driving safety."
        
        // The app will still work with fallback analysis
        // Users will get intelligent rule-based responses instead of AI
        
        // Always reset loading flag
        isLoadingModel = false
    }
    
    // MARK: - Memory Management
    
    private func cleanupMemory() {
        // Force garbage collection and memory cleanup
        autoreleasepool {
            // Clear any cached responses
            currentResponse = ""
            
            // Log memory status
            let memoryInfo = ProcessInfo.processInfo
            print("🧠 [GemmaService] Memory usage: \(memoryInfo.physicalMemory / 1024 / 1024) MB")
        }
    }
    
    // MARK: - Model File Management
    
    private func copyModelToCachesDirectory() -> String? {
        // Always try the larger model first (3.1GB)
        print("🔄 [GemmaService] Attempting to load larger model first...")
        if let modelPath = copySpecificModelToCache(modelName: "gemma-3n-E2B-it-int4", fileExtension: "task") {
            print("✅ [GemmaService] Found larger model: gemma-3n-E2B-it-int4.task")
            return modelPath
        }
        
        print("⚠️ [GemmaService] Larger model not found, will try smaller model as fallback")
        return nil
    }
    
    private func copySpecificModelToCache(modelName: String, fileExtension: String) -> String? {
        let modelFileName = "\(modelName).\(fileExtension)"
        
        // Get the model URL from the app bundle
        guard let bundleURL = Bundle.main.url(forResource: modelName, withExtension: fileExtension) else {
            print("⚠️ [GemmaService] Model not found in bundle: \(modelFileName)")
            return nil
        }
        
        let fileManager = FileManager.default
        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let destinationURL = cachesURL.appendingPathComponent(modelFileName)
        
        print("📁 [GemmaService] Bundle model path: \(bundleURL.path)")
        print("📁 [GemmaService] Cache destination path: \(destinationURL.path)")
        
        // Check if model already exists in cache
        if fileManager.fileExists(atPath: destinationURL.path) {
            print("✅ [GemmaService] Model already exists in cache")
            return destinationURL.path
        }
        
        // Copy model to cache directory
        do {
            try fileManager.copyItem(at: bundleURL, to: destinationURL)
            print("✅ [GemmaService] Successfully copied model to cache: \(destinationURL.path)")
            return destinationURL.path
        } catch {
            print("❌ [GemmaService] Error copying model: \(error.localizedDescription)")
            return nil
        }
    }
    
    func generateResponse(for prompt: String) async {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter a valid prompt"
            return
        }
        
        isGenerating = true
        currentResponse = ""
        errorMessage = nil
        
        do {
            // Check if model is loaded
            guard isModelLoaded, let llmInference = llmInference else {
                errorMessage = "Gemma model not loaded. Using fallback analysis."
                // Use fallback analysis
                let response = generateFallbackResponse(for: prompt)
                currentResponse = response
                return
            }
            
            // Generate response using MediaPipe Gemma model with streaming
            let response = try await generateWithGemmaStreaming(prompt: prompt, llmInference: llmInference)
            currentResponse = response
        } catch {
            errorMessage = "Error generating response: \(error.localizedDescription)"
            // Use fallback response
            let response = generateFallbackResponse(for: prompt)
            currentResponse = response
        }
        
        isGenerating = false
    }
    
    func clearResponse() {
        currentResponse = ""
        errorMessage = nil
    }
    
    func saveConversation(prompt: String, response: String) -> Conversation {
        let conversation = Conversation(
            prompt: prompt,
            response: response,
            timestamp: Date()
        )
        return conversation
    }
    
    // MARK: - MediaPipe Gemma Inference
    
    private func generateWithGemmaStreaming(prompt: String, llmInference: LlmInference) async throws -> String {
        print("🤖 [GemmaService] Generating response with Gemma model...")
        print("📝 [GemmaService] Input prompt: \(prompt.prefix(200))...")
        
        // Run AI inference on background thread (no timeout)
        return try await withCheckedThrowingContinuation { continuation in
            // Capture llmInference for background thread
            let inference = llmInference
            
            // Use background queue for AI inference
            print("🔄 [GemmaService] Starting AI inference on background thread...")
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    do {
                        print("🔄 [GemmaService] Calling MediaPipe generateResponse on background thread...")
                        
                        // Update UI to show processing (on main thread)
                        DispatchQueue.main.async {
                            print("⏳ [GemmaService] AI processing in progress... (UI remains responsive)")
                        }
                        
                        // Generate response with streaming
                        let response = try inference.generateResponse(inputText: prompt)
                        
                        // Process the response
                        let fullResponse = response
                        
                        print("✅ [GemmaService] Gemma response generated successfully on background thread!")
                        print("📄 [GemmaService] Response length: \(fullResponse.count) characters")
                        print("📝 [GemmaService] Response preview: \(fullResponse.prefix(200))...")
                        
                        // Resume on main thread
                        DispatchQueue.main.async {
                            continuation.resume(returning: fullResponse)
                        }
                    } catch {
                        print("❌ [GemmaService] Error generating response: \(error.localizedDescription)")
                        print("❌ [GemmaService] Error details: \(error)")
                        
                        // Resume on main thread
                        DispatchQueue.main.async {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }
    }
    
    private func generateFallbackResponse(for prompt: String) -> String {
        print("🔄 [GemmaService] Using fallback response generation...")
        
        // Enhanced fallback response based on prompt content
        if prompt.lowercased().contains("heart rate") && prompt.lowercased().contains("blood oxygen") {
            return "Based on your heart rate and blood oxygen data, I recommend monitoring your cardiovascular health and respiratory function. If your heart rate is elevated (>100 BPM) or blood oxygen is low (<95%), consider taking a break before driving. Ensure proper ventilation and stay hydrated."
        } else if prompt.lowercased().contains("heart rate") {
            return "Your heart rate data indicates your cardiovascular status. If your heart rate is elevated (>100 BPM), this may indicate stress or physical exertion. Consider taking a short break to allow your heart rate to normalize before driving. Stay hydrated and practice deep breathing exercises."
        } else if prompt.lowercased().contains("blood oxygen") {
            return "Blood oxygen levels are crucial for alertness and cognitive function. If your levels are below 95%, ensure proper ventilation in your vehicle and consider postponing driving until levels improve. Low oxygen can affect reaction times and decision-making."
        } else if prompt.lowercased().contains("driving risk") {
            return "I've analyzed your health data for driving risk assessment. Based on the available metrics, ensure you're well-rested, alert, and in good physical condition before driving. Take regular breaks every 2 hours during long journeys and stay hydrated."
        } else if prompt.lowercased().contains("health data") {
            return "I've reviewed your health metrics for driving safety. Your current readings appear to be within normal ranges, but always prioritize safety when driving. Remember to take breaks, stay hydrated, and ensure you're well-rested before getting behind the wheel."
        } else {
            return "Thank you for sharing your health data. I recommend maintaining good driving practices: ensure adequate rest, stay hydrated, take regular breaks, and always prioritize safety. Your health metrics are being monitored for optimal driving conditions."
        }
    }
    
    // MARK: - Health Data Analysis
    
    func analyzeDrivingRisk(_ healthData: HealthDataFromWatch) async throws -> DrivingRiskAssessment {
        print("🔍 [GemmaService] Starting driving risk analysis...")
        
        // Check if already analyzing - if so, wait for the current request to complete
        if isGenerating {
            print("⏳ [GemmaService] Analysis already in progress, waiting for completion...")
            // Wait for the current request to complete (up to 30 seconds)
            for _ in 0..<30 {
                if !isGenerating {
                    break
                }
                try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
            }
            
            // If still generating after 30 seconds, use fallback
            if isGenerating {
                print("⚠️ [GemmaService] Analysis timeout, using fallback assessment")
                return generateFallbackAssessment(healthData: healthData)
            }
            
            // Check if we have a recent cached result (within last 5 seconds)
            if let cachedAssessment = lastAssessment,
               Date().timeIntervalSince(lastAssessmentTimestamp) < 5.0 {
                print("✅ [GemmaService] Using cached AI result from recent analysis")
                return cachedAssessment
            }
        }
        
        print("📊 [GemmaService] Health data received:")
        print("   - Heart Rate: \(healthData.latestHeartRate) BPM")
        print("   - HRV: \(healthData.latestHRV) ms")
        print("   - Blood Oxygen: \(healthData.latestBloodOxygen)%")
        print("   - Respiratory Rate: \(healthData.latestRespiratoryRate) breaths/min")
        print("   - Step Count: \(healthData.latestStepCount) steps")
        print("   - Active Energy: \(healthData.latestActiveEnergy) kcal")

        // Create dynamic prompt based on available data
        let prompt = createDynamicPrompt(healthData: healthData)
        print("🤖 [GemmaService] Created dynamic prompt based on available data")
        print("📝 [GemmaService] Prompt: \(prompt)")

        print("🚀 [GemmaService] Starting AI analysis...")
        
        // Show loading state
        isGenerating = true

        // Let Gemma analyze the data and return assessment
        let assessment = try await generateGemmaAssessment(prompt: prompt, healthData: healthData)
        
        // Cache the result for potential concurrent requests
        lastAssessment = assessment
        lastAssessmentTimestamp = Date()
        
        // Hide loading state
        isGenerating = false
        
        print("✅ [GemmaService] Gemma analysis completed:")
        print("   - Risk Level: \(assessment.riskLevel)")
        print("   - Risk Factors: \(assessment.riskFactors.count)")
        print("   - Recommendations: \(assessment.recommendations.count)")

        return assessment
    }
    
    private func createDynamicPrompt(healthData: HealthDataFromWatch) -> String {
        var availableMetrics: [String] = []
        var prompt = "As a driving safety AI assistant, analyze the following health data to assess driving risk. "
        
        // Check what data is available and add to prompt
        if !healthData.heartRate.isEmpty {
            availableMetrics.append("Heart Rate: \(Int(healthData.latestHeartRate)) BPM")
        }
        
        if !healthData.hrv.isEmpty {
            availableMetrics.append("Heart Rate Variability: \(Int(healthData.latestHRV)) ms")
        }
        
        if !healthData.bloodOxygen.isEmpty {
            availableMetrics.append("Blood Oxygen: \(Int(healthData.latestBloodOxygen))%")
        }
        
        if !healthData.respiratoryRate.isEmpty {
            availableMetrics.append("Respiratory Rate: \(Int(healthData.latestRespiratoryRate)) breaths/min")
        }
        
        if !healthData.stepCount.isEmpty {
            availableMetrics.append("Step Count: \(healthData.latestStepCount) steps")
        }
        
        if !healthData.activeEnergy.isEmpty {
            availableMetrics.append("Active Energy: \(Int(healthData.latestActiveEnergy)) kcal")
        }
        
        // Add available metrics to prompt
        prompt += "Available health metrics: \(availableMetrics.joined(separator: ", ")). "
        
        // Add context based on available data
        if availableMetrics.count == 1 {
            prompt += "Only heart rate data is available. "
        } else if availableMetrics.count >= 3 {
            prompt += "Multiple health metrics are available for comprehensive analysis. "
        }
        
        // Add specific analysis instructions
        prompt += """
        
        Analyze this health data for driving risk:
        
        1. Risk Level: LOW/MEDIUM/HIGH
        2. Risk Factors: List specific health issues
        3. Recommendations: 3-5 actionable safety tips
        
        Guidelines:
        - Heart Rate: Normal range 60-100 BPM, only consider elevated if >100 BPM
        - Blood Oxygen: Normal range 95-100%, only consider low if <95%
        - HRV: Lower values may indicate stress
        - Step Count: Very low activity may indicate fatigue
        - Active Energy: Low energy may indicate tiredness
        
        CRITICAL RULES:
        - ONLY use the provided health data. Do NOT assume conditions not indicated by the data.
        - If heart rate is 60-100 BPM, it is NORMAL - do NOT flag as risk.
        - If blood oxygen is not provided or is 0%, do NOT assume it's low.
        - Do NOT mention blood pressure unless it's provided in the data.
        - Do NOT mention chronic conditions unless they're in the data.
        - If all provided values are normal, assess as LOW risk.
        
        Format: Start with "## Driving Risk Assessment", state risk level clearly, list factors, provide recommendations.
        """
        
        return prompt
    }
    
    private func generateGemmaAssessment(prompt: String, healthData: HealthDataFromWatch) async throws -> DrivingRiskAssessment {
        print("🤖 [GemmaService] Generating Gemma assessment...")
        print("🔍 [GemmaService] Model status - isModelLoaded: \(isModelLoaded), llmInference: \(llmInference != nil)")
        
        // Check if model is loaded
        guard isModelLoaded, let llmInference = llmInference else {
            print("⚠️ [GemmaService] Model not loaded, using fallback assessment")
            return generateFallbackAssessment(healthData: healthData)
        }
        
        // Note: Multiple request handling is done at the analyzeDrivingRisk level
        
        do {
            print("🚀 [GemmaService] Starting AI generation with Gemma model...")
            // Generate response using actual Gemma model
            let gemmaResponse = try await generateWithGemmaStreaming(prompt: prompt, llmInference: llmInference)
            print("📝 [GemmaService] Gemma response: \(gemmaResponse)")
            
            // Parse Gemma's response to extract risk assessment
            let assessment = parseGemmaResponse(gemmaResponse, healthData: healthData)
            
            print("🎯 [GemmaService] Gemma assessment generated successfully")
            return assessment
        } catch {
            print("❌ [GemmaService] Gemma model failed, using fallback: \(error.localizedDescription)")
            return generateFallbackAssessment(healthData: healthData)
        }
    }
    
    private func generateFallbackAssessment(healthData: HealthDataFromWatch) -> DrivingRiskAssessment {
        print("🔄 [GemmaService] Generating fallback assessment...")
        
        // Simple fallback assessment based on available data
        var riskLevel: RiskLevel = .low
        var riskFactors: [RiskFactor] = []
        var recommendations: [String] = []
        
        // Check heart rate
        if !healthData.heartRate.isEmpty {
            if healthData.latestHeartRate > 120 {
                riskLevel = .high
                riskFactors.append(RiskFactor(
                    type: .elevatedHeartRate,
                    severity: .high,
                    description: "Elevated heart rate - \(Int(healthData.latestHeartRate)) BPM",
                    value: healthData.latestHeartRate
                ))
                recommendations.append("Consider taking a break. Your heart rate is elevated.")
            } else if healthData.latestHeartRate > 100 {
                riskLevel = max(riskLevel, .medium)
                riskFactors.append(RiskFactor(
                    type: .elevatedHeartRate,
                    severity: .medium,
                    description: "Slightly elevated heart rate - \(Int(healthData.latestHeartRate)) BPM",
                    value: healthData.latestHeartRate
                ))
                recommendations.append("Monitor your heart rate and take breaks if needed.")
            }
        }
        
        // Check blood oxygen
        if !healthData.bloodOxygen.isEmpty {
            if healthData.latestBloodOxygen < 95 {
                riskLevel = max(riskLevel, .medium)
                riskFactors.append(RiskFactor(
                    type: .lowBloodOxygen,
                    severity: .medium,
                    description: "Low blood oxygen - \(Int(healthData.latestBloodOxygen))%",
                    value: healthData.latestBloodOxygen
                ))
                recommendations.append("Ensure proper ventilation in your vehicle.")
            }
        }
        
        // Add general recommendations
        if recommendations.isEmpty {
            recommendations.append("Your health metrics appear normal. Continue driving safely.")
            recommendations.append("Take regular breaks every 2 hours.")
            recommendations.append("Stay hydrated and maintain good posture.")
        }
        
        return DrivingRiskAssessment(
            timestamp: Date(),
            riskLevel: riskLevel,
            riskFactors: riskFactors,
            recommendations: recommendations
        )
    }
    
    private func parseGemmaResponse(_ response: String, healthData: HealthDataFromWatch) -> DrivingRiskAssessment {
        print("🔍 [GemmaService] Parsing Gemma response...")
        
        // Extract risk level from response
        let riskLevel = extractRiskLevel(from: response)
        
        // Extract risk factors from response
        let riskFactors = extractRiskFactors(from: response, healthData: healthData)
        
        // Extract recommendations from response
        let recommendations = extractRecommendations(from: response)
        
        let assessment = DrivingRiskAssessment(
            timestamp: Date(),
            riskLevel: riskLevel,
            riskFactors: riskFactors,
            recommendations: recommendations
        )
        
        print("✅ [GemmaService] Response parsed successfully")
        return assessment
    }
    
    private func extractRiskLevel(from response: String) -> RiskLevel {
        let lowercased = response.lowercased()
        print("🔍 [GemmaService] Parsing risk level from: \(lowercased.prefix(200))...")
        
        // Check for explicit risk level statements
        if lowercased.contains("high risk") || lowercased.contains("risk level: high") || lowercased.contains("high driving risk") || lowercased.contains("**risk level:** high") || lowercased.contains("risk level: high") {
            print("🎯 [GemmaService] Detected HIGH risk level")
            return .high
        } else if lowercased.contains("medium risk") || lowercased.contains("risk level: medium") || lowercased.contains("moderate driving risk") || lowercased.contains("moderate risk level") || lowercased.contains("**risk level:** medium") {
            print("🎯 [GemmaService] Detected MEDIUM risk level")
            return .medium
        } else if lowercased.contains("low risk") || lowercased.contains("risk level: low") || lowercased.contains("low driving risk") || lowercased.contains("**risk level:** low") {
            print("🎯 [GemmaService] Detected LOW risk level")
            return .low
        }
        
        // Check for specific risk indicators
        if lowercased.contains("immediately") || lowercased.contains("stop driving") || lowercased.contains("dangerous") || lowercased.contains("severe") {
            return .high
        } else if lowercased.contains("consider") || lowercased.contains("caution") || lowercased.contains("extreme caution") || lowercased.contains("monitor") {
            return .medium
        } else if lowercased.contains("normal") || lowercased.contains("safe") || lowercased.contains("continue") || lowercased.contains("low") {
            return .low
        }
        
        // Check if AI says it can't analyze (fallback to rule-based)
        if lowercased.contains("cannot calculate") || lowercased.contains("does not provide") || lowercased.contains("no information") {
            print("⚠️ [GemmaService] AI response indicates inability to analyze, using fallback logic")
            return .low  // Default to low when AI can't analyze
        }
        
        // Default to low risk if no clear indicators (conservative approach)
        print("⚠️ [GemmaService] No clear risk indicators found, defaulting to LOW risk")
        return .low
    }
    
    private func extractRiskFactors(from response: String, healthData: HealthDataFromWatch) -> [RiskFactor] {
        var factors: [RiskFactor] = []
        let lowercased = response.lowercased()
        
        // Validate that the AI's assessment is supported by actual data
        let hasValidHealthIssues = validateHealthDataForRiskFactors(healthData: healthData)
        if !hasValidHealthIssues {
            print("⚠️ [GemmaService] AI identified risks but health data shows normal values - ignoring AI assessment")
            return []
        }
        
        // Extract heart rate related factors - only if actually elevated
        if (lowercased.contains("heart rate") || lowercased.contains("elevated")) && healthData.latestHeartRate > 100 {
            if !healthData.heartRate.isEmpty {
                factors.append(RiskFactor(
                    type: .elevatedHeartRate,
                    severity: healthData.latestHeartRate > 120 ? .high : .medium,
                    description: "Elevated heart rate detected - \(Int(healthData.latestHeartRate)) BPM",
                    value: healthData.latestHeartRate
                ))
            }
        }
        
        // Extract HRV related factors
        if lowercased.contains("hrv") || lowercased.contains("heart rate variability") {
            if !healthData.hrv.isEmpty {
                factors.append(RiskFactor(
                    type: .lowHRV,
                    severity: healthData.latestHRV < 20 ? .high : .medium,
                    description: "Low heart rate variability - \(Int(healthData.latestHRV)) ms",
                    value: healthData.latestHRV
                ))
            }
        }
        
        // Extract blood oxygen related factors
        if lowercased.contains("oxygen") || lowercased.contains("spo2") {
            if !healthData.bloodOxygen.isEmpty {
                factors.append(RiskFactor(
                    type: .lowBloodOxygen,
                    severity: healthData.latestBloodOxygen < 95 ? .high : .medium,
                    description: "Low blood oxygen saturation - \(Int(healthData.latestBloodOxygen))%",
                    value: healthData.latestBloodOxygen
                ))
            }
        }
        
        // If no specific factors found, check if AI mentioned any issues
        if factors.isEmpty {
            // Only add fallback factors if AI actually identified issues AND they're supported by data
            if lowercased.contains("risk") || lowercased.contains("elevated") || lowercased.contains("high") {
                // Double-check that the AI's assessment is supported by actual data
                let hasValidRiskFactors = identifyRiskFactors(healthData: healthData)
                if !hasValidRiskFactors.isEmpty {
                    factors = hasValidRiskFactors
                }
            }
        }
        
        return factors
    }
    
    private func validateHealthDataForRiskFactors(healthData: HealthDataFromWatch) -> Bool {
        // Check if any health metrics are actually outside normal ranges
        var hasIssues = false
        
        // Heart rate check
        if !healthData.heartRate.isEmpty && healthData.latestHeartRate > 100 {
            hasIssues = true
        }
        
        // Blood oxygen check
        if !healthData.bloodOxygen.isEmpty && healthData.latestBloodOxygen < 95 {
            hasIssues = true
        }
        
        // HRV check (if available)
        if !healthData.hrv.isEmpty && healthData.latestHRV < 20 {
            hasIssues = true
        }
        
        // If no actual health issues found, return false
        return hasIssues
    }
    
    private func extractRecommendations(from response: String) -> [String] {
        var recommendations: [String] = []
        
        // Split response into lines and look for recommendation patterns
        let lines = response.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Look for numbered recommendations
            if trimmed.range(of: "\\d+\\.\\s+", options: .regularExpression) != nil {
                let recommendation = trimmed.replacingOccurrences(of: "\\d+\\.\\s+", with: "", options: .regularExpression)
                if !recommendation.isEmpty {
                    recommendations.append(recommendation)
                }
            }
            // Look for bullet points
            else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("• ") {
                let recommendation = String(trimmed.dropFirst(2))
                if !recommendation.isEmpty {
                    recommendations.append(recommendation)
                }
            }
            // Look for sentences that sound like recommendations
            else if trimmed.contains("consider") || trimmed.contains("take") || trimmed.contains("practice") || trimmed.contains("ensure") {
                if !trimmed.isEmpty && trimmed.count > 10 {
                    recommendations.append(trimmed)
                }
            }
        }
        
        // If no recommendations found, use fallback
        if recommendations.isEmpty {
            recommendations = [
                "Continue driving safely and monitor your condition",
                "Take regular breaks every 2 hours",
                "Stay hydrated and ensure proper ventilation",
                "Stop driving if you feel unwell"
            ]
        }
        
        return Array(recommendations.prefix(5))
    }
    
    private func determineRiskLevel(healthData: HealthDataFromWatch) -> RiskLevel {
        var riskScore = 0
        
        // Analyze heart rate if available
        if !healthData.heartRate.isEmpty {
            if healthData.latestHeartRate > 120 {
                riskScore += 3
            } else if healthData.latestHeartRate > 100 {
                riskScore += 2
            } else if healthData.latestHeartRate < 50 {
                riskScore += 2
            }
        }
        
        // Analyze HRV if available
        if !healthData.hrv.isEmpty {
            if healthData.latestHRV < 20 {
                riskScore += 3
            } else if healthData.latestHRV < 30 {
                riskScore += 2
            }
        }
        
        // Analyze blood oxygen if available
        if !healthData.bloodOxygen.isEmpty {
            if healthData.latestBloodOxygen < 95 {
                riskScore += 3
            } else if healthData.latestBloodOxygen < 97 {
                riskScore += 1
            }
        }
        
        // Analyze respiratory rate if available
        if !healthData.respiratoryRate.isEmpty {
            if healthData.latestRespiratoryRate > 25 || healthData.latestRespiratoryRate < 10 {
                riskScore += 2
            }
        }
        
        // Determine risk level based on score
        if riskScore >= 5 {
            return .high
        } else if riskScore >= 2 {
            return .medium
        } else {
            return .low
        }
    }
    
    private func identifyRiskFactors(healthData: HealthDataFromWatch) -> [RiskFactor] {
        var factors: [RiskFactor] = []
        
        // Check heart rate
        if !healthData.heartRate.isEmpty {
            if healthData.latestHeartRate > 120 {
                factors.append(RiskFactor(
                    type: .elevatedHeartRate,
                    severity: .high,
                    description: "Elevated heart rate - \(Int(healthData.latestHeartRate)) BPM",
                    value: healthData.latestHeartRate
                ))
            } else if healthData.latestHeartRate > 100 {
                factors.append(RiskFactor(
                    type: .elevatedHeartRate,
                    severity: .medium,
                    description: "Slightly elevated heart rate - \(Int(healthData.latestHeartRate)) BPM",
                    value: healthData.latestHeartRate
                ))
            }
        }
        
        // Check HRV
        if !healthData.hrv.isEmpty {
            if healthData.latestHRV < 20 {
                factors.append(RiskFactor(
                    type: .lowHRV,
                    severity: .high,
                    description: "Low heart rate variability - \(Int(healthData.latestHRV)) ms",
                    value: healthData.latestHRV
                ))
            } else if healthData.latestHRV < 30 {
                factors.append(RiskFactor(
                    type: .lowHRV,
                    severity: .medium,
                    description: "Reduced heart rate variability - \(Int(healthData.latestHRV)) ms",
                    value: healthData.latestHRV
                ))
            }
        }
        
        // Check blood oxygen
        if !healthData.bloodOxygen.isEmpty {
            if healthData.latestBloodOxygen < 95 {
                factors.append(RiskFactor(
                    type: .lowBloodOxygen,
                    severity: .high,
                    description: "Low blood oxygen saturation - \(Int(healthData.latestBloodOxygen))%",
                    value: healthData.latestBloodOxygen
                ))
            }
        }
        
        return factors
    }
    
    private func generateDynamicRecommendations(healthData: HealthDataFromWatch, riskLevel: RiskLevel) -> [String] {
        var recommendations: [String] = []
        
        // Base recommendations based on risk level
        switch riskLevel {
        case .low:
            recommendations.append("Continue driving safely. Your health metrics are within normal ranges.")
            recommendations.append("Maintain regular breaks every 2 hours and stay hydrated.")
            
        case .medium:
            recommendations.append("Consider taking a short break to rest and recover.")
            recommendations.append("Practice deep breathing exercises to reduce stress.")
            
        case .high:
            recommendations.append("Immediately find a safe place to pull over and rest.")
            recommendations.append("Consider calling for assistance if needed.")
        }
        
        // Specific recommendations based on available data
        if !healthData.heartRate.isEmpty && healthData.latestHeartRate > 100 {
            recommendations.append("Your heart rate is elevated. Take time to relax and practice deep breathing.")
        }
        
        if !healthData.hrv.isEmpty && healthData.latestHRV < 30 {
            recommendations.append("Your heart rate variability indicates stress. Practice mindfulness techniques.")
        }
        
        if !healthData.bloodOxygen.isEmpty && healthData.latestBloodOxygen < 97 {
            recommendations.append("Ensure proper ventilation and consider medical attention if symptoms persist.")
        }
        
        // Add general safety recommendation
        recommendations.append("Prioritize your safety and the safety of others on the road.")
        
        return Array(recommendations.prefix(5))
    }
    
    private func extractRecommendationsFromResponse(_ response: String) -> [String] {
        // Simple extraction of recommendations from Gemma response
        let lines = response.components(separatedBy: .newlines)
        var recommendations: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased().contains("recommend") || 
               trimmed.lowercased().contains("suggest") ||
               trimmed.lowercased().contains("advise") ||
               (trimmed.hasPrefix("-") || trimmed.hasPrefix("•") || trimmed.hasPrefix("*")) {
                let cleaned = trimmed.replacingOccurrences(of: "- ", with: "")
                    .replacingOccurrences(of: "• ", with: "")
                    .replacingOccurrences(of: "* ", with: "")
                if !cleaned.isEmpty && cleaned.count > 10 {
                    recommendations.append(cleaned)
                }
            }
        }
        
        return recommendations
    }
    

    
    // MARK: - Helper Methods
    
    private func generateContextualResponse(for prompt: String) -> String {
        let lowercasedPrompt = prompt.lowercased()
        
        if lowercasedPrompt.contains("driving") || lowercasedPrompt.contains("safety") {
            return "Based on your health data, I recommend practicing safe driving habits. Take regular breaks, stay hydrated, and be aware of your physical condition while driving."
        } else if lowercasedPrompt.contains("heart") || lowercasedPrompt.contains("stress") {
            return "Your heart rate and stress indicators suggest taking a moment to relax. Practice deep breathing exercises and consider a short break if you're feeling stressed."
        } else if lowercasedPrompt.contains("fatigue") || lowercasedPrompt.contains("tired") {
            return "Fatigue can significantly impact driving safety. Consider taking a rest break or switching drivers if possible. Your safety is the priority."
        } else {
            return "I'm here to help with your driving safety and health monitoring. Please provide specific health data or ask about driving safety recommendations."
        }
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