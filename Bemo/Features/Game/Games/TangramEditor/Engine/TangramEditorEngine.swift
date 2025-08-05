//
//  TangramEditorEngine.swift
//  Bemo
//
//  Core editing logic and state management for connection-based tangram editor
//

import Foundation
import SwiftUI

@Observable
class TangramEditorEngine {
    
    private(set) var puzzle: TangramPuzzle
    private(set) var anchorPieceId: String?
    private(set) var selectedPieceId: String?
    private(set) var validationState: ValidationState = .valid
    
    private let connectionSystem: ConnectionSystem
    
    struct ValidationState {
        let isValid: Bool
        let errors: [String]
        
        static let valid = ValidationState(isValid: true, errors: [])
    }
    
    init(puzzleName: String = "New Puzzle") {
        self.puzzle = TangramPuzzle(name: puzzleName)
        self.connectionSystem = ConnectionSystem()
    }
    
    // MARK: - Puzzle Management
    
    func loadPuzzle(_ puzzle: TangramPuzzle) {
        self.puzzle = puzzle
        
        connectionSystem.removeAllPieces()
        
        for piece in puzzle.pieces {
            connectionSystem.addPiece(
                id: piece.id,
                type: piece.type,
                transform: piece.currentTransform
            )
        }
        
        for connection in puzzle.connections {
            _ = connectionSystem.createConnection(type: connection.type)
        }
        
        if let firstPiece = puzzle.pieces.first {
            anchorPieceId = firstPiece.id
        }
        
        validate()
    }
    
    func clearCanvas() {
        puzzle = TangramPuzzle(name: puzzle.name)
        connectionSystem.removeAllPieces()
        anchorPieceId = nil
        selectedPieceId = nil
        validationState = .valid
    }
    
    // MARK: - Piece Management
    
    func addPiece(_ piece: TangramPiece) {
        puzzle.addPiece(piece)
        connectionSystem.addPiece(
            id: piece.id,
            type: piece.type,
            transform: piece.currentTransform
        )
        
        if anchorPieceId == nil {
            anchorPieceId = piece.id
        }
        
        validate()
    }
    
    func removePiece(id: String) {
        // Remove affected connections first
        let affectedConnections = puzzle.connections.filter { 
            $0.type.pieceAId == id || $0.type.pieceBId == id 
        }
        
        for connection in affectedConnections {
            connectionSystem.removeConnection(id: connection.id)
            puzzle.removeConnection(id: connection.id)
        }
        
        // Remove piece
        connectionSystem.removePiece(id: id)
        puzzle.removePiece(id: id)
        
        // Clear anchor if it was the removed piece
        if anchorPieceId == id {
            anchorPieceId = puzzle.pieces.first?.id
        }
        
        // Clear selection if it was the removed piece
        if selectedPieceId == id {
            selectedPieceId = nil
        }
        
        validate()
    }
    
    func updatePieceTransform(id: String, transform: CGAffineTransform) {
        connectionSystem.updatePieceTransform(id: id, transform: transform)
        
        // Update puzzle piece
        if let index = puzzle.pieces.firstIndex(where: { $0.id == id }) {
            puzzle.pieces[index].currentTransform = transform
        }
        
        validate()
    }
    
    // MARK: - Connection Management
    
    func addConnection(_ connection: Connection) {
        connectionSystem.addConnection(connection)
        puzzle.addConnection(connection)
        validate()
    }
    
    func removeConnection(id: String) {
        connectionSystem.removeConnection(id: id)
        puzzle.removeConnection(id: id)
        validate()
    }
    
    // MARK: - Selection
    
    func selectPiece(id: String?) {
        selectedPieceId = id
    }
    
    func deselectPiece() {
        selectedPieceId = nil
    }
    
    // MARK: - Validation
    
    private func validate() {
        let isValid = connectionSystem.isValidAssembly()
        var errors: [String] = []
        
        if connectionSystem.hasInvalidAreaOverlaps() {
            errors.append("Pieces have area overlap")
        }
        
        if connectionSystem.hasUnexplainedContacts() {
            errors.append("Pieces touch without connection")
        }
        
        if !connectionSystem.isConnected() {
            errors.append("Not all pieces are connected")
        }
        
        validationState = ValidationState(isValid: isValid, errors: errors)
    }
    
    // MARK: - Serialization
    
    func serializeCurrentPuzzle() -> Data? {
        // Sync connectionSystem changes to puzzle before serializing
        updatePuzzleFromConnectionSystem()
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(puzzle)
    }
    
    func loadPuzzle(from data: Data) {
        guard let loadedPuzzle = try? JSONDecoder().decode(TangramPuzzle.self, from: data) else {
            return
        }
        loadPuzzle(loadedPuzzle)
    }
    
    // MARK: - Export for Gameplay
    
    func exportForGameplay() -> SolvedTangramPuzzle? {
        updatePuzzleFromConnectionSystem()
        
        guard connectionSystem.isValidAssembly() else {
            return nil
        }
        
        let solvedPieces = puzzle.pieces.map { piece in
            SolvedPiece(
                pieceType: piece.type,
                transform: piece.currentTransform
            )
        }
        
        return SolvedTangramPuzzle(
            id: puzzle.id,
            name: puzzle.name,
            difficulty: puzzle.difficulty.rawValue,
            solvedPieces: solvedPieces
        )
    }
    
    // MARK: - Private Helpers
    
    private func updatePuzzleFromConnectionSystem() {
        var updatedPieces: [TangramPiece] = []
        
        for piece in puzzle.pieces {
            if let transform = connectionSystem.pieceTransforms[piece.id] {
                var updatedPiece = piece
                updatedPiece.currentTransform = transform
                updatedPieces.append(updatedPiece)
            } else {
                updatedPieces.append(piece)
            }
        }
        
        puzzle.pieces = updatedPieces
        puzzle.connections = connectionSystem.getAllConnections()
    }
}

// MARK: - Extensions

extension TangramEditorEngine {
    var connectionSystemRef: ConnectionSystem {
        return self.connectionSystem
    }
}

extension ConnectionSystem {
    var pieceTransforms: [String: CGAffineTransform] {
        get { return self.localPieceTransforms }
    }
    
    func removeAllPieces() {
        let allIds = Array(pieceTypes.keys)
        for id in allIds {
            removePiece(id: id)
        }
    }
}