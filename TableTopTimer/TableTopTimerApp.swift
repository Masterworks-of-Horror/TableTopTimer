//
//  TableTopTimerApp.swift
//  TableTopTimer
//
//  Created by Yuhao Chen on 6/20/25.
//

import SwiftUI
import SwiftData

@main
struct TableTopTimerApp: App {
    @State private var timerManager = TimerManager()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TimerItem.self,
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
            ContentView()
                .environment(timerManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
