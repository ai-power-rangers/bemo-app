//
//  UndoRedoManager.swift
//  Bemo
//
//  Service for managing undo/redo operations in Tangram Editor
//

import Foundation

class UndoRedoManager {
    
    private var undoStack: [PuzzleSnapshot] = []
    private var redoStack: [PuzzleSnapshot] = []
    private let maxStackSize: Int
    
    init(maxStackSize: Int = 50) {
        self.maxStackSize = maxStackSize
    }
    
    // MARK: - Public Properties
    
    var canUndo: Bool {
        !undoStack.isEmpty
    }
    
    var canRedo: Bool {
        !redoStack.isEmpty
    }
    
    var undoCount: Int {
        undoStack.count
    }
    
    var redoCount: Int {
        redoStack.count
    }
    
    // MARK: - Stack Management
    
    /// Save a snapshot for undo
    func saveSnapshot(_ snapshot: PuzzleSnapshot) {
        undoStack.append(snapshot)
        
        // Limit stack size to prevent excessive memory usage
        if undoStack.count > maxStackSize {
            undoStack.removeFirst()
        }
        
        // Clear redo stack when new action is performed
        redoStack.removeAll()
    }
    
    /// Save current state before performing an action
    func saveState(puzzle: TangramPuzzle) {
        let snapshot = PuzzleSnapshot(puzzle: puzzle)
        saveSnapshot(snapshot)
    }
    
    /// Get the last undo snapshot and move current to redo
    func popUndo(currentPuzzle: TangramPuzzle) -> PuzzleSnapshot? {
        guard let snapshot = undoStack.popLast() else { return nil }
        
        // Save current state to redo stack
        let currentSnapshot = PuzzleSnapshot(puzzle: currentPuzzle)
        redoStack.append(currentSnapshot)
        
        return snapshot
    }
    
    /// Get the last redo snapshot and move current to undo
    func popRedo(currentPuzzle: TangramPuzzle) -> PuzzleSnapshot? {
        guard let snapshot = redoStack.popLast() else { return nil }
        
        // Save current state to undo stack (without clearing redo)
        let currentSnapshot = PuzzleSnapshot(puzzle: currentPuzzle)
        undoStack.append(currentSnapshot)
        
        return snapshot
    }
    
    /// Clear all history
    func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
    
    /// Clear only redo history
    func clearRedoHistory() {
        redoStack.removeAll()
    }
    
    // MARK: - Memory Management
    
    /// Get accurate memory usage in bytes using JSON encoding
    var estimatedMemoryUsage: Int {
        let encoder = JSONEncoder()
        
        // Calculate undo stack memory
        let undoMemory = undoStack.reduce(0) { total, snapshot in
            if let data = try? encoder.encode(snapshot) {
                return total + data.count
            }
            // Fallback estimate if encoding fails
            return total + (snapshot.pieces.count * 200) + (snapshot.connections.count * 100)
        }
        
        // Calculate redo stack memory
        let redoMemory = redoStack.reduce(0) { total, snapshot in
            if let data = try? encoder.encode(snapshot) {
                return total + data.count
            }
            // Fallback estimate if encoding fails
            return total + (snapshot.pieces.count * 200) + (snapshot.connections.count * 100)
        }
        
        return undoMemory + redoMemory
    }
    
    /// Trim stacks if memory usage is too high
    func trimIfNeeded(maxMemoryBytes: Int = TangramConstants.maxUndoMemory) {
        guard estimatedMemoryUsage > maxMemoryBytes else { return }
        
        // Remove oldest entries until under limit
        while estimatedMemoryUsage > maxMemoryBytes && !undoStack.isEmpty {
            undoStack.removeFirst()
        }
    }
}