//
//  TangramEditorViewModel+Persistence.swift
//  Bemo
//
//  Persistence and data management for Tangram Editor
//

// WHAT: Extension handling all persistence operations (save, load, delete puzzles)
// ARCHITECTURE: ViewModel extension for data persistence logic
// USAGE: Contains all methods for saving and loading tangram puzzles

import Foundation
import SwiftUI

extension TangramEditorViewModel {
    
    // MARK: - Persistence
    
    func save() async throws {
        // Clear any pending/UI state before saving
        clearPendingStateBeforeSave()
        
        // Only save if puzzle is valid
        guard canSavePuzzle else {
            throw TangramEditorError.validationFailed("Puzzle must be valid with at least 2 pieces")
        }
        
        // Check if this puzzle already exists in the cache (better indicator than date comparison)
        let existsInCache = await puzzleManagementService?.getTangramPuzzles().contains { $0.id == puzzle.id } ?? false
        
        puzzle.modifiedDate = Date()
        puzzle.solutionChecksum = generateChecksum()
        let updatedPuzzle = try await persistenceService.savePuzzle(puzzle)
        puzzle = updatedPuzzle
        
        // Update original data after successful save
        originalPuzzleData = try? JSONEncoder().encode(puzzle)
        
        await loadSavedPuzzles()
        
        // Update the PuzzleManagementService cache efficiently
        if let puzzleManagement = puzzleManagementService {
            if !existsInCache {
                await puzzleManagement.addNewPuzzle(puzzle.id)
            } else {
                await puzzleManagement.updateSinglePuzzle(puzzle.id)
            }
        }
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
            savedPuzzles = []
        }
    }
    
    // Use the loadPuzzle method from Navigation extension instead
    
    // Use the createNewPuzzle method from Navigation extension instead
    
    func deletePuzzle(_ puzzleToDelete: TangramPuzzle) async {
        do {
            try await persistenceService.deletePuzzle(id: puzzleToDelete.id)
            await loadSavedPuzzles()
            
            // Remove from PuzzleManagementService cache efficiently
            if let puzzleManagement = puzzleManagementService {
                await puzzleManagement.removePuzzle(puzzleToDelete.id)
            }
        } catch {
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
            let savedPuzzle = try await persistenceService.savePuzzle(newPuzzle)
            await loadSavedPuzzles()
            
            // Add new puzzle to PuzzleManagementService cache efficiently
            if let puzzleManagement = puzzleManagementService {
                await puzzleManagement.addNewPuzzle(savedPuzzle.id)
            }
        } catch {
        }
    }
    
    // MARK: - Navigation
    // Navigation methods are in TangramEditorViewModel+Navigation.swift
    
    // MARK: - Undo/Redo
    
    var canUndo: Bool { undoManager.canUndo }
    var canRedo: Bool { undoManager.canRedo }
    
    func undo() {
        guard let snapshot = undoManager.popUndo(currentPuzzle: puzzle) else { return }
        snapshot.apply(to: &puzzle)
        uiState.selectedPieceIds.removeAll()
        validate()
        notifyPuzzleChanged()
    }
    
    func redo() {
        guard let snapshot = undoManager.popRedo(currentPuzzle: puzzle) else { return }
        snapshot.apply(to: &puzzle)
        uiState.selectedPieceIds.removeAll()
        validate()
        notifyPuzzleChanged()
    }
    
    // MARK: - Helpers
    
    private func clearPendingStateBeforeSave() {
        // Clear any UI/pending state that shouldn't be persisted
        uiState.pendingPieceType = nil
        uiState.pendingPieceRotation = 0
        uiState.pendingPieceIsFlipped = false
        uiState.previewPiece = nil
        uiState.previewTransform = nil
        uiState.selectedCanvasPoints.removeAll()
        uiState.selectedPendingPoints.removeAll()
        uiState.clearManipulationState()
        
        // Ensure we're in a clean state
        if case .selectingCanvasConnections = editorState {
            _ = transitionToState(.idle)
        } else if case .selectingPendingConnections = editorState {
            _ = transitionToState(.idle)
        }
    }
    
    func generateChecksum() -> String {
        let positionString = puzzle.pieces.map { piece in
            "\(piece.type.rawValue):\(piece.transform.tx),\(piece.transform.ty)"
        }.sorted().joined()
        return String(positionString.hashValue)
    }
}