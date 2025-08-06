//
//  TangramEditorViewModel.swift
//  Bemo
//
//  ViewModel for Tangram Editor - focused on UI state management
//

import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
class TangramEditorViewModel {
    
    // MARK: - Type Aliases
    typealias ConnectionPoint = PiecePlacementService.ConnectionPoint
    
    // MARK: - Business State (Observable)
    
    var puzzle: TangramPuzzle
    var savedPuzzles: [TangramPuzzle] = []
    var validationState: ValidationState = .unknown
    var editorState: EditorState = .idle
    var availableConnectionPoints: [ConnectionPoint] = []
    var pieceManipulationModes: [String: ManipulationMode] = [:]  // PieceId -> Mode
    
    // MARK: - UI State (Observable)
    
    var uiState = TangramEditorUIState()
    
    // Forwarding properties for backward compatibility
    var selectedPieceIds: Set<String> { 
        get { uiState.selectedPieceIds }
        set { uiState.selectedPieceIds = newValue }
    }
    var editMode: TangramEditorUIState.EditMode { 
        get { uiState.editMode }
        set { uiState.editMode = newValue }
    }
    var navigationState: TangramEditorUIState.NavigationState { 
        get { uiState.navigationState }
        set { uiState.navigationState = newValue }
    }
    var selectedCanvasPoints: [ConnectionPoint] { 
        get { uiState.selectedCanvasPoints }
        set { uiState.selectedCanvasPoints = newValue }
    }
    var selectedPendingPoints: [ConnectionPoint] { 
        get { uiState.selectedPendingPoints }
        set { uiState.selectedPendingPoints = newValue }
    }
    var pendingPieceRotation: Double { 
        get { uiState.pendingPieceRotation }
        set { uiState.pendingPieceRotation = newValue }
    }
    var pendingPieceType: PieceType? { 
        get { uiState.pendingPieceType }
        set { uiState.pendingPieceType = newValue }
    }
    var previewTransform: CGAffineTransform? { 
        get { uiState.previewTransform }
        set { uiState.previewTransform = newValue }
    }
    var previewPiece: TangramPiece? { 
        get { uiState.previewPiece }
        set { uiState.previewPiece = newValue }
    }
    var currentCanvasSize: CGSize { 
        get { uiState.currentCanvasSize }
        set { uiState.currentCanvasSize = newValue }
    }
    var showSettings: Bool { 
        get { uiState.showSettings }
        set { uiState.showSettings = newValue }
    }
    var showSaveDialog: Bool { 
        get { uiState.showSaveDialog }
        set { uiState.showSaveDialog = newValue }
    }
    var manipulatingPieceId: String? { 
        get { uiState.manipulatingPieceId }
        set { uiState.manipulatingPieceId = newValue }
    }
    var ghostTransform: CGAffineTransform? { 
        get { uiState.ghostTransform }
        set { uiState.ghostTransform = newValue }
    }
    var showSnapIndicator: Bool { 
        get { uiState.showSnapIndicator }
        set { uiState.showSnapIndicator = newValue }
    }
    var showErrorAlert: Bool { 
        get { uiState.showErrorAlert }
        set { uiState.showErrorAlert = newValue }
    }
    var errorMessage: String { 
        get { uiState.errorMessage }
        set { uiState.errorMessage = newValue }
    }
    
    // Error handling state (keeping separate for now)
    var currentError: TangramEditorError? = nil
    
    // Delegate
    weak var delegate: GameDelegate?
    var onPuzzleChanged: ((TangramPuzzle) -> Void)?
    
    // MARK: - Services (Dependency Injection)
    
    private let coordinator: TangramEditorCoordinator
    private let placementService: PiecePlacementService
    private let persistenceService: PuzzlePersistenceService
    private let undoManager: UndoRedoManager
    private let validationService: ValidationService
    private let lockingService: PieceLockingService
    private let manipulationService: PieceManipulationService
    let toastService: ToastService  // Public for view access
    
    // MARK: - Initialization
    
