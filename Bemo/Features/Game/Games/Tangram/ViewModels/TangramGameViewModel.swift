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
    private var cvGroupId: UUID = UUID()
    
    // Hint System
    var currentHint: TangramHintEngine.HintData?
    var hintHistory: [TangramHintEngine.HintData] = []
    var lastMovedPiece: TangramPieceType?
    var lastProgressTime = Date()
    var isShowingHintAnimation: Bool = false
    private var hintDismissTask: Task<Void, Never>?
    // MARK: - Validated targets tracking for hints
    private func validatedTargetIds() -> Set<String> {
        // Build from placedPieces with .correct state where we know assigned target
        var ids: Set<String> = []
        for p in placedPieces where p.validationState == .correct {
            if let assigned = p.assignedTargetId { ids.insert(assigned) }
        }
        return ids
    }

    // Sync from SpriteKit scene validated targets → update placedPieces and internal state
    func syncValidatedTargetIds(_ ids: Set<String>) {
        // Ensure placedPieces entries exist for each validated target id and assign them
        guard let puzzle = selectedPuzzle else { return }
        for tid in ids {
            if let target = puzzle.targetPieces.first(where: { $0.id == tid }) {
                // Ensure a placed piece entry exists (create a lightweight entry if missing)
                if let idx = placedPieces.firstIndex(where: { $0.pieceType == target.pieceType }) {
                    placedPieces[idx].assignedTargetId = tid
                    placedPieces[idx].validationState = PlacedPiece.ValidationState.correct
                } else {
                    // Create a minimal PlacedPiece so hints can treat it as validated
                    var p = PlacedPiece(pieceType: target.pieceType, position: CGPoint(x: 0, y: 0), rotation: 0, isFlipped: false)
                    p.assignedTargetId = tid
                    p.validationState = PlacedPiece.ValidationState.correct
                    placedPieces.append(p)
                }
            }
        }
    }

    // Persist instance-binding (pieceId -> assignedTargetId) across frames for CV path
    private var pieceAssignments: [String: String] = [:]
    var mappingService: TangramRelativeMappingService { container.mappingService }
    
    // MARK: - Dependencies
    
    private weak var delegate: GameDelegate?
    private let container: TangramDependencyContainer
    private let supabaseService: SupabaseService?
    var availablePuzzles: [GamePuzzleData] = []

    // MARK: - Difficulty
    private(set) var effectiveDifficulty: UserPreferences.DifficultySetting = .normal
    func setEffectiveDifficulty(_ difficulty: UserPreferences.DifficultySetting) {
        effectiveDifficulty = difficulty
    }
    
    
    // MARK: - Metrics Tracking
    
    private var gameProgress: GameProgress?
    private var currentSessionId: String?
    private var currentChildProfileId: String?
    
    // MARK: - Initialization
    
    init(delegate: GameDelegate, container: TangramDependencyContainer) {
        self.delegate = delegate
        self.container = container
        self.supabaseService = container.supabaseService
        
        // Load puzzles using container's services
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if let managementService = container.puzzleManagementService {
                // Use cached puzzles for instant loading!
                let puzzles = await managementService.getTangramPuzzles()
                self.availablePuzzles = puzzles
            } else {
                // Fallback to direct database loading
                do {
                    let puzzles = try await self.container.databaseLoader.loadOfficialPuzzles()
                    self.availablePuzzles = puzzles
                } catch {
                    // Handle error silently
                }
            }
        }
    }

    // MARK: - Difficulty Override API (from View)
    func applyDifficultyOverride(_ difficulty: UserPreferences.DifficultySetting?) {
        if let d = difficulty {
            setEffectiveDifficulty(d)
        } else {
            // Ask delegate for child default
            let base = delegate?.getChildDifficultySetting() ?? .normal
            setEffectiveDifficulty(base)
        }
        // Notify scene if already running
        // The scene is created in TangramSpriteView; we propagate via a lightweight notification in placedPieces change
        // Actual consumption occurs in TangramPuzzleScene by reading viewModel when binding or via per-call parameters
    }
    
    // Alternative init for backward compatibility
    convenience init(delegate: GameDelegate, supabaseService: SupabaseService? = nil, puzzleManagementService: PuzzleManagementService? = nil) {
        let container = TangramDependencyContainer(
            supabaseService: supabaseService,
            puzzleManagementService: puzzleManagementService
        )
        self.init(delegate: delegate, container: container)
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
            switch container.dataConverter.convertFromDatabase(dictionary) {
            case .success(let puzzle):
                gamePuzzleData = puzzle
            case .failure:
                gamePuzzleData = nil
            }
        } else if let codableData = puzzleData as? Decodable {
            // Convert from codable
            gamePuzzleData = container.dataConverter.convertFromCodable(codableData)
        }
        
        guard let puzzle = gamePuzzleData else {
            return
        }
        
        selectedPuzzle = puzzle
        gameState = PuzzleGameState(targetPuzzle: puzzle)
        currentPhase = .playingPuzzle
        progress = 0.0
        showHints = false
        
        // Initialize GameProgress for automatic time tracking
        gameProgress = GameProgress(
            puzzleId: puzzle.id,
            correctPieces: Set(),
            totalPieces: puzzle.targetPieces.count,
            hintsUsed: 0,
            startTime: Date(),
            lastProgressTime: Date()
        )
        
        // Auto-start timer when puzzle is selected
        startTimer()
        
        // Start game session if we have supabase service
        startGameSession(puzzleId: puzzle.id, puzzleName: puzzle.name, difficulty: puzzle.difficulty)
        
        // Update progress to 0 when starting
        delegate?.gameDidUpdateProgress(Float(0.0))
    }
    
    func exitToSelection() {
        stopTimer()
        
        // Clear any active hints
        clearHint()
        
        // End game session if active
        endGameSession(completed: false)
        
        currentPhase = .selectingPuzzle
        selectedPuzzle = nil
        gameState = nil
        gameProgress = nil
        progress = 0.0
        showHints = false
        timerStarted = false
        elapsedTime = 0
    }
    
    func requestQuit() {
        delegate?.gameDidRequestQuit()
    }
    
    func requestHint() {
        requestStructuredHint()
    }
    
    func toggleHints() {
        // Only request a hint if one isn't already showing
        // This prevents the toggle behavior from rapid clicking
        if currentHint == nil {
            requestStructuredHint()
        }
        // If a hint is already showing, do nothing (let it complete its duration)
    }
    
    func requestStructuredHint() {
        guard let puzzle = selectedPuzzle else { 
            return 
        }
        
        let timeSinceProgress = Date().timeIntervalSince(lastProgressTime)
        
        // Get intelligent hint
        let hint = container.hintEngine.determineNextHint(
            puzzle: puzzle,
            placedPieces: placedPieces,
            lastMovedPiece: lastMovedPiece,
            timeSinceLastProgress: timeSinceProgress,
            previousHints: hintHistory,
            validatedTargetIds: validatedTargetIds(),
            difficultySetting: effectiveDifficulty
        )
        
        if let hint = hint {
            // Set the hint directly - no need for nil pattern
            currentHint = hint
            
            // Track hint
            hintHistory.append(hint)
            gameState?.incrementHintCount()
            
            // Update game progress
            gameProgress?.hintsUsed += 1
            
            // Track hint event to database
            trackHintUsage(hint: hint)
            
            // Show animation
            isShowingHintAnimation = true
            showHints = true
            
            // Cancel any existing dismiss task
            hintDismissTask?.cancel()
            
            // Auto-dismiss hint after 4 seconds
            hintDismissTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 4_000_000_000) // 4 seconds
                guard !Task.isCancelled else { return }
                self?.clearHint()
            }
            
            // Notify delegate
            delegate?.gameDidRequestHint()
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
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self = self, self.timerStarted else { break }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                if self.timerStarted {
                    self.elapsedTime += 0.1
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
        
        // Notify that this piece is being interacted with
        onPieceMoved(tangramPieceType)
        
        let alreadyPlaced = placedPieces.contains { $0.pieceType == tangramPieceType }
        
        if alreadyPlaced {
            // Remove the piece
            placedPieces.removeAll { $0.pieceType == tangramPieceType }
        } else {
            // Create a perfectly placed piece
            // Extract position from transform (tx, ty) and rotation from transform matrix
            let position = CGPoint(x: targetPiece.transform.tx, y: targetPiece.transform.ty)
            // Use sceneRotation for consistency with rendering
            let rotation = TangramGeometryUtilities.sceneRotation(from: targetPiece.transform) * 180.0 / .pi
            
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
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            await MainActor.run {
                self?.showPlacementCelebration = false
            }
        }
    }
    
    // MARK: - SpriteKit Handlers
    
    func handlePieceCompletion(pieceType: String, isFlipped: Bool = false) {
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
        placed.isFlipped = isFlipped  // Track flip state from SpriteKit
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
        
        // Track completion metrics before showing modal
        trackPuzzleCompletion()
        
        let xpAwarded = calculateXP()
        delegate?.gameDidCompleteLevel(xpAwarded: xpAwarded)
        
        // Delay showing the completion modal to allow celebration animation
        Task { @MainActor [weak self] in
            // Wait for celebration animation (3 seconds)
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self?.currentPhase = .puzzleComplete
        }
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
        
        // Check if any hinted piece is being moved
        if let hint = currentHint {
            // Check if the hinted piece is now moving or has changed position
            if let hintedPiece = pieces.first(where: { $0.pieceType == hint.targetPiece }) {
                if hintedPiece.isMoving {
                    // Piece is being moved, clear the hint
                    clearHint()
                } else if let previousPiece = placedPieces.first(where: { $0.pieceType == hint.targetPiece }) {
                    // Check if position changed significantly
                    let positionDiff = hypot(
                        hintedPiece.position.x - previousPiece.position.x,
                        hintedPiece.position.y - previousPiece.position.y
                    )
                    if positionDiff > 5 { // Movement threshold
                        clearHint()
                    }
                }
            }
        }
        
        // Update placed pieces; restore persisted assignments
        placedPieces = pieces.map { piece in
            var updated = piece
            if let assigned = pieceAssignments[piece.id] {
                updated.assignedTargetId = assigned
            }
            return updated
        }
        
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
                return p1.distanceFromCenter(canvasSize: canvasSize) < p2.distanceFromCenter(canvasSize: canvasSize)
            }
            .first
    }
    
    // MARK: - Validation
    
    private func validatePieces() {
        guard let puzzle = selectedPuzzle else { return }
        
        // Ensure we have an anchor
        updateAnchorPiece()
        guard let anchor = anchorPiece else { return }
        
        // Establish or refresh mapping for the CV group
        let anchorRotationRad = CGFloat(anchor.rotation * .pi / 180)
        let _ = container.mappingService.establishOrUpdateMapping(
            groupId: cvGroupId,
            groupPieceIds: Set(placedPieces.map { $0.id }),
            pickAnchor: { () -> (anchorPieceId: String, anchorPositionScene: CGPoint, anchorRotation: CGFloat, anchorIsFlipped: Bool, anchorPieceType: TangramPieceType) in
                return (anchor.id, anchor.position, anchorRotationRad, anchor.isFlipped, anchor.pieceType)
            },
            candidateTargets: { () -> [(target: GamePuzzleData.TargetPiece, centroidScene: CGPoint, expectedZ: CGFloat, isFlipped: Bool)] in
                puzzle.targetPieces
                    .filter { !self.container.mappingService.consumedTargets(groupId: self.cvGroupId).contains($0.id) && $0.pieceType == anchor.pieceType }
                    .map { t in
                        let verts = TangramBounds.computeSKTransformedVertices(for: t)
                        let centroid = CGPoint(x: verts.map{$0.x}.reduce(0,+)/CGFloat(verts.count), y: verts.map{$0.y}.reduce(0,+)/CGFloat(verts.count))
                        let rawAng = TangramPoseMapper.rawAngle(from: t.transform)
                        let expectedZ = TangramPoseMapper.spriteKitAngle(fromRawAngle: rawAng)
                        let det = t.transform.a * t.transform.d - t.transform.b * t.transform.c
                        return (t, centroid, expectedZ, det < 0)
                    }
            }
        )
        
        // Resolve difficulty tolerances
        let tol = TangramGameConstants.Validation.tolerances(for: effectiveDifficulty)

        // Swap in a difficulty-configured validator for this pass
        let difficultyValidator = TangramPieceValidator(
            positionTolerance: tol.position,
            rotationTolerance: tol.rotationDeg,
            edgeContactTolerance: tol.edgeContact
        )

        // Validate non-anchor pieces using mapped pose and instance-binding
        // Require at least 2 pieces in the CV group before allowing any validations
        guard placedPieces.count >= 2 else {
            for i in 0..<placedPieces.count {
                var piece = placedPieces[i]
                if piece.id != anchor.id { piece.validationState = .pending }
                placedPieces[i] = piece
            }
            return
        }
        for i in 0..<placedPieces.count {
            var piece = placedPieces[i]
            
            // Only validate stationary pieces
            guard piece.isPlacedLongEnough() else {
                piece.validationState = .pending
                placedPieces[i] = piece
                continue
            }
            
            // Skip anchor itself for counting (treat as accepted mapping)
            if piece.id == anchor.id {
                piece.validationState = .pending
                placedPieces[i] = piece
                continue
            }
            
            guard let mapping = container.mappingService.mapping(for: cvGroupId) else {
                // Fallback to absolute feature-angle validation if mapping is unavailable
                if let assignedId = piece.assignedTargetId,
                   let target = puzzle.targetPieces.first(where: { $0.id == assignedId }) {
                    piece.validationState = target.matches(piece) ? .correct : .incorrect
                } else {
                    piece.validationState = .incorrect
                }
                placedPieces[i] = piece
                continue
            }
            
            // Compute mapped pose relative to anchor
            let mapped = container.mappingService.mapPieceToTargetSpace(
                piecePositionScene: piece.position,
                pieceRotation: CGFloat(piece.rotation * .pi / 180),
                pieceIsFlipped: piece.isFlipped,
                mapping: mapping,
                anchorPositionScene: anchor.position
            )
            
            // Validate against assigned target only
            if let assignedId = piece.assignedTargetId,
               let target = puzzle.targetPieces.first(where: { $0.id == assignedId }) {
                // Compute target centroid in SK space
                let verts = TangramBounds.computeSKTransformedVertices(for: target)
                let centroid = CGPoint(x: verts.map{$0.x}.reduce(0,+)/CGFloat(verts.count), y: verts.map{$0.y}.reduce(0,+)/CGFloat(verts.count))
                let isValid = container.mappingService.validateMapped(
                    mappedPose: (mapped.positionSK, mapped.rotationSK, mapped.isFlipped),
                    pieceType: piece.pieceType,
                    target: target,
                    targetCentroidScene: centroid,
                    validator: difficultyValidator
                )
                if isValid {
                    piece.validationState = .correct
                    container.mappingService.markTargetConsumed(groupId: cvGroupId, targetId: target.id)
                } else {
                    piece.validationState = .incorrect
                }
            } else {
                // Try to assign to nearest valid unconsumed target of same type
                var best: (id: String, dist: CGFloat)?
                for t in puzzle.targetPieces where t.pieceType == piece.pieceType && !container.mappingService.consumedTargets(groupId: cvGroupId).contains(t.id) {
                    let verts = TangramBounds.computeSKTransformedVertices(for: t)
                    let centroid = CGPoint(x: verts.map{$0.x}.reduce(0,+)/CGFloat(verts.count), y: verts.map{$0.y}.reduce(0,+)/CGFloat(verts.count))
                    let d = hypot(mapped.positionSK.x - centroid.x, mapped.positionSK.y - centroid.y)
                    let isValid = container.mappingService.validateMapped(
                        mappedPose: (mapped.positionSK, mapped.rotationSK, mapped.isFlipped),
                        pieceType: piece.pieceType,
                        target: t,
                        targetCentroidScene: centroid,
                        validator: difficultyValidator
                    )
                    if isValid {
                        if best == nil || d < best!.dist { best = (t.id, d) }
                    }
                }
                if let best = best,
                   let target = puzzle.targetPieces.first(where: { $0.id == best.id }) {
                    piece.assignedTargetId = target.id
                    piece.validationState = .correct
                    pieceAssignments[piece.id] = target.id
                    container.mappingService.markTargetConsumed(groupId: cvGroupId, targetId: target.id)
                } else {
                    piece.validationState = .incorrect
                }
            }
            
            placedPieces[i] = piece
        }
    }
    
    // MARK: - Hint System Tracking
    
    func onPieceMoved(_ pieceType: TangramPieceType) {
        lastMovedPiece = pieceType
        
        // Clear hint if user is moving the piece that the hint is for
        if let hint = currentHint, hint.targetPiece == pieceType {
            clearHint()
        }
    }
    
    func onPieceValidated(_ pieceType: TangramPieceType, isCorrect: Bool) {
        if isCorrect {
            lastProgressTime = Date()
            lastMovedPiece = nil
        }
    }
    
    func clearHintAnimation() {
        isShowingHintAnimation = false
    }
    
    func clearHint() {
        currentHint = nil
        isShowingHintAnimation = false
        showHints = false
        hintDismissTask?.cancel()
        hintDismissTask = nil
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
        // Ensure timer stops so the displayed time is the final completion time
        stopTimer()
        currentPhase = .puzzleComplete
        
        // Track completion metrics
        trackPuzzleCompletion()
        
        let xpAwarded = calculateXP()
        delegate?.gameDidCompleteLevel(xpAwarded: xpAwarded)
    }
    
    private func calculateXP() -> Int {
        guard let progress = gameProgress else { return 100 }
        
        let completionTime = Date().timeIntervalSince(progress.startTime)
        
        // Base XP
        let baseXP = 100
        
        // Time bonus (lose 1 XP per 10 seconds, max 50 bonus)
        let timeBonus = max(0, 50 - Int(completionTime / 10))
        
        // Hint penalty (10 XP per hint used)
        let hintPenalty = progress.hintsUsed * 10
        
        // Calculate final XP (minimum 10)
        return max(10, baseXP + timeBonus - hintPenalty)
    }
    
    // MARK: - Game State Management
    
    func resetGame() {
        // Clear any active hints
        clearHint()
        
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
    
    // MARK: - Metrics Tracking
    
    func setChildProfileId(_ childId: String) {
        currentChildProfileId = childId
    }
    
    private func startGameSession(puzzleId: String, puzzleName: String, difficulty: Int) {
        Task { @MainActor [weak self] in
            guard let self = self,
                  let supabase = self.supabaseService,
                  let childId = self.currentChildProfileId else {
                #if DEBUG
                print("Warning: Cannot start game session - missing supabase service or child ID")
                #endif
                return
            }
            
            // Check if we're authenticated
            if !supabase.isConnected {
                print("Warning: Not authenticated with Supabase - game session will not be tracked")
                return
            }
            
            do {
                currentSessionId = try await supabase.startGameSession(
                    childProfileId: childId,
                    gameId: "tangram",
                    sessionData: [
                        "puzzle_id": puzzleId,
                        "puzzle_name": puzzleName,
                        "difficulty": difficulty
                    ]
                )
                print("Started game session: \(currentSessionId ?? "unknown")")
            } catch {
                print("Failed to start game session: \(error)")
                // Don't let tracking errors interrupt gameplay
                currentSessionId = nil
            }
        }
    }
    
    private func endGameSession(completed: Bool) {
        Task { @MainActor [weak self] in
            guard let self = self,
                  let supabase = self.supabaseService,
                  let sessionId = self.currentSessionId else {
                return
            }
            
            let finalXP = completed ? calculateXP() : 0
            let levelsCompleted = completed ? 1 : 0
            
            do {
                try await supabase.endGameSession(
                    sessionId: sessionId,
                    finalXPEarned: finalXP,
                    finalLevelsCompleted: levelsCompleted,
                    finalSessionData: [
                        "completed": completed,
                        "hints_used": gameProgress?.hintsUsed ?? 0,
                        "completion_time": gameProgress.map { Date().timeIntervalSince($0.startTime) } ?? 0
                    ]
                )
                print("Ended game session: \(sessionId)")
            } catch {
                print("Failed to end game session: \(error)")
            }
            
            currentSessionId = nil
        }
    }
    
    private func trackHintUsage(hint: TangramHintEngine.HintData) {
        Task { @MainActor [weak self] in
            guard let self = self,
                  let supabase = self.supabaseService,
                  let childId = self.currentChildProfileId,
                  let puzzle = self.selectedPuzzle,
                  let progress = gameProgress else {
                return
            }
            
            // Check if we're authenticated
            if !supabase.isConnected {
                print("Warning: Not authenticated - hint usage will not be tracked")
                return
            }
            
            do {
                try await supabase.trackLearningEvent(
                    childProfileId: childId,
                    eventType: "hint_used",
                    gameId: "tangram",
                    xpAwarded: 0,
                    eventData: [
                        "puzzle_id": puzzle.id,
                        "puzzle_name": puzzle.name,
                        "hint_type": String(describing: hint.hintType),
                        "hint_reason": String(describing: hint.reason),
                        "target_piece": hint.targetPiece.rawValue,
                        "time_since_start": Date().timeIntervalSince(progress.startTime),
                        "pieces_completed": progress.correctPieces.count,
                        "total_hints_used": progress.hintsUsed
                    ],
                    sessionId: currentSessionId
                )
            } catch {
                // Don't let tracking errors interrupt gameplay
            }
        }
    }
    
    private func trackPuzzleCompletion() {
        Task { @MainActor [weak self] in
            guard let self = self,
                  let supabase = self.supabaseService,
                  let childId = self.currentChildProfileId,
                  let puzzle = self.selectedPuzzle,
                  let progress = gameProgress else {
                return
            }
            
            let completionTime = Date().timeIntervalSince(progress.startTime)
            let finalXP = calculateXP()
            
            do {
                try await supabase.trackLearningEvent(
                    childProfileId: childId,
                    eventType: "puzzle_completed",
                    gameId: "tangram",
                    xpAwarded: finalXP,
                    eventData: [
                        "puzzle_id": puzzle.id,
                        "puzzle_name": puzzle.name,
                        "difficulty": puzzle.difficulty,
                        "completion_time_seconds": completionTime,
                        "hints_used": progress.hintsUsed,
                        "xp_awarded": finalXP
                    ],
                    sessionId: currentSessionId
                )
                
                // End the session as completed
                endGameSession(completed: true)
                
            } catch {
                // Handle error silently
            }
        }
    }
    
}