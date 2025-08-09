//
//  TangramCVGameViewModel.swift
//  Bemo
//
//  ViewModel coordinator for TangramCV game
//

// WHAT: Coordinates between Scene, Services, and Game delegate
// ARCHITECTURE: ViewModel in MVVM-S pattern, implements Scene delegate
// USAGE: Observes Scene state, coordinates business logic via services

import Foundation
import Observation

@Observable
class TangramCVGameViewModel {
    
    // MARK: - Game State (Observable for UI)
    
    var currentPhase: GamePhase = .selectingPuzzle
    var selectedPuzzle: GamePuzzleData?
    var progress: Double = 0.0
    var completedPieces: Set<String> = []
    
    // MARK: - Configuration
    
    var isCVMode: Bool = false
    
    // MARK: - TEST PIPELINE PUZZLES (TEMPORARY - REMOVE AFTER VALIDATION)
    // This array holds automated pipeline test puzzles loaded from JSON files
    // These are injected alongside database puzzles for testing CV validation
    // TO REMOVE: Delete this property and the loadAutomatedPuzzles() call
    var pipelineTestPuzzles: [GamePuzzleData] = []
    
    // MARK: - Dependencies
    
    private weak var delegate: GameDelegate?
    private let cvService = TangramCVService()
    private let puzzleLibraryService: PuzzleLibraryService
    private let supabaseService: SupabaseService?
    
    // MARK: - Scene Reference
    
    private weak var scene: TangramThreeZoneScene?
    
    // MARK: - CV Output
    
    var cvOutputStream: [String: Any] = [:]
    private var lastCVEmissionTime: TimeInterval = 0
    
    // MARK: - Initialization
    
    init(delegate: GameDelegate? = nil,
         puzzleLibraryService: PuzzleLibraryService,
         supabaseService: SupabaseService? = nil) {
        self.delegate = delegate
        self.puzzleLibraryService = puzzleLibraryService
        self.supabaseService = supabaseService
        
        Task {
            await loadPuzzles()
            // Also load automated pipeline puzzles for testing
            loadAutomatedPuzzles()
        }
    }
    
    // MARK: - Public Interface
    
    var availablePuzzles: [GamePuzzleData] {
        // TEMPORARY: Combine database puzzles with pipeline test puzzles
        // TO REMOVE: Just return puzzleLibraryService.availablePuzzles after validation
        let combined = puzzleLibraryService.availablePuzzles + pipelineTestPuzzles
        print("📚 Available puzzles: \(combined.count) total (\(puzzleLibraryService.availablePuzzles.count) from DB, \(pipelineTestPuzzles.count) from pipeline)")
        return combined
    }
    
    func setScene(_ scene: TangramThreeZoneScene) {
        self.scene = scene
        self.scene?.gameDelegate = self
        self.scene?.isCVMode = isCVMode
    }
    
    func selectPuzzle(_ puzzle: GamePuzzleData) {
        selectedPuzzle = puzzle
        currentPhase = .playingPuzzle
        progress = 0.0
        completedPieces.removeAll()
        cvOutputStream.removeAll()
        
        // Load puzzle in scene
        scene?.loadPuzzle(puzzle)
        
        print("TangramCV: Selected puzzle '\(puzzle.name)'")
    }
    
    func toggleCVMode() {
        isCVMode.toggle()
        scene?.isCVMode = isCVMode
        print("TangramCV: CV Mode = \(isCVMode)")
    }
    
    func requestQuit() {
        delegate?.gameDidRequestQuit()
    }
    
    func quitToLobby() {
        // Reset state and go back to lobby
        currentPhase = .selectingPuzzle
        selectedPuzzle = nil
        progress = 0.0
        completedPieces.removeAll()
        cvOutputStream.removeAll()
        
        // Request game engine to quit
        delegate?.gameDidRequestQuit()
    }
    