    init(puzzle: TangramPuzzle? = nil,
         coordinator: TangramEditorCoordinator,
         placementService: PiecePlacementService,
         persistenceService: PuzzlePersistenceService,
         undoManager: UndoRedoManager,
         validationService: ValidationService,
         lockingService: PieceLockingService,
         manipulationService: PieceManipulationService,
         toastService: ToastService) {
        
        // Initialize services (now required, no defaults)
        self.coordinator = coordinator
        self.placementService = placementService
        self.persistenceService = persistenceService
        self.undoManager = undoManager
        self.validationService = validationService
        self.lockingService = lockingService
        self.manipulationService = manipulationService
        self.toastService = toastService
        
        // Initialize puzzle
        self.puzzle = puzzle ?? TangramPuzzle(name: "New Puzzle")
        
        // Set initial state based on puzzle content
        if self.puzzle.pieces.isEmpty {
            // Start in selecting first piece state for empty puzzles
            self.editorState = .selectingFirstPiece
        } else {
            // Start in idle state for existing puzzles
            self.editorState = .idle
        }
        
        // Load saved puzzles on init
        Task { [weak self] in
            await self?.loadSavedPuzzles()
        }
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: TangramEditorError) {
        currentError = error
        toastService.show(error: error)
        
        // Log error for debugging (in production this could go to error tracking)
        print("[TangramEditor] Error: \(error.errorDescription ?? "Unknown error")")
    }
    
    func dismissError() {
        toastService.dismiss()
        currentError = nil
    }
    
    // MARK: - State Management
    
    /// Validates and performs state transitions
    func transitionToState(_ newState: EditorState) -> Bool {
        // Validate transition is allowed
        guard isValidTransition(from: editorState, to: newState) else {
            print("[TangramEditor] Invalid state transition: \(editorState) -> \(newState)")
            return false
        }
        
        // Perform any cleanup for current state before transitioning
        cleanupCurrentState()
        
        // Update state
        editorState = newState
        
        // Perform any setup for new state
        setupNewState()
        
        return true
    }
    
    /// Check if a state transition is valid
    private func isValidTransition(from currentState: EditorState, to newState: EditorState) -> Bool {
        switch (currentState, newState) {
        // From idle
        case (.idle, .selectingFirstPiece) where puzzle.pieces.isEmpty:
            return true
        case (.idle, .selectingNextPiece) where !puzzle.pieces.isEmpty:
            return true
        case (.idle, .pieceSelected):
            return true
            
        // First piece flow
        case (.selectingFirstPiece, .manipulatingFirstPiece):
            return true
        case (.manipulatingFirstPiece, .idle):
            return true
        case (.manipulatingFirstPiece, .selectingFirstPiece):
            return true
            
        // Subsequent pieces flow
        case (.selectingNextPiece, .selectingCanvasConnections):
            return true
        case (.selectingCanvasConnections, .selectingPendingConnections):
            return true
        case (.selectingPendingConnections, .manipulatingPendingPiece):
            return true
        case (.selectingPendingConnections, .previewingPlacement):
            return true
        case (.manipulatingPendingPiece, .previewingPlacement):
            return true
        case (.previewingPlacement, .idle):
            return true
            
        // Editing flow
        case (.pieceSelected, .unlockingPiece):
            return true
        case (.pieceSelected, .idle):
            return true
        case (.unlockingPiece, .manipulatingExistingPiece):
            return true
        case (.manipulatingExistingPiece, .idle):
            return true
            
        // Error recovery
        case (_, .error):
            return true
        case (.error, _):
            return true
            
        // Cancel operations
        case (_, .idle):
            return true
            
        default:
            return false
        }
    }
    
    /// Cleanup when leaving current state
    private func cleanupCurrentState() {
        switch editorState {
        case .selectingCanvasConnections, .selectingPendingConnections:
            selectedCanvasPoints.removeAll()
            selectedPendingPoints.removeAll()
        case .manipulatingPendingPiece, .manipulatingExistingPiece:
            ghostTransform = nil
            manipulatingPieceId = nil
            showSnapIndicator = false
        default:
            break
        }
    }
    
    /// Setup when entering new state
    private func setupNewState() {
        switch editorState {
        case .selectingFirstPiece:
            clearSelectionState()
        case .selectingNextPiece:
            clearSelectionState()
            pendingPieceType = nil
        case .selectingCanvasConnections:
            updateAvailableConnectionPoints()
        default:
            break
        }
    }
    
    /// Human-readable description of current state
    var currentStateDescription: String {
        switch editorState {
        case .idle:
            return puzzle.pieces.isEmpty ? "Start by selecting a shape" : "Select a shape to add or tap a piece to edit"
        case .selectingFirstPiece:
            return "Select your first shape"
        case .manipulatingFirstPiece:
            return "Rotate or flip to position the piece"
        case .selectingNextPiece:
            return "Select the next shape to add"
        case .selectingCanvasConnections(let maxPoints):
            return "Select up to \(maxPoints) connection point(s) on existing pieces"
        case .selectingPendingConnections(_, let maxPoints):
            return "Select up to \(maxPoints) matching connection point(s) on the new piece"
        case .manipulatingPendingPiece(_, let mode, _):
            switch mode {
            case .rotatable:
                return "Rotate the piece around the connection point"
            case .slidable:
                return "Slide the piece along the edge"
            case .locked:
                return "Piece position is locked by connections"
            }
        case .previewingPlacement:
            return "Confirm or cancel piece placement"
        case .pieceSelected(_, let isLocked):
            return isLocked ? "Piece is locked. Unlock to edit" : "Piece selected for editing"
        case .unlockingPiece:
            return "Unlocking piece for manipulation"
        case .manipulatingExistingPiece(_, let mode):
            switch mode {
            case .rotatable:
                return "Rotate the piece around the connection point"
            case .slidable:
                return "Slide the piece along the edge"
            case .locked:
                return "Piece cannot be manipulated"
            }
        case .error(let message):
            return message
        }
    }
    
