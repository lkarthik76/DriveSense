//
//  DriveSenseWatchApp.swift
//  DriveSenseWatch Watch App
//
//  Created by Karthikeyan Lakshminarayanan on 01/08/25.
//

import SwiftUI
import WatchKit
import WatchConnectivity

@main
struct DriveSenseWatch_Watch_AppApp: App {
    @StateObject private var backgroundTaskManager = BackgroundTaskManager.shared
    
    var body: some Scene {
        WindowGroup {
            DrivingRiskView()
                .onReceive(NotificationCenter.default.publisher(for: WKExtension.applicationWillResignActiveNotification)) { _ in
                    backgroundTaskManager.handleAppWillResignActive()
                }
                .onReceive(NotificationCenter.default.publisher(for: WKExtension.applicationDidBecomeActiveNotification)) { _ in
                    backgroundTaskManager.handleAppDidBecomeActive()
                }
                .onAppear {
                    print("📱 [WatchApp] App appeared, activating WCSession...")
                    if WCSession.isSupported() {
                        let session = WCSession.default
                        session.delegate = WatchSessionDelegate.shared
                        session.activate()
                        print("✅ [WatchApp] WCSession activation requested")
                    } else {
                        print("❌ [WatchApp] WCSession not supported")
                    }
                }
        }
    }
}

// MARK: - Watch Session Delegate
class WatchSessionDelegate: NSObject, WCSessionDelegate {
    static let shared = WatchSessionDelegate()
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ [WatchSessionDelegate] WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("✅ [WatchSessionDelegate] WCSession activated successfully")
            print("📱 [WatchSessionDelegate] Activation state: \(activationState.rawValue)")
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("📱 [WatchSessionDelegate] WCSession reachability changed: \(session.isReachable)")
    }
}
