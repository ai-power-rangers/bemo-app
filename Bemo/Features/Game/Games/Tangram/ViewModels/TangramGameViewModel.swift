//
//  TangramGameViewModel.swift
//  Bemo
//
//  Main view model for Tangram puzzle gameplay
//

// WHAT: Manages game state, puzzle selection, and CV piece tracking for Tangram game
// ARCHITECTURE: ViewModel in MVVM-S pattern, uses @Observable for state management
// USAGE: Created by TangramGame with GameDelegate, manages all game logic

import SwiftUI
import Observation

@Observable
class TangramGameViewModel {
    
    // MARK: - Game State
    
    enum GamePhase {
        case selectingPuzzle
        case playingPuzzle
        case puzzleComplete
    }
    
    var currentPhase: GamePhase = .selectingPuzzle
    var selectedPuzzle: GamePuzzleData?
    var gameState: PuzzleGameState?
    var score: Int = 0
    var progress: Double = 0.0
    var showHints: Bool = false
    var canvasSize: CGSize = CGSize(width: 600, height: 600)
    var showPlacementCelebration: Bool = false
    var useSpriteKit: Bool = true // Toggle for SpriteKit vs SwiftUI canvas
    
    // Timer properties
    var timerStarted: Bool = false
    var elapsedTime: TimeInterval = 0
    private var timerTask: Task<Void, Never>?
    
    // CV Tracking
    var placedPieces: [PlacedPiece] = []
    var anchorPiece: PlacedPiece?
    
    // MARK: - Dependencies
    
    private weak var delegate: GameDelegate?
    private let databaseLoader: TangramDatabaseLoader
    private let puzzleLibraryService: PuzzleLibraryService
    var availablePuzzles: [GamePuzzleData] = []
    
    // MARK: - Initialization
    
    init(delegate: GameDelegate, supabaseService: SupabaseService? = nil) {
        self.delegate = delegate
        self.databaseLoader = TangramDatabaseLoader(supabaseService: supabaseService)
        self.puzzleLibraryService = PuzzleLibraryService(supabaseService: supabaseService)
        
        // Load puzzles from database
        Task { @MainActor in
            do {
                let puzzles = try await self.databaseLoader.loadOfficialPuzzles()
                self.availablePuzzles = puzzles
                print("Loaded \(puzzles.count) puzzles from database")
                for puzzle in puzzles {
                    print("  - \(puzzle.name) (\(puzzle.category))")
                }
            } catch {
                print("Failed to load puzzles: \(error)")
            }
        }
    }
    
    // MARK: - Game Actions
    
    func selectPuzzle(_ puzzleData: Any) {
        // Handle different data formats
        var gamePuzzleData: GamePuzzleData?
        
        if let puzzle = puzzleData as? GamePuzzleData {
            // Already in the right format
            gamePuzzleData = puzzle
        } else if let dictionary = puzzleData as? [String: Any] {
            // Convert from dictionary
            gamePuzzleData = PuzzleDataConverter.convertFromDatabase(dictionary)
        } else if let codableData = puzzleData as? Decodable {
            // Convert from codable
            gamePuzzleData = PuzzleDataConverter.convertFromCodable(codableData)
        }
        
        guard let puzzle = gamePuzzleData else {
            print("Error: Failed to convert puzzle data")
            return
        }
        
        selectedPuzzle = puzzle
        gameState = PuzzleGameState(targetPuzzle: puzzle)
        currentPhase = .playingPuzzle
        progress = 0.0
        showHints = false
        // Reset timer
        timerStarted = false
        elapsedTime = 0
        // Update progress to 0 when starting
        delegate?.gameDidUpdateProgress(Float(0.0))
    }
    
    func exitToSelection() {
        stopTimer()
        currentPhase = .selectingPuzzle
        selectedPuzzle = nil
        gameState = nil
        progress = 0.0
        showHints = false
        timerStarted = false
        elapsedTime = 0
    }
    
    func requestQuit() {
        delegate?.gameDidRequestQuit()
    }
    
    func requestHint() {
        showHints = true
        gameState?.incrementHintCount()
        delegate?.gameDidRequestHint()
    }
    
    func toggleHints() {
        showHints.toggle()
        if showHints {
            gameState?.incrementHintCount()
        }
    }
    