    // MARK: - UI Actions
    
    func startAddingPiece(type: PieceType) {
        guard !isPieceTypeAlreadyPlaced(type) else { 
            handleError(.pieceAlreadyPlaced(type.rawValue))
            return 
        }
        
        pendingPieceType = type
        pendingPieceRotation = 0
        
        if puzzle.pieces.isEmpty {
            // First piece flow - we should already be in selectingFirstPiece state
            // Transition to manipulating the first piece
            _ = transitionToState(.manipulatingFirstPiece(type: type, rotation: 0, isFlipped: false))
        } else {
            // Subsequent pieces flow - need to select connections first
            _ = transitionToState(.selectingCanvasConnections(maxPoints: 2))
        }
    }
    
    func confirmPendingPiece(canvasSize: CGSize? = nil) {
        undoManager.saveState(puzzle: puzzle)
        
        let size = canvasSize ?? currentCanvasSize
        
        switch editorState {
        case .manipulatingFirstPiece(let type, let rotation, _):
            // Place first piece at center (convert degrees to radians)
            var piece = placementService.placeFirstPiece(
                type: type,
                rotation: rotation * .pi / 180,
                canvasSize: size
            )
            piece.isLocked = true  // First piece is always locked
            puzzle.pieces.append(piece)
            // After placing first piece, transition to selecting next piece
            _ = transitionToState(.selectingNextPiece)
            autoLockPieces()  // Auto-lock based on connections
            updateManipulationModes()
            validate()
            notifyPuzzleChanged()
            toastService.showSuccess("First piece placed")
            
        case .previewingPlacement(let piece):
            // Add the previewed piece to the puzzle
            puzzle.pieces.append(piece)
            // After placing any piece, go to selecting next piece
            _ = transitionToState(.selectingNextPiece)
            autoLockPieces()  // Auto-lock based on connections
            updateManipulationModes()
            validate()
            notifyPuzzleChanged()
            toastService.showSuccess("Piece placed successfully")
            
        case .manipulatingPendingPiece(let type, _, let rotation):
            // Place connected piece (convert degrees to radians)
            let result = coordinator.placeConnectedPiece(
                type: type,
                rotation: rotation * .pi / 180,
                canvasConnections: selectedCanvasPoints,
                pieceConnections: selectedPendingPoints,
                existingPieces: puzzle.pieces,
                puzzle: &puzzle
            )
            
            switch result {
            case .success(_):
                // After successfully placing a connected piece, go to selecting next piece
                _ = transitionToState(.selectingNextPiece)
                updateManipulationModes()
                validate()
                notifyPuzzleChanged()
                toastService.showSuccess("Piece connected successfully")
                
            case .failure(let coordinatorError):
                // Convert coordinator error to TangramEditorError
                let editorError: TangramEditorError
                switch coordinatorError {
                case .invalidConnections:
                    editorError = .invalidConnectionPoints("Connection types don't match")
                case .placementCalculationFailed:
                    editorError = .placementCalculationFailed("Could not calculate valid placement")
                case .overlappingPieces:
                    editorError = .overlappingPieces("Piece would overlap with existing pieces")
                case .validationFailed:
                    editorError = .validationFailed("Placement validation failed")
                default:
                    editorError = .invalidPlacement("Unknown placement error")
                }
                handleError(editorError)
            }
            
        default:
            break
        }
    }
    
    func cancelPendingPiece() {
        _ = transitionToState(.idle)
        clearSelectionState()
    }
    
    func rotatePendingPiece(by degrees: Double) {
        pendingPieceRotation += degrees
        
        // Update the rotation in the current state
        switch editorState {
        case .manipulatingFirstPiece(let type, _, let isFlipped):
            _ = transitionToState(.manipulatingFirstPiece(type: type, rotation: pendingPieceRotation, isFlipped: isFlipped))
        case .manipulatingPendingPiece(let type, let mode, _):
            _ = transitionToState(.manipulatingPendingPiece(type: type, mode: mode, rotation: pendingPieceRotation))
        default:
            break
        }
        
        updatePreviewIfNeeded()
    }
    
