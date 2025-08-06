# Uncomment the next line to define a global platform for your project
platform :ios, '15.0'

target 'DriveSense' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # MediaPipe LLM Inference for Gemma model
  pod 'MediaPipeTasksGenAI'
  pod 'MediaPipeTasksGenAIC'

  target 'DriveSenseTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'DriveSenseUITests' do
    # Pods for testing
  end

end

# Note: Watch app is excluded from CocoaPods since it doesn't need MediaPipe
# The Watch app will use the fallback analysis system 