    func selectNextPuzzle() {
        // Find next puzzle in the list
        guard let currentPuzzle = selectedPuzzle else { return }
        
        let puzzles = availablePuzzles
        if let currentIndex = puzzles.firstIndex(where: { $0.id == currentPuzzle.id }) {
            let nextIndex = (currentIndex + 1) % puzzles.count
            selectPuzzle(puzzles[nextIndex])
        } else {
            // Fallback: select first puzzle
            if let firstPuzzle = puzzles.first {
                selectPuzzle(firstPuzzle)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadPuzzles() async {
        // Puzzles are loaded via PuzzleLibraryService
        print("TangramCV: Loaded \(availablePuzzles.count) puzzles")
    }
    
    private func updateProgress() {
        guard let puzzle = selectedPuzzle else { return }
        let totalPieces = puzzle.targetPieces.count
        let completed = completedPieces.count
        progress = Double(completed) / Double(totalPieces)
        
        if progress >= 1.0 {
            handlePuzzleCompletion()
        }
    }
    
    private func handlePuzzleCompletion() {
        currentPhase = .puzzleComplete
        delegate?.gameDidCompleteLevel(xpAwarded: 100)
        print("🎉 TangramCV: Puzzle completed!")
    }
}

// MARK: - TangramCVSceneDelegate

extension TangramCVGameViewModel: TangramCVSceneDelegate {
    
    func sceneDidSelectPiece(_ piece: CVPuzzlePieceNode) {
        // Track piece selection if needed
    }
    
    func sceneDidMovePiece(_ piece: CVPuzzlePieceNode, from: Zone, to: Zone) {
        // Track zone transitions if needed
        if from != to {
            print("Piece \(piece.pieceType?.rawValue ?? "?") moved from \(from) to \(to)")
        }
    }
    
    func sceneDidReleasePiece(_ piece: CVPuzzlePieceNode, in zone: Zone) {
        // Handle piece release
    }
    
    func sceneDidAddPieceToAssembly(_ piece: CVPuzzlePieceNode) {
        print("Added \(piece.pieceType?.rawValue ?? "?") to assembly")
    }
    
    func sceneDidRemovePieceFromAssembly(_ piece: CVPuzzlePieceNode) {
        print("Removed \(piece.pieceType?.rawValue ?? "?") from assembly")
    }
    
    func sceneRequestsAnchorUpdate(currentAnchor: CVPuzzlePieceNode?, assembledPieces: [CVPuzzlePieceNode]) {
        guard let state = scene?.currentState else { return }
        
        if cvService.shouldPromoteAnchor(currentAnchor: currentAnchor, assembledPieces: assembledPieces) {
            let newAnchor = cvService.selectBestAnchor(
                from: assembledPieces,
                stableFrames: state.pieceStabilityFrames,
                isCVMode: isCVMode
            )
            scene?.updateAnchor(newAnchor)
            print("🚩 Anchor updated: \(newAnchor?.pieceType?.rawValue ?? "none")")
        }
    }
    
    func sceneRequestsCVGeneration(state: TangramCVPuzzleState) {
        // Throttle CV generation
        let now = Date().timeIntervalSince1970
        if now - lastCVEmissionTime < (1.0 / TangramCVConstants.cvStreamFrequency) {
            return
        }
        
        cvOutputStream = cvService.generateCVOutput(state: state)
        lastCVEmissionTime = now
        
        print("📸 CV Stream: \(state.assembledPieces.count) pieces, anchor: \(state.anchorPiece?.pieceType?.rawValue ?? "none")")
    }
    
    func sceneRequestsValidation(for piece: CVPuzzlePieceNode, at position: CGPoint) -> Bool {
        return cvService.validatePiecePlacement(piece, at: position, puzzle: selectedPuzzle)
    }
    
    func sceneRequestsCompletionCheck(state: TangramCVPuzzleState) -> Bool {
        guard let puzzle = selectedPuzzle else { return false }
        
        // Check each piece type
        for target in puzzle.targetPieces {
            if let piece = state.assembledPieces.first(where: { $0.pieceType == target.pieceType }) {
                let isValid = cvService.validatePiecePlacement(piece, at: piece.position, puzzle: puzzle)
                
                if isValid && !completedPieces.contains(target.pieceType.rawValue) {
                    completedPieces.insert(target.pieceType.rawValue)
                    print("✅ Piece completed: \(target.pieceType.rawValue)")
                }
            }
        }
        
        updateProgress()
        return cvService.isPuzzleComplete(state: state)
    }
}

// MARK: - Game Phase

extension TangramCVGameViewModel {
    enum GamePhase {
        case selectingPuzzle
        case playingPuzzle
        case puzzleComplete
    }
}