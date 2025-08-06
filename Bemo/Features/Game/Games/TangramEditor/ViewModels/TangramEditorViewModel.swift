//
//  TangramEditorViewModel.swift
//  Bemo
//
//  Main view model for the tangram editor, orchestrating all services
//

import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
class TangramEditorViewModel {
    
    // MARK: - Observable Properties
    
    var puzzle: TangramPuzzle
    var selectedPieceIds: Set<String> = []  // Changed to support multiple selection
    var validationState: ValidationState = .unknown
    var editMode: EditMode = .select
    var editorState: EditorState = .idle
    
    // Piece placement properties
    var selectedCanvasPoints: [ConnectionPoint] = []  // Points selected on canvas pieces
    var selectedPendingPoints: [ConnectionPoint] = []  // Points selected on pending piece
    var availableConnectionPoints: [ConnectionPoint] = []  // All available points
    var pendingPieceRotation: Double = 0  // Rotation for pending piece
    var previewTransform: CGAffineTransform?  // Transform for preview
    var previewPiece: TangramPiece?  // Preview piece for placement
    var currentCanvasSize: CGSize = CGSize(width: 800, height: 800)  // Track canvas size
    var showSettings = false
    var showSaveDialog = false
    
    // Game delegate for communication with host
    weak var delegate: GameDelegate?
    
    // MARK: - Services
    
    private let connectionService: ConnectionService
    private let validationService: ValidationService
    private let persistenceService: PuzzlePersistenceService
    private let constraintManager = ConstraintManager()
    
    // MARK: - Types
    
    enum EditMode {
        case select
        case move
        case rotate
    }
    
    enum EditorState: Equatable {
        case idle
        case pendingFirstPiece(type: PieceType, rotation: Double)  // First piece being configured
        case selectingCanvasPoints  // Selecting connection points on existing pieces
        case pendingSubsequentPiece(type: PieceType, rotation: Double)  // Subsequent piece being configured
        case previewingPlacement(piece: TangramPiece, connections: [(canvasPoint: ConnectionPoint, piecePoint: ConnectionPoint)])  // Preview before placement
        case error(String)
        