    func loadNextPuzzle() {
        // Stop timer when loading next puzzle
        stopTimer()
        
        // Get next puzzle from available puzzles
        let currentIndex = availablePuzzles.firstIndex { $0.id == selectedPuzzle?.id } ?? 0
        let nextIndex = (currentIndex + 1) % availablePuzzles.count
        
        if nextIndex < availablePuzzles.count {
            let nextPuzzle = availablePuzzles[nextIndex]
            selectPuzzle(nextPuzzle)
        } else {
            // No more puzzles, go back to selection
            exitToSelection()
        }
    }
    
    // MARK: - Timer Management
    
    func startTimer() {
        guard !timerStarted else { return }
        
        timerStarted = true
        elapsedTime = 0
        
        // Start timer task
        timerTask = Task { @MainActor in
            while !Task.isCancelled && timerStarted {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                if timerStarted {
                    elapsedTime += 0.1
                }
            }
        }
    }
    
    func stopTimer() {
        timerStarted = false
        timerTask?.cancel()
        timerTask = nil
    }
    
    var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Touch-based Testing
    
    func handlePieceTouch(pieceType: String) {
        guard let puzzle = selectedPuzzle else { return }
        
        // Find the target piece in the puzzle
        guard let targetPiece = puzzle.targetPieces.first(where: { $0.pieceType.rawValue == pieceType }) else {
            return
        }
        
        // Check if piece is already placed - convert String to TangramPieceType
        guard let tangramPieceType = TangramPieceType(rawValue: pieceType) else { return }
        let alreadyPlaced = placedPieces.contains { $0.pieceType == tangramPieceType }
        
        if alreadyPlaced {
            // Remove the piece
            placedPieces.removeAll { $0.pieceType == tangramPieceType }
        } else {
            // Create a perfectly placed piece
            // Extract position from transform (tx, ty) and rotation from transform matrix
            let position = CGPoint(x: targetPiece.transform.tx, y: targetPiece.transform.ty)
            let rotation = atan2(targetPiece.transform.b, targetPiece.transform.a) * 180.0 / .pi
            
            let mockPiece = RecognizedPiece(
                id: "touch_\(pieceType)_\(UUID().uuidString.prefix(8))",
                pieceTypeId: pieceType,
                position: position,
                rotation: rotation,
                velocity: CGVector(dx: 0, dy: 0),
                isMoving: false,
                confidence: 1.0,
                timestamp: Date(),
                frameNumber: 0
            )
            
            var placed = PlacedPiece(from: mockPiece)
            placed.validationState = PlacedPiece.ValidationState.correct
            
            // Add to placed pieces
            placedPieces.append(placed)
            
            // Show brief celebration for correct placement
            showPlacementFeedback()
        }
        
        // Update progress
        let correctCount = placedPieces.filter { $0.validationState == .correct }.count
        let newProgress = Double(correctCount) / Double(puzzle.targetPieces.count)
        updateProgress(newProgress)
    }
    
