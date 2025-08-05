//
//  TangramEditorViewModel.swift
//  Bemo
//
//  Main view model for the tangram editor, orchestrating all services
//

import Foundation
import SwiftUI
import Combine

@MainActor
class TangramEditorViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var puzzle: TangramPuzzle
    @Published var selectedPieceId: String?
    @Published var anchorPieceId: String?
    @Published var validationState: ValidationState = .unknown
    @Published var editMode: EditMode = .select
    @Published var showGrid: Bool = true
    @Published var snapToGrid: Bool = true
    
    // MARK: - Services
    
    private let connectionService: ConnectionService
    private let validationService: ValidationService
    
    // MARK: - Types
    
    enum EditMode {
        case select
        case move
        case rotate
        case connect
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
        // TODO: Implement actual persistence
    }
    
    func load(puzzleId: String) async throws {
        // TODO: Implement actual loading
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
    
    // MARK: - Undo/Redo (Future)
    
    func undo() {
        // TODO: Implement undo
    }
    
    func redo() {
        // TODO: Implement redo
    }
}