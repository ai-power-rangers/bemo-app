//
//  AnimationLabTool.swift
//  Bemo
//
//  DevTool entry point for experimenting with SpriteKit tangram animations
//

// WHAT: Implements a standalone DevTool that hosts an SKScene for testing transition and character animations
// ARCHITECTURE: DevTool in MVVM-S. SwiftUI view embeds a SpriteKit scene and a SwiftUI control panel overlay
// USAGE: AppCoordinator can launch this DevTool in isolation; does not affect Tangram game code

import SwiftUI
import SpriteKit

// Legacy AnimationLabView removed - replaced by AnimationLabContainerView

class AnimationLabTool: DevTool {
    let id = "animation_lab"
    let title = "Animation Lab"
    let description = "Experiment with SpriteKit animations for tangram puzzles"
    let recommendedAge: ClosedRange<Int> = 18...120
    let thumbnailImageName = "tangram_thumb"
    
    // Custom UI config - no overlay buttons since we use native navigation
    var devToolUIConfig: DevToolUIConfig {
        return DevToolUIConfig(
            respectsSafeAreas: true,
            showQuitButton: false,  // Using native nav bar instead
            showProgressBar: false,
            showSaveButton: false   // No save functionality needed
        )
    }

    func makeDevToolView(delegate: DevToolDelegate) -> AnyView {
        // Use DI-provided services via the dev tool host context
        if let host = delegate as? DevToolHostViewModel {
            let pms = PuzzleManagementService(supabaseService: host.supabaseService, errorTracking: host.errorTrackingService)
            let vm = AnimationLabViewModel(puzzleService: pms, delegate: delegate)
            return AnyView(AnimationLabContainerView(viewModel: vm))
        }
        // Safe fallback: still avoid creating auth-bound supabase; use service-role minimal
        let supabase = SupabaseService(useServiceRole: true)
        let pms = PuzzleManagementService(supabaseService: supabase, errorTracking: nil)
        let vm = AnimationLabViewModel(puzzleService: pms, delegate: delegate)
        return AnyView(AnimationLabContainerView(viewModel: vm))
    }

    func reset() { }
    func saveState() -> Data? { nil }
    func loadState(from data: Data) { }
}


