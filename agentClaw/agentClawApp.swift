

//
//  agentClawApp.swift
//  agentClaw
//
//  Created by MAC on 2026/5/16.
//

import SwiftUI

@main
struct agentClawApp: App {
    private let container = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
        }
    }
}