    func flipPendingPiece() {
        // Only parallelogram can flip
        guard let pieceType = pendingPieceType, pieceType == .parallelogram else { return }
        
        switch editorState {
        case .manipulatingFirstPiece(let type, let rotation, let isFlipped):
            _ = transitionToState(.manipulatingFirstPiece(type: type, rotation: rotation, isFlipped: !isFlipped))
        default:
            break
        }
        
        updatePreviewIfNeeded()
    }
    
    func getConnectionPointsForPendingPiece(type: PieceType, scale: CGFloat) -> [ConnectionPoint] {
        // For the pending piece preview, we need connection points in local space
        // (not transformed) because PendingConnectionPoint will apply rotation and centering
        var points: [ConnectionPoint] = []
        let vertices = TangramGeometry.vertices(for: type)
        let edges = TangramGeometry.edges(for: type)
        
        // Scale vertices to match the preview scale (50)
        let scaledVertices = vertices.map { 
            CGPoint(x: $0.x * TangramConstants.visualScale, 
                    y: $0.y * TangramConstants.visualScale)
        }
        
        // Create a dummy piece ID for consistency
        let pieceId = "pending_\(type.rawValue)"
        
        // Add vertex points (in local space, will be rotated by PendingConnectionPoint)
        for (index, vertex) in scaledVertices.enumerated() {
            points.append(ConnectionPoint(
                type: .vertex(index: index),
                position: vertex,
                pieceId: pieceId
            ))
        }
        
        // Add edge midpoints (in local space)
        for i in 0..<scaledVertices.count {
            let start = scaledVertices[i]
            let end = scaledVertices[(i + 1) % scaledVertices.count]
            let midpoint = CGPoint(
                x: (start.x + end.x) / 2,
                y: (start.y + end.y) / 2
            )
            points.append(ConnectionPoint(
                type: .edge(index: i),
                position: midpoint,
                pieceId: pieceId
            ))
        }
        
        return points
    }
    
    func togglePendingPoint(_ point: ConnectionPoint) {
        if let index = selectedPendingPoints.firstIndex(where: { $0.id == point.id }) {
            selectedPendingPoints.remove(at: index)
        } else {
            selectedPendingPoints.append(point)
        }
        
        // Check if we have enough points to proceed
        if selectedCanvasPoints.count == selectedPendingPoints.count && !selectedCanvasPoints.isEmpty {
            // Calculate manipulation mode and transition to manipulating state
            if let type = pendingPieceType {
                // TODO: Calculate actual manipulation mode based on connections
                let mode = ManipulationMode.locked // Placeholder
                _ = transitionToState(.manipulatingPendingPiece(type: type, mode: mode, rotation: pendingPieceRotation))
            }
        }
    }
    
    func toggleCanvasPoint(_ point: ConnectionPoint) {
        if let index = selectedCanvasPoints.firstIndex(where: { $0.id == point.id }) {
            selectedCanvasPoints.remove(at: index)
        } else {
            selectedCanvasPoints.append(point)
        }
        
        // Check if we have the maximum number of points
        if selectedCanvasPoints.count >= 2 {
            proceedToPendingPiece()
        }
    }
    
    func proceedToPendingPiece() {
        // Transition to selecting pending piece connections
        if !selectedCanvasPoints.isEmpty, let type = pendingPieceType {
            _ = transitionToState(.selectingPendingConnections(pieceType: type, maxPoints: selectedCanvasPoints.count))
        }
    }
    
    // MARK: - Selection Management
    
    func selectPiece(id: String) {
        // Check if piece is locked before allowing selection
        guard let piece = puzzle.pieces.first(where: { $0.id == id }) else { return }
        
        if piece.isLocked {
            // Transition to locked piece state
            _ = transitionToState(.pieceSelected(id: id, isLocked: true))
        } else {
            if uiState.editMode == .select {
                selectedPieceIds.insert(id)
                _ = transitionToState(.pieceSelected(id: id, isLocked: false))
            }
        }
    }
    
    func togglePieceSelection(_ pieceId: String) {
        if selectedPieceIds.contains(pieceId) {
            selectedPieceIds.remove(pieceId)
        } else {
            selectedPieceIds.insert(pieceId)
        }
    }
    
    func clearSelection() {
        selectedPieceIds.removeAll()
    }
    
    func selectAllPieces() {
        selectedPieceIds = Set(puzzle.pieces.map { $0.id })
    }
    
