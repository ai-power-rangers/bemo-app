//
//  TangramProgressServiceTool.swift  
//  Bemo
//
//  DevTool for testing TangramProgressService functionality
//

// WHAT: DevTool for testing and demonstrating TangramProgressService functionality
// ARCHITECTURE: DevTool in MVVM-S pattern
// USAGE: Provides UI to test service-level progress tracking, persistence, and multiple children

import SwiftUI
import Foundation

class TangramProgressServiceTool: DevTool {
    let id = "tangram_progress_service"
    let title = "Tangram Progress Service"
    let description = "Test progress service with persistence and multiple children"
    let recommendedAge: ClosedRange<Int> = 18...120
    let thumbnailImageName = "tangram_thumb"
    
    var devToolUIConfig: DevToolUIConfig {
        return DevToolUIConfig(
            respectsSafeAreas: true,
            showQuitButton: true,
            showProgressBar: false,
            showSaveButton: false
        )
    }
    
    func makeDevToolView(delegate: DevToolDelegate) -> AnyView {
        return AnyView(TangramProgressServiceDebugView())
    }
    
    func reset() { }
    func saveState() -> Data? { nil }
    func loadState(from data: Data) { }
}
