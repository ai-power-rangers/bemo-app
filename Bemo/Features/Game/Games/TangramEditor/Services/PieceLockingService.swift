//
//  PieceLockingService.swift
//  Bemo
//
//  Service for managing piece lock/unlock state and validation
//

// WHAT: Manages the locking and unlocking of tangram pieces based on their connections
// ARCHITECTURE: Service layer in MVVM-S pattern, provides business logic for piece locking
// USAGE: Injected into ViewModel via DependencyContainer, call methods to lock/unlock pieces

import Foundation

@MainActor
class PieceLockingService {
    
    // MARK: - Public Methods
    
    /// Lock a piece
    func lockPiece(id: String, in puzzle: inout TangramPuzzle) {
        guard let index = puzzle.pieces.firstIndex(where: { $0.id == id }) else { return }
        puzzle.pieces[index].isLocked = true
    }
    
    /// Attempt to unlock a piece
    func unlockPiece(id: String, in puzzle: inout TangramPuzzle) -> Result<Void, TangramEditorError> {
        guard let index = puzzle.pieces.firstIndex(where: { $0.id == id }) else {
            return .failure(.operationNotAllowed("Piece not found"))
        }
        
        let piece = puzzle.pieces[index]
        
        // Check if piece can be unlocked
        if !canUnlock(piece: piece, connections: puzzle.connections) {
            let reason = getLockReason(piece: piece, connections: puzzle.connections)
            return .failure(.operationNotAllowed(reason ?? "Piece cannot be unlocked"))
        }
        
        puzzle.pieces[index].isLocked = false
        return .success(())
    }
    
    /// Check if a piece can be unlocked
    func canUnlock(piece: TangramPiece, connections: [Connection]) -> Bool {
        // Count connections for this piece
        let connectionCount = getConnectionCount(for: piece.id, in: connections)
        
        // Pieces with 2+ connections cannot be unlocked (they're structurally locked)
        if connectionCount >= 2 {
            return false
        }
        
        // Check if unlocking would break puzzle integrity
        // (e.g., if this piece is the only connection between two groups)
        if isKeyStructuralPiece(piece: piece, connections: connections) {
            return false
        }
        
        return true
    }
    
    /// Get the reason why a piece is locked
    func getLockReason(piece: TangramPiece, connections: [Connection]) -> String? {
        let connectionCount = getConnectionCount(for: piece.id, in: connections)
        
        if connectionCount >= 2 {
            return "Piece has \(connectionCount) connections and cannot be moved"
        }
        
        if isKeyStructuralPiece(piece: piece, connections: connections) {
            return "Piece is structurally important and cannot be unlocked"
        }
        
        if piece.isLocked {
            return "Piece is manually locked"
        }
        
        return nil
    }
    
    /// Toggle lock state of a piece
    func toggleLock(id: String, in puzzle: inout TangramPuzzle) -> Result<Bool, TangramEditorError> {
        guard let index = puzzle.pieces.firstIndex(where: { $0.id == id }) else {
            return .failure(.operationNotAllowed("Piece not found"))
        }
        
        let piece = puzzle.pieces[index]
        
        if piece.isLocked {
            // Try to unlock
            let result = unlockPiece(id: id, in: &puzzle)
            switch result {
            case .success:
                return .success(false) // Now unlocked
            case .failure(let error):
                return .failure(error)
            }
        } else {
            // Lock the piece
            lockPiece(id: id, in: &puzzle)
            return .success(true) // Now locked
        }
    }
    
    /// Auto-lock pieces based on their connections
    func autoLockPieces(in puzzle: inout TangramPuzzle) {
        for (index, piece) in puzzle.pieces.enumerated() {
            let connectionCount = getConnectionCount(for: piece.id, in: puzzle.connections)
            
            // Auto-lock pieces with 2+ connections
            if connectionCount >= 2 {
                puzzle.pieces[index].isLocked = true
            }
            // First piece is always locked initially
            else if puzzle.pieces.count == 1 {
                puzzle.pieces[index].isLocked = true
            }
        }
    }
    
    /// Update connection points for a piece
    func updateConnectionPoints(for pieceId: String, in puzzle: inout TangramPuzzle) {
        guard let pieceIndex = puzzle.pieces.firstIndex(where: { $0.id == pieceId }) else { return }
        
        // Find all connections involving this piece
        let pieceConnections = puzzle.connections.filter { connection in
            connection.pieceAId == pieceId || connection.pieceBId == pieceId
        }
        
        // Convert to ConnectionData array
        var connectionPoints: [ConnectionData] = []
        for connection in pieceConnections {
            connectionPoints.append(ConnectionData(
                otherPieceId: connection.pieceAId == pieceId ? connection.pieceBId : connection.pieceAId,
                type: connection.type
            ))
        }
        
        puzzle.pieces[pieceIndex].connectionPoints = connectionPoints
    }
    
    // MARK: - Private Helpers
    
    private func getConnectionCount(for pieceId: String, in connections: [Connection]) -> Int {
        connections.filter { $0.pieceAId == pieceId || $0.pieceBId == pieceId }.count
    }
    
    private func isKeyStructuralPiece(piece: TangramPiece, connections: [Connection]) -> Bool {
        // This is a simplified check - in a real implementation, 
        // we'd do a graph analysis to see if removing this piece
        // would disconnect the puzzle
        
        // For now, we'll say no pieces are structurally key
        // (this can be enhanced later with proper graph algorithms)
        return false
    }
}