    // MARK: - Piece Locking
    
    func togglePieceLock(id: String) {
        undoManager.saveState(puzzle: puzzle)
        
        let result = lockingService.toggleLock(id: id, in: &puzzle)
        switch result {
        case .success(let isNowLocked):
            if isNowLocked {
                _ = transitionToState(.pieceSelected(id: id, isLocked: true))
                toastService.showInfo("Piece locked")
            } else {
                _ = transitionToState(.pieceSelected(id: id, isLocked: false))
                toastService.showSuccess("Piece unlocked")
            }
            updateManipulationModes()
            notifyPuzzleChanged()
            
        case .failure(let error):
            handleError(error)
        }
    }
    
    func unlockPiece(id: String) {
        undoManager.saveState(puzzle: puzzle)
        
        let result = lockingService.unlockPiece(id: id, in: &puzzle)
        switch result {
        case .success:
            _ = transitionToState(.manipulatingExistingPiece(id: id, mode: determineManipulationMode(for: id)))
            updateManipulationModes()
            notifyPuzzleChanged()
            
        case .failure(let error):
            handleError(error)
        }
    }
    
    func autoLockPieces() {
        lockingService.autoLockPieces(in: &puzzle)
        updateManipulationModes()
    }
    
    // MARK: - Piece Operations
    
    func removePiece(id: String) {
        // Check if piece is locked
        guard let piece = puzzle.pieces.first(where: { $0.id == id }) else { return }
        
        if piece.isLocked {
            handleError(.operationNotAllowed("Piece must be unlocked before deletion"))
            return
        }
        
        undoManager.saveState(puzzle: puzzle)
        puzzle.pieces.removeAll { $0.id == id }
        puzzle.connections.removeAll { $0.involvesPiece(id) }
        validate()
        notifyPuzzleChanged()
        _ = transitionToState(.idle)
    }
    
    func removeSelectedPieces() {
        // Check if any selected pieces are locked
        let selectedPieces = puzzle.pieces.filter { selectedPieceIds.contains($0.id) }
        let lockedPieces = selectedPieces.filter { $0.isLocked }
        
        if !lockedPieces.isEmpty {
            handleError(.operationNotAllowed("\(lockedPieces.count) piece(s) must be unlocked before deletion"))
            return
        }
        
        undoManager.saveState(puzzle: puzzle)
        let idsToRemove = selectedPieceIds
        puzzle.pieces.removeAll { idsToRemove.contains($0.id) }
        puzzle.connections.removeAll { connection in
            idsToRemove.contains { connection.involvesPiece($0) }
        }
        selectedPieceIds.removeAll()
        validate()
        notifyPuzzleChanged()
        _ = transitionToState(.idle)
    }
    
    func updatePieceTransform(id: String, transform: CGAffineTransform) {
        guard let index = puzzle.pieces.firstIndex(where: { $0.id == id }) else { return }
        
        undoManager.saveState(puzzle: puzzle)
        puzzle.pieces[index].transform = transform
        validate()
        notifyPuzzleChanged()
    }
    
    // MARK: - Undo/Redo
    
    var canUndo: Bool { undoManager.canUndo }
    var canRedo: Bool { undoManager.canRedo }
    
    func undo() {
        guard let snapshot = undoManager.popUndo(currentPuzzle: puzzle) else { return }
        snapshot.apply(to: &puzzle)
        selectedPieceIds.removeAll()
        validate()
        notifyPuzzleChanged()
    }
    
    func redo() {
        guard let snapshot = undoManager.popRedo(currentPuzzle: puzzle) else { return }
        snapshot.apply(to: &puzzle)
        selectedPieceIds.removeAll()
        validate()
        notifyPuzzleChanged()
    }
    
    // MARK: - Persistence
    
    func save() async throws {
        puzzle.modifiedDate = Date()
        puzzle.solutionChecksum = generateChecksum()
        let updatedPuzzle = try await persistenceService.savePuzzle(puzzle)
        puzzle = updatedPuzzle
        await loadSavedPuzzles()
    }
    
    func loadSavedPuzzles() async {
        do {
            let allPuzzles = try await persistenceService.listPuzzles()
            var loadedPuzzles: [TangramPuzzle] = []
            for metadata in allPuzzles {
                if let fullPuzzle = try? await persistenceService.loadPuzzle(id: metadata.id) {
                    loadedPuzzles.append(fullPuzzle)
                }
            }
            savedPuzzles = loadedPuzzles
        } catch {
            print("Failed to load puzzles: \(error)")
            savedPuzzles = []
        }
    }
    