        static func == (lhs: EditorState, rhs: EditorState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle):
                return true
            case (.selectingCanvasPoints, .selectingCanvasPoints):
                return true
            case let (.pendingFirstPiece(type1, rot1), .pendingFirstPiece(type2, rot2)):
                return type1 == type2 && rot1 == rot2
            case let (.pendingSubsequentPiece(type1, rot1), .pendingSubsequentPiece(type2, rot2)):
                return type1 == type2 && rot1 == rot2
            case let (.error(msg1), .error(msg2)):
                return msg1 == msg2
            case let (.previewingPlacement(piece1, conn1), .previewingPlacement(piece2, conn2)):
                return piece1.id == piece2.id && conn1.count == conn2.count
            default:
                return false
            }
        }
    }
    
    struct ConnectionPoint: Equatable, Hashable {
        enum PointType: Equatable, Hashable {
            case vertex(index: Int)
            case edge(index: Int)
        }
        let type: PointType
        let position: CGPoint
        let pieceId: String
        
        var id: String {
            switch type {
            case .vertex(let index):
                return "\(pieceId)_v\(index)"
            case .edge(let index):
                return "\(pieceId)_e\(index)"
            }
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    
    
    enum ValidationState {
        case unknown
        case valid
        case invalid([String])
        
        var isValid: Bool {
            if case .valid = self { return true }
            return false
        }
        
        var errors: [String] {
            if case .invalid(let errors) = self { return errors }
            return []
        }
    }
    
    // MARK: - UI State Methods
    
    func toggleSettings() {
        showSettings.toggle()
    }
    
    func requestSave() {
        showSaveDialog = true
    }
    
    // MARK: - Initialization
    
    init(puzzle: TangramPuzzle? = nil) {
        self.puzzle = puzzle ?? TangramPuzzle(name: "New Puzzle")
        self.connectionService = ConnectionService()
        self.validationService = ValidationService()
        self.persistenceService = PuzzlePersistenceService()
    }
    
    // MARK: - Piece Management
    
    func startAddingPiece(type: PieceType) {
        // Check if this piece type has already been placed
        if isPieceTypeAlreadyPlaced(type) {
            editorState = .error("\(type.displayName) has already been placed")
            return
        }
        
        if puzzle.pieces.isEmpty {
            // First piece - show in pending view
            editorState = .pendingFirstPiece(type: type, rotation: 0)
            pendingPieceRotation = 0
        } else {
            // Subsequent pieces - first need to select connection points on canvas
            if selectedCanvasPoints.isEmpty {
                // Show all connection points for selection
                editorState = .selectingCanvasPoints
                availableConnectionPoints = getAllCanvasConnectionPoints()
            } else {
                // Canvas points already selected, show pending piece
                editorState = .pendingSubsequentPiece(type: type, rotation: 0)
                pendingPieceRotation = 0
            }
        }
    }
    
    private func isPieceTypeAlreadyPlaced(_ type: PieceType) -> Bool {
        return puzzle.pieces.contains { $0.type == type }
    }
    
    func rotatePendingPiece(by angle: Double) {
        pendingPieceRotation += angle
        
        // Update state with new rotation
        switch editorState {
        case .pendingFirstPiece(let type, _):
            editorState = .pendingFirstPiece(type: type, rotation: pendingPieceRotation)
        case .pendingSubsequentPiece(let type, _):
            editorState = .pendingSubsequentPiece(type: type, rotation: pendingPieceRotation)
            updatePreview()
        default:
            break
        }
    }
    
    func flipPendingPiece() {
        // Only flip parallelogram - flip is a 180 degree rotation around X axis
        // In 2D this is represented as scaling Y by -1
        // For simplicity, we'll rotate by 180 degrees
        rotatePendingPiece(by: Double.pi)
    }
    
    func confirmPendingPiece(canvasSize: CGSize? = nil) {
        // Update canvas size if provided
        if let size = canvasSize {
            currentCanvasSize = size
        }
        
        switch editorState {
        case .pendingFirstPiece(let type, let rotation):
            // Place first piece at true center with rotation
            let canvasCenter = CGPoint(x: currentCanvasSize.width / 2, y: currentCanvasSize.height / 2)
            var transform = CGAffineTransform(translationX: canvasCenter.x, y: canvasCenter.y)
            transform = transform.rotated(by: rotation)
            let piece = TangramPiece(type: type, transform: transform)
            puzzle.pieces.append(piece)
            validate()
            
            // Reset state
            editorState = .idle
            pendingPieceRotation = 0
            
        case .pendingSubsequentPiece(let type, let rotation):
            // Place piece with connections
            if !selectedCanvasPoints.isEmpty && !selectedPendingPoints.isEmpty {
                placePieceWithConnections(type: type, rotation: rotation)
            }
            
        default:
            break
        }
    }
    
    func cancelPendingPiece() {
        editorState = .idle
        pendingPieceRotation = 0
        selectedPendingPoints.removeAll()
        previewTransform = nil
    }
    
    func toggleCanvasPoint(_ point: ConnectionPoint) {
        if let index = selectedCanvasPoints.firstIndex(where: { $0.id == point.id }) {
            // Deselect
            selectedCanvasPoints.remove(at: index)
        } else {
            // Select (max 2 points)
            if selectedCanvasPoints.count < 2 {
                selectedCanvasPoints.append(point)
            }
        }
    }
    
    func togglePendingPoint(_ point: ConnectionPoint) {
        if let index = selectedPendingPoints.firstIndex(where: { $0.id == point.id }) {
            // Deselect
            selectedPendingPoints.remove(at: index)
        } else {
            // Only select if we have matching type with canvas points
            if canSelectPendingPoint(point) {
                selectedPendingPoints.append(point)
                updatePreview()
            }
        }
    }
    
    private func canSelectPendingPoint(_ point: ConnectionPoint) -> Bool {
        // Check if point type matches selected canvas points
        for canvasPoint in selectedCanvasPoints {
            if arePointTypesCompatible(point.type, canvasPoint.type) {
                return selectedPendingPoints.count < selectedCanvasPoints.count
            }
        }
        return false
    }
    
    private func placePieceWithConnections(type: PieceType, rotation: Double) {
        guard !selectedCanvasPoints.isEmpty && !selectedPendingPoints.isEmpty else { return }
        
        // Calculate transform based on connection points
        let transform = calculatePlacementTransform(
            pieceType: type,
            rotation: rotation,
            canvasPoints: selectedCanvasPoints,
            pendingPoints: selectedPendingPoints
        )
        
        // Create the piece
        let piece = TangramPiece(type: type, transform: transform)
        puzzle.pieces.append(piece)
        
        // Create connections
        for (canvasPoint, pendingPoint) in zip(selectedCanvasPoints, selectedPendingPoints) {
            let connectionType = createConnectionType(
                pieceA: canvasPoint.pieceId,
                pointA: canvasPoint,
                pieceB: piece.id,
                pointB: pendingPoint
            )
            
            if let connection = connectionService.createConnection(
                type: connectionType,
                pieces: puzzle.pieces
            ) {
                puzzle.connections.append(connection)
            }
        }
        
        // Reset state
        editorState = .idle
        selectedCanvasPoints.removeAll()
        selectedPendingPoints.removeAll()
        pendingPieceRotation = 0
        previewTransform = nil
        availableConnectionPoints.removeAll()
        
        // Auto-recenter after placement with correct canvas size
        recenterPuzzle(canvasSize: currentCanvasSize)
        
        validate()
    }
    
    private func updatePreview() {
        guard case .pendingSubsequentPiece(let type, let rotation) = editorState else {
            previewTransform = nil
            return
        }
        
        // Only show preview if we have matching points
        guard !selectedPendingPoints.isEmpty && selectedPendingPoints.count == selectedCanvasPoints.count else {
            previewTransform = nil
            return
        }
        
        // Calculate preview transform
        previewTransform = calculatePlacementTransform(
            pieceType: type,
            rotation: rotation,
            canvasPoints: selectedCanvasPoints,
            pendingPoints: selectedPendingPoints
        )
    }
    
    private func calculatePlacementTransform(
        pieceType: PieceType,
        rotation: Double,
        canvasPoints: [ConnectionPoint],
        pendingPoints: [ConnectionPoint]
    ) -> CGAffineTransform {
        guard let firstCanvasPoint = canvasPoints.first,
              let firstPendingPoint = pendingPoints.first else {
            return CGAffineTransform.identity
        }
        
        // Get base vertices for the pending piece
        let baseVertices = TangramGeometry.vertices(for: pieceType)
        let scaledVertices = baseVertices.map { CGPoint(x: $0.x * 50, y: $0.y * 50) }
        
        // Apply rotation first
        var transform = CGAffineTransform(rotationAngle: rotation)
        
        // Get the position of the pending point after rotation
        let pendingPos: CGPoint
        switch firstPendingPoint.type {
        case .vertex(let index):
            pendingPos = scaledVertices[index].applying(transform)
        case .edge(let index):
            let edges = TangramGeometry.edges(for: pieceType)
            let edge = edges[index]
            let start = scaledVertices[edge.startVertex].applying(transform)
            let end = scaledVertices[edge.endVertex].applying(transform)
            pendingPos = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        }
        
        // Calculate translation to align points
        let dx = firstCanvasPoint.position.x - pendingPos.x
        let dy = firstCanvasPoint.position.y - pendingPos.y
        
        // Apply translation
        transform = transform.concatenating(CGAffineTransform(translationX: dx, y: dy))
        
        return transform
    }
    
    
    func removePiece(id: String) {
        puzzle.pieces.removeAll { $0.id == id }
        puzzle.connections.removeAll { $0.pieceAId == id || $0.pieceBId == id }
        selectedPieceIds.remove(id)
        validate()
    }
    
    func updatePieceTransform(id: String, transform: CGAffineTransform) {
        guard let index = puzzle.pieces.firstIndex(where: { $0.id == id }) else { return }
        
        puzzle.pieces[index].transform = transform
        validate()
    }
    
    func rotatePiece(id: String, by angle: Double) {
        guard let index = puzzle.pieces.firstIndex(where: { $0.id == id }) else { return }
        
        var transform = puzzle.pieces[index].transform
        transform = transform.rotated(by: angle)
        
        puzzle.pieces[index].transform = transform
        validate()
    }
    
    func selectPiece(id: String) {
        // Toggle selection
        if selectedPieceIds.contains(id) {
            selectedPieceIds.remove(id)
        } else {
            selectedPieceIds.insert(id)
        }
    }
    
    func selectAllPieces() {
        selectedPieceIds = Set(puzzle.pieces.map { $0.id })
    }
    
    func clearSelection() {
        selectedPieceIds.removeAll()
    }
    
    func removeSelectedPieces() {
        // Remove pieces and their connections
        puzzle.pieces.removeAll { selectedPieceIds.contains($0.id) }
        puzzle.connections.removeAll { connection in
            selectedPieceIds.contains(connection.pieceAId) || selectedPieceIds.contains(connection.pieceBId)
        }
        
        // Clear selection
        selectedPieceIds.removeAll()
        
        // Revalidate
        validate()
    }
    
    // MARK: - Connection Management
    
    func removeConnection(id: String) {
        puzzle.connections.removeAll { $0.id == id }
        validate()
    }
    
    func getConnectionsBetween(pieceA: String, pieceB: String) -> Connection? {
        return connectionService.connectionBetween(pieceA, pieceB, connections: puzzle.connections)
    }
    
    // MARK: - Validation
    
    func validate() {
        // Skip validation if no pieces
        guard !puzzle.pieces.isEmpty else {
            validationState = .unknown
            return
        }
        
        let hasAreaOverlaps = validationService.hasInvalidAreaOverlaps(pieces: puzzle.pieces)
        let hasUnexplainedContacts = validationService.hasUnexplainedContacts(
            pieces: puzzle.pieces,
            connections: puzzle.connections
        )
        let isConnected = validationService.isConnected(
            pieces: puzzle.pieces,
            connections: puzzle.connections
        )
        
        var errors: [String] = []
        
        // Priority order for errors
        if !isConnected && puzzle.pieces.count > 1 {
            errors.append("Orphaned pieces - not all connected")
        }
        
        if hasAreaOverlaps {
            errors.append("Pieces overlapping")
        }
        
        if hasUnexplainedContacts {
            errors.append("Pieces touching without connection")
        }
        
        validationState = errors.isEmpty ? .valid : .invalid(errors)
    }
    
    // MARK: - Geometric Queries
    
    func getTransformedVertices(for pieceId: String) -> [CGPoint]? {
        guard let piece = puzzle.pieces.first(where: { $0.id == pieceId }) else { return nil }
        let baseVertices = TangramGeometry.vertices(for: piece.type)
        return GeometryEngine.transformVertices(baseVertices, with: piece.transform)
    }
    
    func getPieceBounds(for pieceId: String) -> CGRect? {
        guard let vertices = getTransformedVertices(for: pieceId) else { return nil }
        return GeometryEngine.boundingBox(for: vertices)
    }
    
    func getPieceCentroid(for pieceId: String) -> CGPoint? {
        guard let piece = puzzle.pieces.first(where: { $0.id == pieceId }) else { return nil }
        let baseCentroid = TangramGeometry.centroid(for: piece.type)
        return baseCentroid.applying(piece.transform)
    }
    
    // MARK: - Persistence
    
    func save() async throws {
        puzzle.modifiedDate = Date()
        puzzle.solutionChecksum = generateChecksum()
        try await persistenceService.savePuzzle(puzzle)
    }
    
    func load(puzzleId: String) async throws {
        puzzle = try await persistenceService.loadPuzzle(id: puzzleId)
        validate()
    }
    
    func deletePuzzle() async throws {
        try await persistenceService.deletePuzzle(id: puzzle.id)
        reset()
    }
    
    func listSavedPuzzles() async throws -> [PuzzleMetadata] {
        return try await persistenceService.listPuzzles()
    }
    
    func exportForGameplay() -> SolvedTangramPuzzle? {
        guard validationState.isValid else { return nil }
        
        let solvedPieces = puzzle.pieces.map { piece in
            SolvedPiece(pieceType: piece.type, transform: piece.transform)
        }
        
        return SolvedTangramPuzzle(
            id: puzzle.id,
            name: puzzle.name,
            category: puzzle.category.rawValue,
            difficulty: puzzle.difficulty.displayName,
            solvedPieces: solvedPieces,
            checksum: generateChecksum()
        )
    }
    
    // MARK: - Helpers
    
    private func generateChecksum() -> String {
        // Simple checksum based on piece positions
        let positionString = puzzle.pieces.map { piece in
            "\(piece.type.rawValue):\(piece.transform.tx),\(piece.transform.ty)"
        }.sorted().joined()
        
        return String(positionString.hashValue)
    }
    
    // MARK: - Game Integration
    
    func reset() {
        puzzle = TangramPuzzle(name: "New Puzzle")
        selectedPieceIds.removeAll()
        validationState = .unknown
        editMode = .select
        editorState = .idle
        selectedCanvasPoints.removeAll()
        selectedPendingPoints.removeAll()
        availableConnectionPoints.removeAll()
        pendingPieceRotation = 0
        previewTransform = nil
    }
    
    func currentPuzzleData() -> TangramPuzzle {
        return puzzle
    }
    
    func loadPuzzle(from data: TangramPuzzle) {
        puzzle = data
        validate()
    }
    
    
    func recenterPuzzle(canvasSize: CGSize? = nil) {
        // Use provided size or stored size
        let size = canvasSize ?? currentCanvasSize
        guard !puzzle.pieces.isEmpty else { return }
        
        // Calculate the bounding box of all pieces
        var minX = Double.infinity
        var minY = Double.infinity
        var maxX = -Double.infinity
        var maxY = -Double.infinity
        
        for piece in puzzle.pieces {
            // Scale vertices by 50 to match visual representation
            let baseVertices = TangramGeometry.vertices(for: piece.type)
            let scaledVertices = baseVertices.map { CGPoint(x: $0.x * 50, y: $0.y * 50) }
            let vertices = GeometryEngine.transformVertices(scaledVertices, with: piece.transform)
            
            for vertex in vertices {
                minX = min(minX, vertex.x)
                minY = min(minY, vertex.y)
                maxX = max(maxX, vertex.x)
                maxY = max(maxY, vertex.y)
            }
        }
        
        // Calculate center of bounding box
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        
        // Target is the center of the canvas
        let targetX = size.width / 2
        let targetY = size.height / 2
        
        // Calculate translation needed
        let dx = targetX - centerX
        let dy = targetY - centerY
        
        // Apply translation to all pieces
        for i in puzzle.pieces.indices {
            puzzle.pieces[i].transform.tx += dx
            puzzle.pieces[i].transform.ty += dy
        }
    }
    
    func getConnectionPoints(for pieceId: String) -> [ConnectionPoint] {
        guard let piece = puzzle.pieces.first(where: { $0.id == pieceId }) else { return [] }
        
        var points: [ConnectionPoint] = []
        
        // Get base vertices and scale them by 50 (same as PieceShape does)
        let baseVertices = TangramGeometry.vertices(for: piece.type)
        let scaledVertices = baseVertices.map { vertex in
            CGPoint(x: vertex.x * 50, y: vertex.y * 50)
        }
        
        // Now apply the piece's transform to the scaled vertices
        let transformedVertices = GeometryEngine.transformVertices(scaledVertices, with: piece.transform)
        
        let edges = TangramGeometry.edges(for: piece.type)
        
        // Add vertex connection points
        for (index, vertex) in transformedVertices.enumerated() {
            points.append(ConnectionPoint(
                type: .vertex(index: index),
                position: vertex,
                pieceId: pieceId
            ))
        }
        
        // Add edge midpoint connection points
        for (index, edge) in edges.enumerated() {
            let start = transformedVertices[edge.startVertex]
            let end = transformedVertices[edge.endVertex]
            let midpoint = CGPoint(
                x: (start.x + end.x) / 2,
                y: (start.y + end.y) / 2
            )
            points.append(ConnectionPoint(
                type: .edge(index: index),
                position: midpoint,
                pieceId: pieceId
            ))
        }
        
        return points
    }
    
    
    // MARK: - Constraint-Aware Transformations
    
    func rotatePieceAroundVertex(pieceId: String, vertex: CGPoint, angle: Double) {
        guard let index = puzzle.pieces.firstIndex(where: { $0.id == pieceId }) else { return }
        let piece = puzzle.pieces[index]
        
        // Get constraints for this piece from connections
        let constraints = getConstraintsForPiece(pieceId)
        
        // Apply rotation
        var newTransform = piece.transform
        newTransform = constraintManager.rotateAroundPoint(newTransform, angle: angle, point: vertex)
        
        // Apply constraints
        newTransform = constraintManager.applyConstraints(newTransform, constraints: constraints)
        
        puzzle.pieces[index].transform = newTransform
        validate()
    }
    
    func slidePieceAlongEdge(pieceId: String, edgeVector: CGVector, distance: Double) {
        guard let index = puzzle.pieces.firstIndex(where: { $0.id == pieceId }) else { return }
        let piece = puzzle.pieces[index]
        
        // Get constraints for this piece
        let constraints = getConstraintsForPiece(pieceId)
        
        // Calculate new position along edge
        let normalizedVector = CGVector(
            dx: edgeVector.dx / sqrt(edgeVector.dx * edgeVector.dx + edgeVector.dy * edgeVector.dy),
            dy: edgeVector.dy / sqrt(edgeVector.dx * edgeVector.dx + edgeVector.dy * edgeVector.dy)
        )
        
        var newTransform = piece.transform
        newTransform.tx += normalizedVector.dx * distance
        newTransform.ty += normalizedVector.dy * distance
        
        // Apply constraints
        newTransform = constraintManager.applyConstraints(newTransform, constraints: constraints)
        
        puzzle.pieces[index].transform = newTransform
        validate()
    }
    
    func snapToValidPosition(pieceId: String) -> CGAffineTransform? {
        guard let piece = puzzle.pieces.first(where: { $0.id == pieceId }) else { return nil }
        
        let constraints = getConstraintsForPiece(pieceId)
        let snappedTransform = constraintManager.applyConstraints(piece.transform, constraints: constraints)
        
        return snappedTransform
    }
    
    private func getConstraintsForPiece(_ pieceId: String) -> [Constraint] {
        return puzzle.connections
            .filter { connection in
                connection.pieceAId == pieceId || connection.pieceBId == pieceId
            }
            .map { $0.constraint }
    }
    
    // MARK: - Pending Piece Helpers
    
    private func getAllCanvasConnectionPoints() -> [ConnectionPoint] {
        var allPoints: [ConnectionPoint] = []
        
        for piece in puzzle.pieces {
            let piecePoints = getConnectionPoints(for: piece.id)
            allPoints.append(contentsOf: piecePoints)
        }
        
        return allPoints
    }
    
    private func findCompatiblePoints(for point: ConnectionPoint) -> [ConnectionPoint] {
        var compatiblePoints: [ConnectionPoint] = []
        
        for piece in puzzle.pieces {
            let piecePoints = getConnectionPoints(for: piece.id)
            
            for canvasPoint in piecePoints {
                // Check if points are compatible (vertex-to-vertex or edge-to-edge)
                if arePointTypesCompatible(point.type, canvasPoint.type) {
                    compatiblePoints.append(canvasPoint)
                }
            }
        }
        
        return compatiblePoints
    }
    
    private func arePointTypesCompatible(_ type1: ConnectionPoint.PointType, _ type2: ConnectionPoint.PointType) -> Bool {
        switch (type1, type2) {
        case (.vertex, .vertex), (.edge, .edge):
            return true
        default:
            return false
        }
    }
    
    private func calculateConnectionTransform(
        newPieceType: PieceType,
        newPiecePoint: ConnectionPoint,
        existingPieceId: String,
        existingPoint: ConnectionPoint
    ) -> CGAffineTransform {
        
        guard let existingPiece = puzzle.pieces.first(where: { $0.id == existingPieceId }) else {
            return CGAffineTransform.identity
        }
        
        // Get the base vertices for both pieces
        let newPieceVertices = TangramGeometry.vertices(for: newPieceType)
        let existingVertices = GeometryEngine.transformVertices(
            TangramGeometry.vertices(for: existingPiece.type),
            with: existingPiece.transform
        )
        
        // Calculate the target position based on point types
        let targetPosition: CGPoint
        
        switch (newPiecePoint.type, existingPoint.type) {
        case let (.vertex(newIndex), .vertex(existingIndex)):
            // Align vertices
            targetPosition = existingVertices[existingIndex]
            let newVertex = newPieceVertices[newIndex]
            
            // Calculate transform to move newVertex to targetPosition
            let dx = targetPosition.x - newVertex.x
            let dy = targetPosition.y - newVertex.y
            return CGAffineTransform(translationX: dx, y: dy)
            
        case let (.edge(newEdgeIndex), .edge(existingEdgeIndex)):
            // Align edge midpoints
            let existingEdges = TangramGeometry.edges(for: existingPiece.type)
            let newEdges = TangramGeometry.edges(for: newPieceType)
            
            let existingEdge = existingEdges[existingEdgeIndex]
            let newEdge = newEdges[newEdgeIndex]
            
            let existingStart = existingVertices[existingEdge.startVertex]
            let existingEnd = existingVertices[existingEdge.endVertex]
            let existingMid = CGPoint(
                x: (existingStart.x + existingEnd.x) / 2,
                y: (existingStart.y + existingEnd.y) / 2
            )
            
            let newStart = newPieceVertices[newEdge.startVertex]
            let newEnd = newPieceVertices[newEdge.endVertex]
            let newMid = CGPoint(
                x: (newStart.x + newEnd.x) / 2,
                y: (newStart.y + newEnd.y) / 2
            )
            
            // Calculate transform to align midpoints
            let dx = existingMid.x - newMid.x
            let dy = existingMid.y - newMid.y
            return CGAffineTransform(translationX: dx, y: dy)
            
        default:
            return CGAffineTransform.identity
        }
    }
    
    private func createConnectionType(
        pieceA: String,
        pointA: ConnectionPoint,
        pieceB: String,
        pointB: ConnectionPoint
    ) -> ConnectionType {
        switch (pointA.type, pointB.type) {
        case let (.vertex(indexA), .vertex(indexB)):
            return .vertexToVertex(
                pieceA: pieceA,
                vertexA: indexA,
                pieceB: pieceB,
                vertexB: indexB
            )
        case let (.edge(indexA), .edge(indexB)):
            return .edgeToEdge(
                pieceA: pieceA,
                edgeA: indexA,
                pieceB: pieceB,
                edgeB: indexB
            )
        default:
            fatalError("Incompatible connection types")
        }
    }
    
    func getConnectionPointsForPendingPiece(type: PieceType, scale: CGFloat = 1) -> [ConnectionPoint] {
        var points: [ConnectionPoint] = []
        let vertices = TangramGeometry.vertices(for: type)
        let edges = TangramGeometry.edges(for: type)
        
        // Scale vertices for display
        let scaledVertices = vertices.map { CGPoint(x: $0.x * scale, y: $0.y * scale) }
        
        // Add vertices
        for (index, vertex) in scaledVertices.enumerated() {
            points.append(ConnectionPoint(
                type: .vertex(index: index),
                position: vertex,
                pieceId: "pending"  // Special ID for pending piece
            ))
        }
        
        // Add edges
        for (index, edge) in edges.enumerated() {
            let start = scaledVertices[edge.startVertex]
            let end = scaledVertices[edge.endVertex]
            let midpoint = CGPoint(
                x: (start.x + end.x) / 2,
                y: (start.y + end.y) / 2
            )
            points.append(ConnectionPoint(
                type: .edge(index: index),
                position: midpoint,
                pieceId: "pending"
            ))
        }
        
        return points
    }
    
    // MARK: - Selection Methods
    
    func togglePieceSelection(_ pieceId: String) {
        if selectedPieceIds.contains(pieceId) {
            selectedPieceIds.remove(pieceId)
        } else {
            selectedPieceIds.insert(pieceId)
        }
    }
    
    func clearPuzzle() {
        puzzle.pieces.removeAll()
        puzzle.connections.removeAll()
        selectedPieceIds.removeAll()
        editorState = .idle
        validate()
    }
    
    // MARK: - Undo/Redo
    
    // For now, undo/redo is not implemented
    var canUndo: Bool { false }
    var canRedo: Bool { false }
    
    func undo() {
        // TODO: Implement undo stack
    }
    
    func redo() {
        // TODO: Implement redo stack
    }
}