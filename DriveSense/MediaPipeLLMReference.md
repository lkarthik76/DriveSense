# 📱 MediaPipe LLM Inference iOS Reference

## 🎯 **Complete API Reference for iOS**

Based on the official MediaPipe Tasks GenAI framework headers, here's the complete iOS reference for LLM inference.

## 📋 **Core Classes**

### **1. LlmInference (Main Class)**
```swift
import MediaPipeTasksGenAI

class LlmInference: NSObject {
    // Properties
    var metrics: LlmInference.Metrics { get }
    
    // Initializers
    init(options: LlmInference.Options) throws
    convenience init(modelPath: String) throws
    
    // Methods
    func generateResponse(inputText: String) throws -> String
    func generateResponseAsync(inputText: String, progress: @escaping (String?, Error?) -> Void, completion: @escaping () -> Void) throws
    func generateResponseAsync(inputText: String) -> AsyncThrowingStream<String, Error> // iOS 13+
}
```

### **2. LlmInference.Options (Configuration)**
```swift
class LlmInference.Options: NSObject {
    // Required Properties
    var modelPath: String                    // Path to model file (.task or .bin)
    
    // Optional Properties
    var visionEncoderPath: String            // For vision models
    var visionAdapterPath: String            // For vision models
    var maxTokens: Int                       // Total input + output tokens (default: varies)
    var maxImages: Int                       // Max images for vision (default: varies)
    var maxTopk: Int                         // Max Top-K for GPU (default: 40)
    var supportedLoraRanks: [NSNumber]       // Supported LoRA ranks for GPU
    var waitForWeightUploads: Bool           // Wait for weights to upload (default: false)
    var useSubmodel: Bool                    // Use submodel if available (default: false)
    var sequenceBatchSize: Int               // Batch size for encoding (default: 0 = auto)
    
    // Initializer
    init(modelPath: String)
}
```

### **3. LlmInference.Session (Stateful Inference)**
```swift
class LlmInference.Session: NSObject {
    // Properties
    var metrics: LlmInference.Session.Metrics { get }
    
    // Initializers
    init(llmInference: LlmInference, options: LlmInference.Session.Options) throws
    convenience init(llmInference: LlmInference) throws
    
    // Methods
    func generateResponse(inputText: String) throws -> String
    func generateResponseAsync(inputText: String, progress: @escaping (String?, Error?) -> Void, completion: @escaping () -> Void) throws
    func generateResponseAsync(inputText: String) -> AsyncThrowingStream<String, Error> // iOS 13+
    func clone() throws -> LlmInference.Session
}
```

### **4. LlmInference.Session.Options (Session Configuration)**
```swift
class LlmInference.Session.Options: NSObject {
    // Generation Parameters
    var topk: Int                            // Top-K sampling (default: 40)
    var topp: Float                          // Top-P sampling (default: varies)
    var temperature: Float                   // Randomness (0.0 = greedy, default: 0.8)
    var randomSeed: Int                      // Random seed for sampling
    
    // Advanced Features
    var loraPath: String?                    // LoRA model path (GPU only)
    var enableVisionModality: Bool           // Enable vision features
    
    // Initializer
    init()
}
```

## 🚀 **Usage Examples**

### **Basic Usage (Stateless)**
```swift
import MediaPipeTasksGenAI

// 1. Initialize with model path
let llmInference = try LlmInference(modelPath: "/path/to/gemma-3n-E2B-it-int4.task")

// 2. Generate response
let response = try llmInference.generateResponse(inputText: "Hello, how are you?")
print(response)
```

### **Advanced Usage (With Options)**
```swift
// 1. Create options
let options = LlmInference.Options(modelPath: "/path/to/gemma-3n-E2B-it-int4.task")
options.maxTokens = 1024
options.maxTopk = 40
options.waitForWeightUploads = true

// 2. Initialize with options
let llmInference = try LlmInference(options: options)

// 3. Generate response
let response = try llmInference.generateResponse(inputText: "Explain quantum computing")
print(response)
```