    func loadPuzzle(from loadedPuzzle: TangramPuzzle) {
        puzzle = loadedPuzzle
        _ = transitionToState(.idle)
        validate()
        notifyPuzzleChanged()
        uiState.navigationState = .editor
    }
    
    func createNewPuzzle() {
        reset()
        puzzle = TangramPuzzle(name: "New Puzzle", category: .custom, difficulty: .medium)
        _ = transitionToState(.idle)
        uiState.navigationState = .editor
    }
    
    func deletePuzzle(_ puzzleToDelete: TangramPuzzle) async {
        do {
            try await persistenceService.deletePuzzle(id: puzzleToDelete.id)
            await loadSavedPuzzles()
        } catch {
            print("Failed to delete puzzle: \(error)")
        }
    }
    
    func duplicatePuzzle(_ puzzleToDuplicate: TangramPuzzle) async {
        var newPuzzle = TangramPuzzle(
            name: "\(puzzleToDuplicate.name) Copy",
            category: puzzleToDuplicate.category,
            difficulty: puzzleToDuplicate.difficulty
        )
        
        newPuzzle.pieces = puzzleToDuplicate.pieces
        newPuzzle.connections = puzzleToDuplicate.connections
        newPuzzle.solutionChecksum = puzzleToDuplicate.solutionChecksum
        newPuzzle.createdBy = puzzleToDuplicate.createdBy
        newPuzzle.tags = puzzleToDuplicate.tags
        
        do {
            _ = try await persistenceService.savePuzzle(newPuzzle)
            await loadSavedPuzzles()
        } catch {
            print("Failed to duplicate puzzle: \(error)")
        }
    }
    
    // MARK: - Validation
    
    func validate() {
        validationState = coordinator.validatePuzzle(puzzle)
    }
    
    // MARK: - UI State Methods
    
    func toggleSettings() {
        showSettings.toggle()
    }
    
    func requestSave() {
        showSaveDialog = true
    }
    
    func reset() {
        puzzle = TangramPuzzle(name: "New Puzzle")
        selectedPieceIds.removeAll()
        validationState = .unknown
        uiState.editMode = .select
        _ = transitionToState(.idle)
        undoManager.clearHistory()
    }
    
    func clearPuzzle() {
        undoManager.saveState(puzzle: puzzle)
        puzzle.pieces.removeAll()
        puzzle.connections.removeAll()
        selectedPieceIds.removeAll()
        validationState = .unknown
        _ = transitionToState(.idle)
        notifyPuzzleChanged()
    }
    
    func recenterPuzzle() {
        guard !puzzle.pieces.isEmpty else { 
            return 
        }
        
        // Don't recenter if canvas size is not properly set
        guard currentCanvasSize.width > 0 && currentCanvasSize.height > 0 else {
            return
        }
        
        // Use centralized coordinate system to get current center
        guard let currentCenter = TangramCoordinateSystem.getCenter(of: puzzle.pieces) else {
            return
        }
        
        // Calculate target center
        let targetCenter = CGPoint(
            x: currentCanvasSize.width / 2,
            y: currentCanvasSize.height / 2
        )
        
        // Calculate translation needed
        let dx = targetCenter.x - currentCenter.x
        let dy = targetCenter.y - currentCenter.y
        
        // Check for valid translation values
        if !dx.isFinite || !dy.isFinite {
            return
        }
        
        // Apply translation to all pieces
        undoManager.saveState(puzzle: puzzle)
        for i in 0..<puzzle.pieces.count {
            let oldTransform = puzzle.pieces[i].transform
            // Use direct world-space translation (centralized system pattern)
            var newTransform = puzzle.pieces[i].transform
            newTransform.tx += dx
            newTransform.ty += dy
            puzzle.pieces[i].transform = newTransform
        }
        
        notifyPuzzleChanged()
    }
    
    func getConnectionPoints(for pieceId: String) -> [ConnectionPoint] {
        guard let piece = puzzle.pieces.first(where: { $0.id == pieceId }) else {
            return []
        }
        // Use centralized coordinate system directly for better performance
        return TangramCoordinateSystem.getConnectionPoints(for: piece)
    }
    
    // MARK: - Manipulation Mode Management
    
    /// Determine manipulation mode for a piece based on its connections
    func determineManipulationMode(for pieceId: String) -> ManipulationMode {
        guard let piece = puzzle.pieces.first(where: { $0.id == pieceId }) else {
            return .locked
        }
        
        return manipulationService.calculateManipulationMode(piece: piece, connections: puzzle.connections)
    }
    
    /// Update manipulation modes for all pieces
    func updateManipulationModes() {
        pieceManipulationModes.removeAll()
        
        for piece in puzzle.pieces {
            let mode = determineManipulationMode(for: piece.id)
            pieceManipulationModes[piece.id] = mode
        }
    }
    
