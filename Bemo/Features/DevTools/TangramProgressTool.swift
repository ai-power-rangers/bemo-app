//
//  TangramProgressTool.swift  
//  Bemo
//
//  DevTool for testing TangramProgress model functionality
//

// WHAT: DevTool for testing and demonstrating TangramProgress functionality
// ARCHITECTURE: DevTool in MVVM-S pattern
// USAGE: Provides UI to test progress tracking, difficulty switching, and unlock logic

import SwiftUI
import Foundation

class TangramProgressTool: DevTool {
    let id = "tangram_progress"
    let title = "Tangram Progress Test"
    let description = "Test difficulty selection and progress tracking"
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
        return AnyView(TangramProgressDebugView())
    }
    
    func reset() { }
    func saveState() -> Data? { nil }
    func loadState(from data: Data) { }
}
