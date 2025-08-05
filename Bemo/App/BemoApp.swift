//
//  BemoApp.swift
//  Bemo
//
//  Main entry point for the Bemo application
//

// WHAT: This is the app's entry point marked with @main. It creates and holds the AppCoordinator instance.
// ARCHITECTURE: Entry point of MVVM-S architecture. Creates AppCoordinator which manages all navigation and dependency injection.
// USAGE: This file is automatically executed by iOS. No manual instantiation needed - just ensure AppCoordinator is properly configured.

import SwiftUI

@main
struct BemoApp: App {
    private var appCoordinator = AppCoordinator()
    
    var body: some Scene {
        WindowGroup {
            appCoordinator.rootView
                .onAppear {
                    appCoordinator.start()
                }
        }
    }
}