    // MARK: - Manipulation Handlers
    
    /// Handle rotation gesture for a piece with single vertex connection
    func handleRotation(pieceId: String, angle: Double) {
        guard let mode = pieceManipulationModes[pieceId],
              let pieceIndex = puzzle.pieces.firstIndex(where: { $0.id == pieceId }) else {
            return
        }
        
        switch mode {
        case .rotatable(let pivot, let snapAngles):
            let piece = puzzle.pieces[pieceIndex]
            
            // Convert angle to degrees for snapping
            let angleDegrees = angle * 180 / .pi
            
            // Find nearest snap angle
            let snappedAngle = snapAngles.min(by: { 
                abs($0 - angleDegrees) < abs($1 - angleDegrees) 
            }) ?? angleDegrees
            
            // Convert back to radians
            let snappedRadians = snappedAngle * .pi / 180
            
            // Create rotation transform around pivot
            var transform = CGAffineTransform.identity
            transform = transform.translatedBy(x: pivot.x, y: pivot.y)
            transform = transform.rotated(by: snappedRadians)
            transform = transform.translatedBy(x: -pivot.x, y: -pivot.y)
            
            // Apply to piece's base transform
            let newTransform = piece.transform.concatenating(transform)
            
            // Check for overlaps with validation service
            let testPiece = TangramPiece(type: piece.type, transform: newTransform)
            let otherPieces = puzzle.pieces.filter { $0.id != pieceId }
            
            var hasOverlap = false
            for other in otherPieces {
                if validationService.hasAreaOverlap(pieceA: testPiece, pieceB: other) {
                    hasOverlap = true
                    break
                }
            }
            
            if !hasOverlap {
                // Update ghost preview
                ghostTransform = newTransform
                showSnapIndicator = abs(angle - snappedRadians) < 0.1
                
                // Store as manipulating piece
                manipulatingPieceId = pieceId
            }
            
        default:
            break
        }
    }
    
    /// Confirm the rotation and apply it to the piece
    func confirmRotation() {
        guard let pieceId = manipulatingPieceId,
              let transform = ghostTransform,
              let pieceIndex = puzzle.pieces.firstIndex(where: { $0.id == pieceId }) else {
            return
        }
        
        undoManager.saveState(puzzle: puzzle)
        puzzle.pieces[pieceIndex].transform = transform
        
        // Clear manipulation state
        manipulatingPieceId = nil
        ghostTransform = nil
        showSnapIndicator = false
        
        validate()
        notifyPuzzleChanged()
    }
    
    /// Handle sliding gesture for a piece with single edge connection
    func handleSlide(pieceId: String, distance: Double) {
        guard let mode = pieceManipulationModes[pieceId],
              let pieceIndex = puzzle.pieces.firstIndex(where: { $0.id == pieceId }) else {
            return
        }
        
        switch mode {
        case .slidable(let edge, let range, let snapPositions):
            let piece = puzzle.pieces[pieceIndex]
            
            // Clamp distance to valid range
            let clampedDistance = max(range.lowerBound, min(range.upperBound, distance))
            
            // Find nearest snap position
            let normalizedDistance = (clampedDistance - range.lowerBound) / (range.upperBound - range.lowerBound)
            let snappedPosition = snapPositions.min(by: {
                abs($0 - normalizedDistance) < abs($1 - normalizedDistance)
            }) ?? normalizedDistance
            
            // Convert back to actual distance
            let snappedDistance = range.lowerBound + snappedPosition * (range.upperBound - range.lowerBound)
            
            // Calculate translation along edge vector
            let translation = CGVector(
                dx: edge.vector.dx * snappedDistance,
                dy: edge.vector.dy * snappedDistance
            )
            
            // Create new transform
            var newTransform = piece.transform
            newTransform.tx += translation.dx
            newTransform.ty += translation.dy
            
            // Check for overlaps
            let testPiece = TangramPiece(type: piece.type, transform: newTransform)
            let otherPieces = puzzle.pieces.filter { $0.id != pieceId }
            
            var hasOverlap = false
            for other in otherPieces {
                if validationService.hasAreaOverlap(pieceA: testPiece, pieceB: other) {
                    hasOverlap = true
                    break
                }
            }
            
            if !hasOverlap {
                // Update ghost preview
                ghostTransform = newTransform
                showSnapIndicator = snapPositions.contains(snappedPosition)
                
                // Store as manipulating piece
                manipulatingPieceId = pieceId
            }
            
        default:
            break
        }
    }
    
