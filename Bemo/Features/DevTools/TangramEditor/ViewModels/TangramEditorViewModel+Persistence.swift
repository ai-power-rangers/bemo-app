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
        // Check if this is a new puzzle (doesn't exist in database yet)
        let isNewPuzzle = puzzle.createdDate == puzzle.modifiedDate
        
        puzzle.modifiedDate = Date()
        puzzle.solutionChecksum = generateChecksum()
        let updatedPuzzle = try await persistenceService.savePuzzle(puzzle)
        puzzle = updatedPuzzle
        
        // Update original data after successful save
        originalPuzzleData = try? JSONEncoder().encode(puzzle)
        
        await loadSavedPuzzles()
        
        // Update the PuzzleManagementService cache efficiently
        if let puzzleManagement = puzzleManagementService {
            if isNewPuzzle {
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
    
    func loadPuzzle(from loadedPuzzle: TangramPuzzle) {
        puzzle = loadedPuzzle
        // Save original state for change detection
        originalPuzzleData = try? JSONEncoder().encode(puzzle)
        // Set state based on whether puzzle has pieces
        stateManager.resetState(for: puzzle)
        editorState = stateManager.currentState
        validate()
        notifyPuzzleChanged()
        uiState.navigationState = .editor
    }
    
    func createNewPuzzle() {
        reset()
        puzzle = TangramPuzzle(name: "New Puzzle", category: .custom, difficulty: .medium)
        // Save original state (empty puzzle)
        originalPuzzleData = try? JSONEncoder().encode(puzzle)
        // New puzzle should start in selectingFirstPiece state
        stateManager.setInitialState(for: puzzle)
        editorState = stateManager.currentState
        uiState.navigationState = .editor
    }
    
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
    
    func requestQuit() {
        // Exit the editor and return to the game lobby
        delegate?.devToolDidRequestQuit()
    }
    
    func navigateToLibrary(saveChanges: Bool = false) {
        if saveChanges && !puzzle.pieces.isEmpty {
            // Save the puzzle before navigating
            Task {
                do {
                    try await save()
                } catch {
                }
                uiState.navigationState = .library
            }
        } else {
            // Clear the editor state when going back without saving
            reset()
            uiState.pendingPieceType = nil
            uiState.pendingPieceRotation = 0
            uiState.navigationState = .library
        }
    }
    
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
    
    func generateChecksum() -> String {
        let positionString = puzzle.pieces.map { piece in
            "\(piece.type.rawValue):\(piece.transform.tx),\(piece.transform.ty)"
        }.sorted().joined()
        return String(positionString.hashValue)
    }
}