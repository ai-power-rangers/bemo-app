//
//  TangramCVGameViewModel.swift
//  Bemo
//
//  View model for CV-ready Tangram game with three-zone layout
//

// WHAT: Manages CV-ready game state, anchor tracking, and relative validation
// ARCHITECTURE: ViewModel in MVVM-S, uses @Observable for state management
// USAGE: Created by TangramCVGame, manages three-zone gameplay and CV streaming

import SwiftUI
import Observation

@Observable
class TangramCVGameViewModel {
    
    // MARK: - Game State
    
    enum GamePhase {
        case selectingPuzzle
        case playingPuzzle
        case puzzleComplete
    }
    
    var currentPhase: GamePhase = .selectingPuzzle
    var selectedPuzzle: GamePuzzleData?
    var score: Int = 0
    var progress: Double = 0.0
    
    // MARK: - CV and Anchor Tracking
    
    var anchorPiece: CVPuzzlePieceNode?
    var assembledPieces: [CVPuzzlePieceNode] = []
    var cvOutputStream: [String: Any] = [:]
    var lastCVEmissionTime: TimeInterval = 0
    var isCVMode: Bool = false // Toggle between touch and CV mode
    
    // Track piece stability for anchor promotion (CV mode)
    private var pieceStabilityFrames: [String: Int] = [:]
    
    // MARK: - Zone Management
    
    var referenceZoneHeight: CGFloat = 0
    var assemblyZoneHeight: CGFloat = 0
    var storageZoneHeight: CGFloat = 0
    
    // MARK: - Validation
    
    var validationResults: [TangramPieceType: Bool] = [:]
    var completedPieces: Set<String> = []
    
    // MARK: - Dependencies
    
    private weak var delegate: GameDelegate?
    private let puzzleLibraryService: PuzzleLibraryService
    private let supabaseService: SupabaseService?
    var availablePuzzles: [GamePuzzleData] {
        puzzleLibraryService.availablePuzzles
    }
    
    // CV Services (to be implemented)
    // private let cvOutputBridge = CVOutputBridge()
    // private let relativeValidator = TangramRelativeValidator()
    
    // MARK: - Initialization
    
    init(delegate: GameDelegate, supabaseService: SupabaseService? = nil, puzzleManagementService: PuzzleManagementService? = nil) {
        self.delegate = delegate
        self.supabaseService = supabaseService
        self.puzzleLibraryService = PuzzleLibraryService(
            puzzleManagementService: puzzleManagementService,
            supabaseService: supabaseService
        )
        // Puzzles will be loaded automatically by PuzzleLibraryService
    }
    
    func selectPuzzle(_ puzzle: GamePuzzleData) {
        selectedPuzzle = puzzle
        currentPhase = .playingPuzzle
        progress = 0.0
        completedPieces.removeAll()
        validationResults.removeAll()
        anchorPiece = nil
        assembledPieces.removeAll()
        
        print("TangramCV: Selected puzzle '\(puzzle.name)'")
    }
    
    // MARK: - Anchor Management
    
    func setAnchorPiece(_ piece: CVPuzzlePieceNode) {
        // Clear previous anchor
        anchorPiece?.isAnchor = false
        
        // Set new anchor
        anchorPiece = piece
        piece.isAnchor = true
        
        print("TangramCV: Anchor set to \(piece.pieceType?.rawValue ?? "unknown")")
        
        // Generate CV output with new anchor
        generateCVOutputStream()
    }
    
    func promoteNewAnchor() {
        guard !assembledPieces.isEmpty else {
            anchorPiece = nil
            return
        }
        
        let newAnchor: CVPuzzlePieceNode?
        
        if isCVMode {
            // CV mode: Find largest stable piece
            newAnchor = assembledPieces
                .filter { isStableForFrames($0, frames: 5) }
                .max { p1, p2 in
                    getPieceArea(p1.pieceType) < getPieceArea(p2.pieceType)
                }
        } else {
            // Touch mode: Use first (oldest) piece
            newAnchor = assembledPieces.first
        }
        
        if let anchor = newAnchor {
            setAnchorPiece(anchor)
        }
    }
    
    private func isStableForFrames(_ piece: CVPuzzlePieceNode, frames: Int) -> Bool {
        guard let id = piece.id else { return false }
        return (pieceStabilityFrames[id] ?? 0) >= frames
    }
    
    private func getPieceArea(_ type: TangramPieceType?) -> Double {
        guard let type = type else { return 0 }
        
        switch type {
        case .largeTriangle1, .largeTriangle2:
            return 2.0
        case .mediumTriangle, .square, .parallelogram:
            return 1.0
        case .smallTriangle1, .smallTriangle2:
            return 0.5
        }
    }
    
    // MARK: - CV Stream Generation
    
    func generateCVOutputStream() {
        // Throttle to 20Hz (50ms between emissions)
        let now = CACurrentMediaTime()
        guard now - lastCVEmissionTime >= 0.05 else { return }
        lastCVEmissionTime = now
        
        // Generate CV format output
        // This will be implemented with CVOutputBridge
        let cvData: [String: Any] = [
            "schema_version": 1,
            "timestamp": Date().timeIntervalSince1970,
            "anchor_id": anchorPiece?.id ?? "none",
            "objects": assembledPieces.map { piece in
                [
                    "id": piece.id ?? UUID().uuidString,
                    "type": piece.pieceType?.rawValue ?? "unknown",
                    "is_anchor": piece.isAnchor
                ]
            }
        ]
        
        cvOutputStream = cvData
        
        #if DEBUG
        print("📸 CV Stream: \(assembledPieces.count) pieces, anchor: \(anchorPiece?.pieceType?.rawValue ?? "none")")
        #endif
    }
    
    // MARK: - Piece Placement
    
    func handlePiecePlacement(_ piece: CVPuzzlePieceNode, inAssemblyZone: Bool) {
        if inAssemblyZone {
            // Add to assembled pieces if not already there
            if !assembledPieces.contains(where: { $0.id == piece.id }) {
                assembledPieces.append(piece)
                
                // First piece becomes anchor
                if anchorPiece == nil {
                    setAnchorPiece(piece)
                }
            }
        } else {
            // Remove from assembled pieces
            assembledPieces.removeAll { $0.id == piece.id }
            
            // If this was the anchor, promote a new one
            if piece == anchorPiece {
                anchorPiece = nil
                piece.isAnchor = false
                promoteNewAnchor()
            }
        }
        
        generateCVOutputStream()
    }
    
    // MARK: - Validation (Placeholder)
    
    func validateAssembly() {
        // This will use TangramRelativeValidator when implemented
        // For now, just track progress
        let placedCount = assembledPieces.count
        progress = Double(placedCount) / 7.0
        
        if placedCount == 7 {
            // Check if puzzle is complete
            checkPuzzleCompletion()
        }
    }
    
    private func checkPuzzleCompletion() {
        // Placeholder - will implement with relative validation
        currentPhase = .puzzleComplete
        delegate?.gameDidCompleteLevel(xpAwarded: 100)
        
        print("TangramCV: Puzzle completed!")
    }
    
    // MARK: - Navigation
    
    func quitToLobby() {
        delegate?.gameDidRequestQuit()
    }
    
    func selectNextPuzzle() {
        if let currentIndex = availablePuzzles.firstIndex(where: { $0.id == selectedPuzzle?.id }),
           currentIndex < availablePuzzles.count - 1 {
            selectPuzzle(availablePuzzles[currentIndex + 1])
        }
    }
}