### **Streaming Responses (Async)**
```swift
// iOS 13+ with async/await
let stream = llmInference.generateResponseAsync(inputText: "Write a story about...")

for try await partialResponse in stream {
    print("Partial: \(partialResponse)")
}
```

### **Stateful Sessions**
```swift
// 1. Create session with options
let sessionOptions = LlmInference.Session.Options()
sessionOptions.temperature = 0.7
sessionOptions.topk = 40
sessionOptions.randomSeed = 42

let session = try LlmInference.Session(llmInference: llmInference, options: sessionOptions)

// 2. Generate responses (maintains context)
let response1 = try session.generateResponse(inputText: "What is AI?")
let response2 = try session.generateResponse(inputText: "Tell me more about that.")

// 3. Clone session to continue from same state
let clonedSession = try session.clone()
```

### **Progress Callbacks**
```swift
try llmInference.generateResponseAsync(
    inputText: "Write a long story...",
    progress: { partialResponse, error in
        if let error = error {
            print("Error: \(error)")
        } else if let partial = partialResponse {
            print("Partial: \(partial)")
        }
    },
    completion: {
        print("Generation complete!")
    }
)
```

## ⚙️ **Configuration Guidelines**

### **Model Paths**
- **Gemma-3 1B**: Use `.task` format (no conversion needed)
- **Gemma 2B/7B**: Use `.bin` format (no conversion needed)
- **Path**: Must be absolute path to model file in app bundle

### **Performance Tuning**
```swift
let options = LlmInference.Options(modelPath: modelPath)

// For faster responses
options.maxTokens = 512
options.maxTopk = 20
options.sequenceBatchSize = 1

// For better quality
options.maxTokens = 2048
options.maxTopk = 40
options.waitForWeightUploads = true
```

### **Session Parameters**
```swift
let sessionOptions = LlmInference.Session.Options()

// Creative responses
sessionOptions.temperature = 0.9
sessionOptions.topk = 50
sessionOptions.topp = 0.9

// Focused responses
sessionOptions.temperature = 0.3
sessionOptions.topk = 10
sessionOptions.topp = 0.8
```

## 🔧 **Error Handling**
```swift
do {
    let llmInference = try LlmInference(modelPath: modelPath)
    let response = try llmInference.generateResponse(inputText: prompt)
    print(response)
} catch {
    print("LLM Error: \(error.localizedDescription)")
    
    // Common errors:
    // - Model file not found
    // - Invalid model format
    // - Insufficient memory
    // - GPU not available (for GPU models)
}
```

## 📊 **Metrics & Monitoring**
```swift
// Get initialization metrics
let metrics = llmInference.metrics
print("Initialization time: \(metrics.initializationTimeInSeconds)s")

// Get session metrics
let sessionMetrics = session.metrics
print("Response generation time: \(sessionMetrics.responseGenerationTimeInSeconds)s")
```

## 🎯 **Best Practices**

### **1. Initialization**
- ✅ Initialize on background thread (expensive operation)
- ✅ Use `waitForWeightUploads = true` for consistent timing
- ✅ Handle initialization errors gracefully

### **2. Memory Management**
- ✅ Sessions maintain strong references to LlmInference
- ✅ LlmInference stays in memory until all sessions are destroyed
- ✅ Use sessions for stateful conversations

### **3. Performance**
- ✅ Use appropriate `maxTokens` for your use case
- ✅ Tune `temperature` and `topk` for desired output quality
- ✅ Consider using sessions for multiple related queries

### **4. Error Handling**
- ✅ Always wrap calls in try-catch blocks
- ✅ Provide fallback responses for production apps
- ✅ Monitor metrics for performance issues

## 🔗 **Integration with DriveSense**

The current implementation in `GemmaService.swift` uses:
- ✅ **Stateless inference** for risk assessment
- ✅ **Dynamic prompts** based on available health data
- ✅ **Fallback system** when model isn't available
- ✅ **Async/await** for modern Swift concurrency

This reference provides all the tools needed to enhance the current implementation with advanced features like sessions, streaming, and custom configurations. 