    /// Confirm the slide and apply it to the piece
    func confirmSlide() {
        guard let pieceId = manipulatingPieceId,
              let transform = ghostTransform,
              let pieceIndex = puzzle.pieces.firstIndex(where: { $0.id == pieceId }) else {
            return
        }
        
        undoManager.saveState(puzzle: puzzle)
        puzzle.pieces[pieceIndex].transform = transform
        
        // Clear manipulation state
        manipulatingPieceId = nil
        ghostTransform = nil
        showSnapIndicator = false
        
        validate()
        notifyPuzzleChanged()
    }
    
    /// Cancel any ongoing manipulation
    func cancelManipulation() {
        manipulatingPieceId = nil
        ghostTransform = nil
        showSnapIndicator = false
    }
    
    // MARK: - Private Helpers
    
    private func isPieceTypeAlreadyPlaced(_ type: PieceType) -> Bool {
        puzzle.pieces.contains { $0.type == type }
    }
    
    private func updateAvailableConnectionPoints() {
        availableConnectionPoints = puzzle.pieces.flatMap { piece in
            placementService.getConnectionPoints(for: piece)
        }
    }
    
    private func updatePreviewIfNeeded() {
        // Update preview based on current selection
        // Implementation depends on current state
    }
    
    private func clearSelectionState() {
        uiState.clearSelectionState()
        availableConnectionPoints.removeAll()
    }
    
    private func notifyPuzzleChanged() {
        onPuzzleChanged?(puzzle)
    }
    
    private func generateChecksum() -> String {
        let positionString = puzzle.pieces.map { piece in
            "\(piece.type.rawValue):\(piece.transform.tx),\(piece.transform.ty)"
        }.sorted().joined()
        return String(positionString.hashValue)
    }
    
    // MARK: - Nested Types
    
    enum EditorState: Equatable {
        case idle
        
        // First piece workflow
        case selectingFirstPiece
        case manipulatingFirstPiece(type: PieceType, rotation: Double, isFlipped: Bool)
        
        // Subsequent pieces workflow
        case selectingNextPiece
        case selectingCanvasConnections(maxPoints: Int)
        case selectingPendingConnections(pieceType: PieceType, maxPoints: Int)
        case manipulatingPendingPiece(type: PieceType, mode: ManipulationMode, rotation: Double)
        case previewingPlacement(piece: TangramPiece)
        
        // Editing existing pieces
        case pieceSelected(id: String, isLocked: Bool)
        case unlockingPiece(id: String)
        case manipulatingExistingPiece(id: String, mode: ManipulationMode)
        
        // Error recovery
        case error(String)
        
        static func == (lhs: EditorState, rhs: EditorState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), 
                 (.selectingFirstPiece, .selectingFirstPiece),
                 (.selectingNextPiece, .selectingNextPiece):
                return true
            case (.manipulatingFirstPiece(let lType, let lRot, let lFlip), 
                  .manipulatingFirstPiece(let rType, let rRot, let rFlip)):
                return lType == rType && lRot == rRot && lFlip == rFlip
            case (.selectingCanvasConnections(let lMax), .selectingCanvasConnections(let rMax)):
                return lMax == rMax
            case (.selectingPendingConnections(let lType, let lMax), 
                  .selectingPendingConnections(let rType, let rMax)):
                return lType == rType && lMax == rMax
            case (.manipulatingPendingPiece(let lType, let lMode, let lRot), 
                  .manipulatingPendingPiece(let rType, let rMode, let rRot)):
                return lType == rType && lMode == rMode && lRot == rRot
            case (.previewingPlacement(let lPiece), .previewingPlacement(let rPiece)):
                return lPiece == rPiece
            case (.pieceSelected(let lId, let lLocked), .pieceSelected(let rId, let rLocked)):
                return lId == rId && lLocked == rLocked
            case (.unlockingPiece(let lId), .unlockingPiece(let rId)):
                return lId == rId
            case (.manipulatingExistingPiece(let lId, let lMode), 
                  .manipulatingExistingPiece(let rId, let rMode)):
                return lId == rId && lMode == rMode
            case (.error(let lMsg), .error(let rMsg)):
                return lMsg == rMsg
            default:
                return false
            }
        }
    }
}

// MARK: - Extension for PlacementError

extension TangramEditorCoordinator.PlacementError {
    var localizedDescription: String {
        switch self {
        case .invalidConnections:
            return "Invalid connection points selected"
        case .placementCalculationFailed:
            return "Could not calculate piece placement"
        case .overlappingPieces:
            return "Piece would overlap with existing pieces"
        case .validationFailed:
            return "Placement validation failed"
        }
    }
}