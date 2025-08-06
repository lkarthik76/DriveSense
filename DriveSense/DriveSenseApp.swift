//
//  DriveSenseApp.swift
//  DriveSense
//
//  Created by Karthikeyan Lakshminarayanan on 01/08/25.
//

import SwiftUI
import SwiftData
import WatchConnectivity

@main
struct DriveSenseApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Conversation.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

                var body: some Scene {
                WindowGroup {
                    DashboardView()
                        .onAppear {
                            print("📱 [iPhoneApp] App appeared, activating WCSession...")
                            if WCSession.isSupported() {
                                let session = WCSession.default
                                session.delegate = WatchDataReceiver.shared
                                session.activate()
                                print("✅ [iPhoneApp] WCSession activation requested")
                            } else {
                                print("❌ [iPhoneApp] WCSession not supported")
                            }
                        }
                }
                .modelContainer(sharedModelContainer)
            }
}
