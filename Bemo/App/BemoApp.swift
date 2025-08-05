//
//  BemoApp.swift
//  Bemo
//
//  Main entry point for the Bemo application
//

import SwiftUI

@main
struct BemoApp: App {
    @StateObject private var appCoordinator = AppCoordinator()
    
    var body: some Scene {
        WindowGroup {
            appCoordinator.rootView
                .onAppear {
                    appCoordinator.start()
                }
        }
    }
}