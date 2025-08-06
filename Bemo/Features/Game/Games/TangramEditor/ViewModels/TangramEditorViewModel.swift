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
    
    // MARK: - UI State (Observable)
    
    var puzzle: TangramPuzzle
    var savedPuzzles: [TangramPuzzle] = []
    var selectedPieceIds: Set<String> = []
    var validationState: ValidationState = .unknown
    var editMode: EditMode = .select
    var editorState: EditorState = .idle
    var navigationState: NavigationState = .library
    
    // UI-specific state
    var selectedCanvasPoints: [ConnectionPoint] = []
    var selectedPendingPoints: [ConnectionPoint] = []
    var availableConnectionPoints: [ConnectionPoint] = []
    var pendingPieceRotation: Double = 0
    var pendingPieceType: PieceType? = nil  // Track the piece type being added
    var previewTransform: CGAffineTransform?
    var previewPiece: TangramPiece?
    private var cachedPendingPiece: TangramPiece? = nil  // Cache to maintain consistent IDs
    var currentCanvasSize: CGSize = CGSize(width: 800, height: 800)
    var showSettings = false
    var showSaveDialog = false
    
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
         coordinator: TangramEditorCoordinator? = nil,
         placementService: PiecePlacementService? = nil,
         persistenceService: PuzzlePersistenceService? = nil,
         undoManager: UndoRedoManager? = nil,
         validationService: ValidationService? = nil) {
        
        // Initialize services with defaults if not provided
        self.coordinator = coordinator ?? TangramEditorCoordinator()
        self.placementService = placementService ?? PiecePlacementService()
        self.persistenceService = persistenceService ?? PuzzlePersistenceService()
        self.undoManager = undoManager ?? UndoRedoManager()
        self.validationService = validationService ?? ValidationService()
        
        // Initialize puzzle
        self.puzzle = puzzle ?? TangramPuzzle(name: "New Puzzle")
        
        // Load saved puzzles on init
        Task {
            await loadSavedPuzzles()
        }
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
            print("DEBUG: Added first piece at transform: \(piece.transform)")
            print("DEBUG: Total pieces now: \(puzzle.pieces.count)")
            editorState = .idle
            clearSelectionState()
            validate()
            notifyPuzzleChanged()
            
        case .pendingSubsequentPiece(let type, let rotation):
            // Place connected piece (convert degrees to radians)
            print("DEBUG: About to place connected piece of type \(type)")
            print("DEBUG: Current piece count: \(puzzle.pieces.count)")
            print("DEBUG: Selected canvas points: \(selectedCanvasPoints)")
            print("DEBUG: Selected pending points: \(selectedPendingPoints)")
            
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
                print("DEBUG: Successfully placed piece with transform: \(newPiece.transform)")
                print("DEBUG: Total pieces after placement: \(puzzle.pieces.count)")
                editorState = .idle
                clearSelectionState()
                
                // Print all piece transforms before recentering
                print("DEBUG: Piece transforms before recentering:")
                for (index, piece) in puzzle.pieces.enumerated() {
                    print("DEBUG: Piece \(index) (\(piece.type)): \(piece.transform)")
                }
                
                // TODO: Fix recentering - pieces going off screen
                // recenterPuzzle()  // Temporarily disabled
                
                // Print all piece transforms after recentering
                print("DEBUG: Piece transforms after recentering:")
                for (index, piece) in puzzle.pieces.enumerated() {
                    print("DEBUG: Piece \(index) (\(piece.type)): \(piece.transform)")
                }
                
            case .failure(let error):
                print("DEBUG: Failed to place piece: \(error)")
                editorState = .error(error.localizedDescription)
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
        if editMode == .select {
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
        puzzle.connections.removeAll { $0.involvespiece(id) }
        validate()
        notifyPuzzleChanged()
    }
    
    func removeSelectedPieces() {
        undoManager.saveState(puzzle: puzzle)
        let idsToRemove = selectedPieceIds
        puzzle.pieces.removeAll { idsToRemove.contains($0.id) }
        puzzle.connections.removeAll { connection in
            idsToRemove.contains { connection.involvespiece($0) }
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
        navigationState = .editor
    }
    
    func createNewPuzzle() {
        reset()
        puzzle = TangramPuzzle(name: "New Puzzle", category: .custom, difficulty: .medium)
        editorState = .idle
        navigationState = .editor
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
        editMode = .select
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
            print("DEBUG: recenterPuzzle called but no pieces exist")
            return 
        }
        
        // Don't recenter if canvas size is not properly set
        guard currentCanvasSize.width > 0 && currentCanvasSize.height > 0 else {
            print("DEBUG: recenterPuzzle called but canvas size invalid: \(currentCanvasSize)")
            return
        }
        
        print("DEBUG: recenterPuzzle starting with \(puzzle.pieces.count) pieces")
        print("DEBUG: currentCanvasSize: \(currentCanvasSize)")
        
        // Calculate the bounding box of all pieces
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        
        for (index, piece) in puzzle.pieces.enumerated() {
            let vertices = TangramGeometry.vertices(for: piece.type)
            // Scale vertices to match what PieceShape creates
            let scaledVertices = vertices.map { 
                CGPoint(x: $0.x * TangramConstants.visualScale, 
                        y: $0.y * TangramConstants.visualScale)
            }
            // Apply the transform to get final screen positions
            let transformed = scaledVertices.map { $0.applying(piece.transform) }
            
            print("DEBUG: Piece \(index) vertices: \(vertices)")
            print("DEBUG: Piece \(index) transform: \(piece.transform)")
            print("DEBUG: Piece \(index) transformed vertices: \(transformed)")
            
            for vertex in transformed {
                minX = min(minX, vertex.x)
                maxX = max(maxX, vertex.x)
                minY = min(minY, vertex.y)
                maxY = max(maxY, vertex.y)
            }
        }
        
        print("DEBUG: Bounding box - minX: \(minX), maxX: \(maxX), minY: \(minY), maxY: \(maxY)")
        
        // Calculate center offset
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        let targetX = currentCanvasSize.width / 2
        let targetY = currentCanvasSize.height / 2
        let dx = targetX - centerX
        let dy = targetY - centerY
        
        print("DEBUG: Current center: (\(centerX), \(centerY))")
        print("DEBUG: Target center: (\(targetX), \(targetY))")
        print("DEBUG: Translation needed: dx=\(dx), dy=\(dy)")
        
        // Check for NaN or infinite values
        if !dx.isFinite || !dy.isFinite {
            print("DEBUG: ERROR - dx or dy is not finite! dx=\(dx), dy=\(dy)")
            return
        }
        
        // Apply translation to all pieces
        undoManager.saveState(puzzle: puzzle)
        for i in 0..<puzzle.pieces.count {
            let oldTransform = puzzle.pieces[i].transform
            // CRITICAL: Don't use translatedBy - it applies in rotated space!
            // Instead, directly modify tx and ty for world-space translation
            var newTransform = puzzle.pieces[i].transform
            newTransform.tx += dx
            newTransform.ty += dy
            puzzle.pieces[i].transform = newTransform
            print("DEBUG: Updated piece \(i) transform from \(oldTransform) to \(puzzle.pieces[i].transform)")
        }
        
        print("DEBUG: recenterPuzzle completed")
        notifyPuzzleChanged()
    }
    
    func getConnectionPoints(for pieceId: String) -> [ConnectionPoint] {
        guard let piece = puzzle.pieces.first(where: { $0.id == pieceId }) else {
            return []
        }
        return placementService.getConnectionPoints(for: piece)
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
        selectedCanvasPoints.removeAll()
        selectedPendingPoints.removeAll()
        availableConnectionPoints.removeAll()
        previewTransform = nil
        previewPiece = nil
        cachedPendingPiece = nil  // Clear cached piece
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
    
    enum NavigationState {
        case library
        case editor
    }
    
    enum EditMode {
        case select
        case move
        case rotate
    }
    
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