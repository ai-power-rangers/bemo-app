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
    var selectedPieceId: String?
    var anchorPieceId: String?
    var validationState: ValidationState = .unknown
    var editMode: EditMode = .select
    var connectionState: ConnectionCreationState = .idle
    var highlightedPoints: [ConnectionPoint] = []
    
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
        case connect
    }
    
    enum ConnectionCreationState {
        case idle
        case selectingFirstPiece
        case selectedFirstPiece(pieceId: String, point: ConnectionPoint?)
        case selectingSecondPiece(firstPieceId: String, firstPoint: ConnectionPoint)
        case readyToConnect(connection: PendingConnection)
        case error(String)
    }
    
    struct ConnectionPoint: Equatable {
        enum PointType: Equatable {
            case vertex(index: Int)
            case edge(index: Int)
        }
        let type: PointType
        let position: CGPoint
        let pieceId: String
    }
    
    struct PendingConnection {
        let pieceAId: String
        let pieceBId: String
        let pointA: ConnectionPoint
        let pointB: ConnectionPoint
        let connectionType: ConnectionType
        let possibleConstraints: [ConstraintType]
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
    
    // MARK: - Initialization
    
    init(puzzle: TangramPuzzle? = nil) {
        self.puzzle = puzzle ?? TangramPuzzle(name: "New Puzzle")
        self.connectionService = ConnectionService()
        self.validationService = ValidationService()
        self.persistenceService = PuzzlePersistenceService()
    }
    
    // MARK: - Piece Management
    
    func addPiece(type: PieceType, at position: CGPoint = .zero) {
        let transform = CGAffineTransform(translationX: position.x, y: position.y)
        let piece = TangramPiece(type: type, transform: transform)
        puzzle.pieces.append(piece)
        validate()
    }
    
    func removePiece(id: String) {
        puzzle.pieces.removeAll { $0.id == id }
        puzzle.connections.removeAll { $0.pieceAId == id || $0.pieceBId == id }
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
    
    func selectPiece(id: String?) {
        selectedPieceId = id
    }
    
    func setAnchorPiece(id: String?) {
        anchorPieceId = id
    }
    
    // MARK: - Connection Management
    
    func createConnection(type: ConnectionType) {
        guard let connection = connectionService.createConnection(
            type: type,
            pieces: puzzle.pieces
        ) else {
            return
        }
        
        puzzle.connections.append(connection)
        validate()
    }
    
    func removeConnection(id: String) {
        puzzle.connections.removeAll { $0.id == id }
        validate()
    }
    
    func getConnectionsBetween(pieceA: String, pieceB: String) -> Connection? {
        return connectionService.connectionBetween(pieceA, pieceB, connections: puzzle.connections)
    }
    
    // MARK: - Validation
    
    func validate() {
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
        
        if hasAreaOverlaps {
            errors.append("Pieces have area overlap")
        }
        
        if hasUnexplainedContacts {
            errors.append("Pieces touch without connection")
        }
        
        if !isConnected && puzzle.pieces.count > 1 {
            errors.append("Not all pieces are connected")
        }
        
        if puzzle.name.isEmpty {
            errors.append("Puzzle name is required")
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
        selectedPieceId = nil
        anchorPieceId = nil
        validationState = .unknown
        editMode = .select
    }
    
    func currentPuzzleData() -> TangramPuzzle {
        return puzzle
    }
    
    func loadPuzzle(from data: TangramPuzzle) {
        puzzle = data
        validate()
    }
    
    // MARK: - Connection Creation Workflow
    
    func startConnectionMode() {
        editMode = .connect
        connectionState = .selectingFirstPiece
        highlightedPoints = []
    }
    
    func cancelConnectionMode() {
        connectionState = .idle
        editMode = .select
        highlightedPoints = []
        selectedPieceId = nil
        anchorPieceId = nil
    }
    
    func selectPieceForConnection(pieceId: String) {
        switch connectionState {
        case .idle, .selectingFirstPiece:
            connectionState = .selectedFirstPiece(pieceId: pieceId, point: nil)
            anchorPieceId = pieceId
            highlightedPoints = getConnectionPoints(for: pieceId)
            
        case .selectedFirstPiece(let firstId, let firstPoint) where firstPoint != nil:
            if pieceId == firstId {
                connectionState = .selectedFirstPiece(pieceId: firstId, point: nil)
                highlightedPoints = getConnectionPoints(for: firstId)
            } else {
                connectionState = .selectingSecondPiece(
                    firstPieceId: firstId,
                    firstPoint: firstPoint!
                )
                selectedPieceId = pieceId
                highlightedPoints = getCompatiblePoints(for: pieceId, matching: firstPoint!)
            }
            
        case .selectingSecondPiece(let firstId, let firstPoint):
            if pieceId == firstId {
                connectionState = .selectedFirstPiece(pieceId: firstId, point: firstPoint)
                highlightedPoints = getConnectionPoints(for: firstId)
                selectedPieceId = nil
            } else {
                selectedPieceId = pieceId
                highlightedPoints = getCompatiblePoints(for: pieceId, matching: firstPoint)
            }
            
        default:
            break
        }
    }
    
    func selectConnectionPoint(_ point: ConnectionPoint) {
        switch connectionState {
        case .selectedFirstPiece(let pieceId, _):
            connectionState = .selectedFirstPiece(pieceId: pieceId, point: point)
            anchorPieceId = pieceId
            
        case .selectingSecondPiece(let firstId, let firstPoint):
            if arePointsCompatible(firstPoint, point) {
                let pending = createPendingConnection(
                    firstPiece: firstId,
                    firstPoint: firstPoint,
                    secondPiece: point.pieceId,
                    secondPoint: point
                )
                connectionState = .readyToConnect(connection: pending)
            } else {
                connectionState = .error("Incompatible connection points")
            }
            
        default:
            break
        }
    }
    
    func confirmConnection(with constraintType: ConstraintType? = nil) {
        guard case .readyToConnect(let pending) = connectionState else { return }
        
        let constraint = constraintType ?? getDefaultConstraint(for: pending.connectionType)
        
        let connection = Connection(
            type: pending.connectionType,
            constraint: Constraint(type: constraint, affectedPieceId: pending.pieceBId)
        )
        
        puzzle.connections.append(connection)
        
        connectionState = .idle
        editMode = .select
        highlightedPoints = []
        selectedPieceId = nil
        anchorPieceId = nil
        
        validate()
    }
    
    private func getConnectionPoints(for pieceId: String) -> [ConnectionPoint] {
        guard let piece = puzzle.pieces.first(where: { $0.id == pieceId }) else { return [] }
        
        var points: [ConnectionPoint] = []
        let vertices = getTransformedVertices(for: pieceId) ?? []
        let edges = TangramGeometry.edges(for: piece.type)
        
        for (index, vertex) in vertices.enumerated() {
            points.append(ConnectionPoint(
                type: .vertex(index: index),
                position: vertex,
                pieceId: pieceId
            ))
        }
        
        for (index, edge) in edges.enumerated() {
            let start = vertices[edge.startVertex]
            let end = vertices[edge.endVertex]
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
    
    private func getCompatiblePoints(for pieceId: String, matching firstPoint: ConnectionPoint) -> [ConnectionPoint] {
        let allPoints = getConnectionPoints(for: pieceId)
        
        return allPoints.filter { point in
            switch (firstPoint.type, point.type) {
            case (.vertex, .vertex), (.edge, .edge):
                return true
            default:
                return false
            }
        }
    }
    
    private func arePointsCompatible(_ point1: ConnectionPoint, _ point2: ConnectionPoint) -> Bool {
        switch (point1.type, point2.type) {
        case (.vertex, .vertex):
            return true
        case (.edge, .edge):
            return true
        default:
            return false
        }
    }
    
    private func createPendingConnection(
        firstPiece: String,
        firstPoint: ConnectionPoint,
        secondPiece: String,
        secondPoint: ConnectionPoint
    ) -> PendingConnection {
        
        let connectionType: ConnectionType
        
        switch (firstPoint.type, secondPoint.type) {
        case let (.vertex(v1), .vertex(v2)):
            connectionType = .vertexToVertex(
                pieceA: firstPiece,
                vertexA: v1,
                pieceB: secondPiece,
                vertexB: v2
            )
            
        case let (.edge(e1), .edge(e2)):
            connectionType = .edgeToEdge(
                pieceA: firstPiece,
                edgeA: e1,
                pieceB: secondPiece,
                edgeB: e2
            )
            
        default:
            fatalError("Invalid connection point combination")
        }
        
        let constraints = calculatePossibleConstraints(for: connectionType)
        
        return PendingConnection(
            pieceAId: firstPiece,
            pieceBId: secondPiece,
            pointA: firstPoint,
            pointB: secondPoint,
            connectionType: connectionType,
            possibleConstraints: constraints
        )
    }
    
    private func calculatePossibleConstraints(for connectionType: ConnectionType) -> [ConstraintType] {
        switch connectionType {
        case .vertexToVertex:
            return [
                .rotation(around: .zero, range: -Double.pi...Double.pi),
                .fixed
            ]
            
        case .edgeToEdge(let pieceA, let edgeA, let pieceB, let edgeB):
            guard let piece1 = puzzle.pieces.first(where: { $0.id == pieceA }),
                  let piece2 = puzzle.pieces.first(where: { $0.id == pieceB }) else {
                return [.fixed]
            }
            
            let edges1 = TangramGeometry.edges(for: piece1.type)
            let edges2 = TangramGeometry.edges(for: piece2.type)
            
            let length1 = edges1[edgeA].length
            let length2 = edges2[edgeB].length
            
            if abs(length1 - length2) > 0.01 {
                let slideRange = abs(length1 - length2)
                return [
                    .translation(along: CGVector(dx: 1, dy: 0), range: 0...slideRange),
                    .fixed
                ]
            } else {
                return [.fixed]
            }
        }
    }
    
    private func getDefaultConstraint(for connectionType: ConnectionType) -> ConstraintType {
        switch connectionType {
        case .vertexToVertex:
            return .rotation(around: .zero, range: -Double.pi...Double.pi)
        case .edgeToEdge:
            return .fixed
        }
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
    
    // MARK: - Undo/Redo (Future)
    
    func undo() {
        // TODO: Implement undo
    }
    
    func redo() {
        // TODO: Implement redo
    }
}