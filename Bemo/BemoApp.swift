//
//  BemoApp.swift
//  Bemo
//
//  Created by Roosh on 8/4/25.
//

import SwiftUI

@main
struct BemoApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