    private func showPlacementFeedback() {
        // Show visual feedback
        showPlacementCelebration = true
        
        // Hide after a short delay
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            await MainActor.run {
                showPlacementCelebration = false
            }
        }
    }
    
    // MARK: - SpriteKit Handlers
    
    func handlePieceCompletion(pieceType: String) {
        // Create a correctly placed piece
        let mockPiece = RecognizedPiece(
            id: "sprite_\(pieceType)_\(UUID().uuidString.prefix(8))",
            pieceTypeId: pieceType,
            position: CGPoint(x: 0, y: 0), // Position managed by SpriteKit
            rotation: 0,
            velocity: CGVector(dx: 0, dy: 0),
            isMoving: false,
            confidence: 1.0,
            timestamp: Date(),
            frameNumber: 0
        )
        
        var placed = PlacedPiece(from: mockPiece)
        placed.validationState = .correct
        
        // Update placed pieces - convert String to TangramPieceType
        if let tangramPieceType = TangramPieceType(rawValue: pieceType) {
            placedPieces.removeAll { $0.pieceType == tangramPieceType }
        }
        placedPieces.append(placed)
        
        // Update progress
        let correctCount = placedPieces.filter { $0.validationState == .correct }.count
        let newProgress = Double(correctCount) / 7.0
        updateProgress(newProgress)
        
        // Show feedback
        showPlacementFeedback()
    }
    
    func handlePuzzleCompletion() {
        // Puzzle completed via SpriteKit
        stopTimer()
        currentPhase = .puzzleComplete
        let xpAwarded = calculateXP()
        delegate?.gameDidCompleteLevel(xpAwarded: xpAwarded)
    }
    
    // MARK: - CV Processing
    
    func processMockCVInput(_ recognizedPieces: [RecognizedPiece]) -> PlayerActionOutcome {
        // Convert to placed pieces and process
        let placedPieces = recognizedPieces.map { PlacedPiece(from: $0) }
        processCVInput(placedPieces)
        
        // Return appropriate outcome
        if placedPieces.isEmpty {
            return .noAction
        }
        
        let correctCount = placedPieces.filter { $0.validationState == .correct }.count
        if correctCount > 0 {
            return .correctPlacement(points: correctCount * 10)
        }
        
        return .stateUpdated
    }
    
    func processCVInput(_ pieces: [PlacedPiece]) {
        guard currentPhase == .playingPuzzle else { return }
        
        // Update placed pieces
        placedPieces = pieces
        
        // Select or update anchor piece
        updateAnchorPiece()
        
        // Calculate relative positions for all pieces
        if let anchor = anchorPiece {
            placedPieces = placedPieces.map { piece in
                if piece.id == anchor.id {
                    return piece
                } else {
                    return piece.updateRelativeToAnchor(anchor)
                }
            }
        }
        
        // Validate piece placements
        validatePieces()
        
        // Update game state
        gameState?.updatePlacedPieces(placedPieces)
        
        // Calculate progress based on correct pieces
        let correctCount = placedPieces.filter { $0.validationState == .correct }.count
        let newProgress = Double(correctCount) / 7.0
        updateProgress(newProgress)
    }
    
    private func updateAnchorPiece() {
        // If no anchor or anchor is not in current pieces, select new one
        if anchorPiece == nil || !placedPieces.contains(where: { $0.id == anchorPiece?.id }) {
            selectNewAnchor()
        }
    }
    
    private func selectNewAnchor() {
        // Priority: largest piece > most central > first placed
        anchorPiece = placedPieces
            .sorted { p1, p2 in
                // First sort by area (larger pieces first)
                if p1.area != p2.area {
                    return p1.area > p2.area
                }
                // Then by distance from center (closer to center first)
                return p1.distanceFromCenter < p2.distanceFromCenter
            }
            .first
    }
    
    // MARK: - Validation
    
    private func validatePieces() {
        guard let puzzle = selectedPuzzle else { return }
        
        // For each placed piece, check if it matches any target
        for i in 0..<placedPieces.count {
            var piece = placedPieces[i]
            
            // Only validate stationary pieces
            guard piece.isPlacedLongEnough() else {
                piece.validationState = PlacedPiece.ValidationState.pending
                placedPieces[i] = piece
                continue
            }
            
            // Check if this piece matches any target position
            let isCorrect = puzzle.targetPieces.contains { target in
                // For now, simple matching - will need proper position extraction
                target.pieceType == piece.pieceType
            }
            
            piece.validationState = isCorrect ? PlacedPiece.ValidationState.correct : PlacedPiece.ValidationState.incorrect
            placedPieces[i] = piece
        }
    }
    
    // MARK: - Progress Management (Phase 3)
    
    func updateProgress(_ newProgress: Double) {
        progress = newProgress
        delegate?.gameDidUpdateProgress(Float(progress))
        
        if progress >= 1.0 {
            completePuzzle()
        }
    }
    
    private func completePuzzle() {
        currentPhase = .puzzleComplete
        let xpAwarded = calculateXP()
        delegate?.gameDidCompleteLevel(xpAwarded: xpAwarded)
    }
    
    private func calculateXP() -> Int {
        // Base XP with modifiers for hints, time, etc.
        return 100
    }
    
    // MARK: - Game State Management
    
    func resetGame() {
        currentPhase = .selectingPuzzle
        selectedPuzzle = nil
        gameState = nil
        placedPieces = []
        anchorPiece = nil
        score = 0
        progress = 0.0
        showHints = false
    }
    
    func restoreGameState(_ state: PuzzleGameState) {
        gameState = state
        selectedPuzzle = state.targetPuzzle
        currentPhase = .playingPuzzle
        // Restore placed pieces (not optional - array is always present)
        placedPieces = state.placedPieces
        updateAnchorPiece()
    }
}