//
//  AnimationLabViewModel.swift
//  Bemo
//
//  ViewModel for the Animation Lab dev tool
//

// WHAT: Manages animations list, puzzle list from DB, and selection state
// ARCHITECTURE: @Observable ViewModel using PuzzleManagementService to fetch puzzles
// USAGE: Inject into AnimationLabView; scene consumes selected puzzle to render

import Foundation
import Observation

@Observable
class AnimationLabViewModel {
    enum AnimationGroup: String, CaseIterable { case transitional, character }
    enum AnimationCategory: String, CaseIterable { 
        case generic, celebration, entrance, exit 
    }
    enum AnimationType: String, CaseIterable {
        // Generic
        case squareTakeover, squareWave, squareSpiral
        // Transitional
        case assemble, explosion, fadeIn, scatter, disassemble
        // Character
        case breathing, pulse, wobble, happyJump, shimmer
        // Combined
        case celebration
    }
    
    struct AnimationItem: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let group: AnimationGroup
        let category: AnimationCategory
        let type: AnimationType
        let requiresPuzzle: Bool
    }
    
    // Inputs
    private let puzzleService: PuzzleManagementService?
    weak var delegate: DevToolDelegate?
    
    // State
    var animations: [AnimationItem] = []
    var selectedAnimation: AnimationItem? = nil
    
    var puzzles: [GamePuzzleData] = []
    var isLoadingPuzzles = false
    var selectedPuzzle: GamePuzzleData? = nil
    var errorMessage: String? = nil
    
    init(puzzleService: PuzzleManagementService?, delegate: DevToolDelegate? = nil) {
        self.puzzleService = puzzleService
        self.delegate = delegate
        setupAnimations()
        Task { await loadPuzzles() }
    }
    
    private func setupAnimations() {
        // Generic animations (not puzzle-specific)
        let genericAnims = [
            AnimationItem(name: "Row Slide", group: .transitional, category: .generic, type: .squareTakeover, requiresPuzzle: false),
            AnimationItem(name: "Column Slide", group: .transitional, category: .generic, type: .squareWave, requiresPuzzle: false)
        ]
        
        // Celebration animations - for puzzle completion
        let celebrationAnims = [
            AnimationItem(name: "Full Celebration", group: .transitional, category: .celebration, type: .celebration, requiresPuzzle: true)
        ]
        
        // Entrance animations - for puzzle start
        let entranceAnims = [
            AnimationItem(name: "Assemble", group: .transitional, category: .entrance, type: .assemble, requiresPuzzle: true)
        ]
        
        // Exit animations - for puzzle transitions
        let exitAnims = [
            AnimationItem(name: "Explosion", group: .transitional, category: .exit, type: .explosion, requiresPuzzle: true),
            AnimationItem(name: "Disassemble", group: .transitional, category: .exit, type: .disassemble, requiresPuzzle: true)
        ]
        
        animations = genericAnims + celebrationAnims + entranceAnims + exitAnims
    }
    
    func loadPuzzles() async {
        guard !isLoadingPuzzles else { return }
        await MainActor.run { isLoadingPuzzles = true; errorMessage = nil }
        do {
            let list = await puzzleService?.getTangramPuzzles() ?? []
            await MainActor.run {
                self.puzzles = list
                self.isLoadingPuzzles = false
                // Don't auto-select a puzzle - let user choose
                // if self.selectedPuzzle == nil { self.selectedPuzzle = list.first }
            }
        }
    }
    
    func requestQuit() {
        delegate?.devToolDidRequestQuit()
    }
}


