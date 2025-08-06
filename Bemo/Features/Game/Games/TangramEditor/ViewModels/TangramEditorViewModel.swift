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
    
    // MARK: - Manipulation Mode
    enum ManipulationMode: Equatable {
        case locked                                             // 2+ connections - no movement allowed
        case rotatable(pivot: CGPoint, snapAngles: [Double])   // 1 vertex connection - can rotate
        case slidable(edge: Edge, range: ClosedRange<Double>, snapPositions: [Double])  // 1 edge connection - can slide
        
        struct Edge: Equatable {
            let start: CGPoint
            let end: CGPoint
            let vector: CGVector  // Normalized direction vector
        }
    }
    
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
    
    // MARK: - Initialization
    
    init(puzzle: TangramPuzzle? = nil,
         coordinator: TangramEditorCoordinator,
         placementService: PiecePlacementService,
         persistenceService: PuzzlePersistenceService,
         undoManager: UndoRedoManager,
         validationService: ValidationService) {
        
        // Initialize services (now required, no defaults)
        self.coordinator = coordinator
        self.placementService = placementService
        self.persistenceService = persistenceService
        self.undoManager = undoManager
        self.validationService = validationService
        
        // Initialize puzzle
        self.puzzle = puzzle ?? TangramPuzzle(name: "New Puzzle")
        
        // Load saved puzzles on init
        Task { [weak self] in
            await self?.loadSavedPuzzles()
        }
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: TangramEditorError) {
        currentError = error
        uiState.showError(error.userMessage)
        
        // Log error for debugging (in production this could go to error tracking)
        print("[TangramEditor] Error: \(error.errorDescription ?? "Unknown error")")
    }
    
    func dismissError() {
        uiState.dismissError()
        currentError = nil
    }
    
    // MARK: - UI Actions
    
    func startAddingPiece(type: PieceType) {
        guard !isPieceTypeAlreadyPlaced(type) else { return }
        
        pendingPieceType = type
        pendingPieceRotation = 0
        selectedCanvasPoints.removeAll()
        selectedPendingPoints.removeAll()
        
        if puzzle.pieces.isEmpty {
            editorState = .pendingFirstPiece(type: type, rotation: 0)
        } else {
            // For subsequent pieces, show connection points on existing pieces
            updateAvailableConnectionPoints()
            editorState = .selectingCanvasPoints
        }
    }
    
    func confirmPendingPiece(canvasSize: CGSize? = nil) {
        undoManager.saveState(puzzle: puzzle)
        
        let size = canvasSize ?? currentCanvasSize
        
        switch editorState {
        case .pendingFirstPiece(let type, let rotation):
            // Place first piece at center (convert degrees to radians)
            let piece = placementService.placeFirstPiece(
                type: type,
                rotation: rotation * .pi / 180,
                canvasSize: size
            )
            puzzle.pieces.append(piece)
            editorState = .idle
            clearSelectionState()
            updateManipulationModes()  // Update manipulation modes after adding piece
            validate()
            notifyPuzzleChanged()
            
        case .pendingSubsequentPiece(let type, let rotation):
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
            case .success(let newPiece):
                editorState = .idle
                clearSelectionState()
                updateManipulationModes()  // Update manipulation modes after adding piece
                
                // TODO: Fix recentering - pieces going off screen
                // recenterPuzzle()  // Temporarily disabled
                
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
                // Don't change editor state to error - keep current state
            }
            
        default:
            break
        }
        
        validate()
        notifyPuzzleChanged()
    }
    
    func cancelPendingPiece() {
        editorState = .idle
        clearSelectionState()
    }
    
    func rotatePendingPiece(by degrees: Double) {
        pendingPieceRotation += degrees
        
        // Update the rotation in the current state
        switch editorState {
        case .pendingFirstPiece(let type, _):
            editorState = .pendingFirstPiece(type: type, rotation: pendingPieceRotation)
        case .pendingSubsequentPiece(let type, _):
            editorState = .pendingSubsequentPiece(type: type, rotation: pendingPieceRotation)
        default:
            break
        }
        
        updatePreviewIfNeeded()
    }
    
    func flipPendingPiece() {
        // Only parallelogram can flip
        pendingPieceRotation = -pendingPieceRotation
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
            // Get the pending piece type from the current state
            switch editorState {
            case .selectingCanvasPoints:
                // We don't have the type here, need to track it separately
                break
            case .pendingFirstPiece(let type, let rotation):
                editorState = .pendingSubsequentPiece(type: type, rotation: rotation)
            default:
                break
            }
        }
    }
    
    func toggleCanvasPoint(_ point: ConnectionPoint) {
        if let index = selectedCanvasPoints.firstIndex(where: { $0.id == point.id }) {
            selectedCanvasPoints.remove(at: index)
        } else {
            selectedCanvasPoints.append(point)
        }
        
        // Don't immediately show pending piece - wait for user to explicitly proceed
        // This allows selecting multiple canvas points first
    }
    
    func proceedToPendingPiece() {
        // Transition to pending piece state after canvas points are selected
        if !selectedCanvasPoints.isEmpty, let type = pendingPieceType {
            editorState = .pendingSubsequentPiece(type: type, rotation: pendingPieceRotation)
        }
    }
    
    // MARK: - Selection Management
    
    func selectPiece(id: String) {
        if uiState.editMode == .select {
            selectedPieceIds.insert(id)
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
    
    // MARK: - Piece Operations
    
    func removePiece(id: String) {
        undoManager.saveState(puzzle: puzzle)
        puzzle.pieces.removeAll { $0.id == id }
        puzzle.connections.removeAll { $0.involvesPiece(id) }
        validate()
        notifyPuzzleChanged()
    }
    
    func removeSelectedPieces() {
        undoManager.saveState(puzzle: puzzle)
        let idsToRemove = selectedPieceIds
        puzzle.pieces.removeAll { idsToRemove.contains($0.id) }
        puzzle.connections.removeAll { connection in
            idsToRemove.contains { connection.involvesPiece($0) }
        }
        selectedPieceIds.removeAll()
        validate()
        notifyPuzzleChanged()
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
        editorState = .idle
        selectedPieceIds.removeAll()
        validate()
        notifyPuzzleChanged()
        uiState.navigationState = .editor
    }
    
    func createNewPuzzle() {
        reset()
        puzzle = TangramPuzzle(name: "New Puzzle", category: .custom, difficulty: .medium)
        editorState = .idle
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
        editorState = .idle
        clearSelectionState()
        undoManager.clearHistory()
    }
    
    func clearPuzzle() {
        undoManager.saveState(puzzle: puzzle)
        puzzle.pieces.removeAll()
        puzzle.connections.removeAll()
        selectedPieceIds.removeAll()
        validationState = .unknown
        editorState = .idle
        clearSelectionState()
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
        
        // Find connections involving this piece
        let pieceConnections = puzzle.connections.filter { connection in
            connection.pieceAId == pieceId || connection.pieceBId == pieceId
        }
        
        // Multiple connections = locked
        if pieceConnections.count >= 2 {
            return .locked
        }
        
        // Single connection - determine type
        if let connection = pieceConnections.first {
            switch connection.type {
            case .vertexToVertex(let pieceAId, let vertexA, let pieceBId, let vertexB):
                // Get the pivot point (vertex in world space)
                let isPieceA = pieceId == pieceAId
                let vertexIndex = isPieceA ? vertexA : vertexB
                let worldVertices = TangramCoordinateSystem.getWorldVertices(for: piece)
                
                guard vertexIndex < worldVertices.count else {
                    return .locked
                }
                
                let pivot = worldVertices[vertexIndex]
                // Snap at 45° intervals
                let snapAngles = [0, 45, 90, 135, 180, 225, 270, 315].map { Double($0) }
                
                return .rotatable(pivot: pivot, snapAngles: snapAngles)
                
            case .edgeToEdge(let pieceAId, let edgeA, let pieceBId, let edgeB):
                // Determine which piece is sliding and which is stationary
                let isPieceA = pieceId == pieceAId
                
                // Get the stationary piece (the one we're sliding along)
                guard let stationaryPiece = puzzle.pieces.first(where: { 
                    $0.id == (isPieceA ? pieceBId : pieceAId) 
                }) else {
                    return .locked
                }
                
                // Get edge info for the STATIONARY piece (the track we slide along)
                let stationaryWorldVertices = TangramCoordinateSystem.getWorldVertices(for: stationaryPiece)
                let stationaryEdges = TangramGeometry.edges(for: stationaryPiece.type)
                let stationaryEdgeIndex = isPieceA ? edgeB : edgeA
                
                guard stationaryEdgeIndex < stationaryEdges.count else {
                    return .locked
                }
                
                let stationaryEdgeDef = stationaryEdges[stationaryEdgeIndex]
                let stationaryEdgeStart = stationaryWorldVertices[stationaryEdgeDef.startVertex]
                let stationaryEdgeEnd = stationaryWorldVertices[stationaryEdgeDef.endVertex]
                
                // Calculate the stationary edge vector (this is our sliding track)
                let dx = stationaryEdgeEnd.x - stationaryEdgeStart.x
                let dy = stationaryEdgeEnd.y - stationaryEdgeStart.y
                let stationaryEdgeLength = sqrt(dx * dx + dy * dy)
                let normalizedVector = CGVector(dx: dx / stationaryEdgeLength, dy: dy / stationaryEdgeLength)
                
                // Get the sliding piece's edge length
                let slidingEdges = TangramGeometry.edges(for: piece.type)
                let slidingEdgeIndex = isPieceA ? edgeA : edgeB
                guard slidingEdgeIndex < slidingEdges.count else {
                    return .locked
                }
                
                let slidingEdgeLength = slidingEdges[slidingEdgeIndex].length * TangramConstants.visualScale
                
                // The sliding range is the stationary edge length minus the sliding edge length
                // This allows the sliding piece to move from one end to the other
                let slideRange = max(0, stationaryEdgeLength - slidingEdgeLength)
                
                // Snap at 0%, 50%, 100% of the range
                let snapPositions = [0.0, 0.5, 1.0]
                
                return .slidable(
                    edge: ManipulationMode.Edge(
                        start: stationaryEdgeStart,
                        end: stationaryEdgeEnd,
                        vector: normalizedVector
                    ),
                    range: 0...slideRange,
                    snapPositions: snapPositions
                )
                
            case .vertexToEdge:
                // Vertex on edge - for now, lock it
                // Could potentially allow sliding along the edge
                return .locked
            }
        }
        
        // No connections - shouldn't happen for placed pieces
        return .locked
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
        case pendingFirstPiece(type: PieceType, rotation: Double)
        case selectingCanvasPoints
        case pendingSubsequentPiece(type: PieceType, rotation: Double)
        case previewingPlacement(piece: TangramPiece, connections: [(ConnectionPoint, ConnectionPoint)])
        case error(String)
        
        static func == (lhs: EditorState, rhs: EditorState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle):
                return true
            case (.pendingFirstPiece(let lType, let lRot), .pendingFirstPiece(let rType, let rRot)):
                return lType == rType && lRot == rRot
            case (.selectingCanvasPoints, .selectingCanvasPoints):
                return true
            case (.pendingSubsequentPiece(let lType, let lRot), .pendingSubsequentPiece(let rType, let rRot)):
                return lType == rType && lRot == rRot
            case (.previewingPlacement(let lPiece, let lConn), .previewingPlacement(let rPiece, let rConn)):
                // Compare arrays of tuples element by element
                guard lPiece == rPiece && lConn.count == rConn.count else { return false }
                for (index, lConnection) in lConn.enumerated() {
                    let rConnection = rConn[index]
                    if lConnection.0 != rConnection.0 || lConnection.1 != rConnection.1 {
                        return false
                    }
                }
                return true
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