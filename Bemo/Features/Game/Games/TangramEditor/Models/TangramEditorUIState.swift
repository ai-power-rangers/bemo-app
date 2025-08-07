//
//  TangramEditorUIState.swift
//  Bemo
//
//  UI-specific state for Tangram Editor, separated from business logic
//

// WHAT: Pure UI state management for Tangram Editor, containing only presentation-related state
// ARCHITECTURE: State model in MVVM-S pattern, separates UI concerns from business logic in ViewModel
// USAGE: Owned by TangramEditorViewModel, tracks UI-only state like selections, modal visibility, canvas size

import Foundation
import CoreGraphics

/// UI-specific state for the Tangram Editor
struct TangramEditorUIState {
    
    // MARK: - Nested Types
    
    enum EditMode: String, CaseIterable {
        case select = "Select"
        case add = "Add"
        case connect = "Connect"
        case validate = "Validate"
    }
    
    enum NavigationState {
        case library
        case editor
        case settings
    }
    
    // MARK: - Selection State
    var selectedPieceIds: Set<String> = []
    var selectedCanvasPoints: [PiecePlacementService.ConnectionPoint] = []
    var selectedPendingPoints: [PiecePlacementService.ConnectionPoint] = []
    
    // MARK: - Canvas State
    var currentCanvasSize: CGSize = CGSize(width: 800, height: 800)
    var editMode: EditMode = .select
    var navigationState: NavigationState = .library
    
    // MARK: - Pending Operation State
    var pendingPieceType: PieceType? = nil
    var pendingPieceRotation: Double = 0
    var previewTransform: CGAffineTransform?
    var previewPiece: TangramPiece?
    
    // MARK: - Ghost/Manipulation State
    var manipulatingPieceId: String? = nil
    var ghostTransform: CGAffineTransform? = nil
    var showSnapIndicator: Bool = false
    
    // MARK: - Modal/Dialog State
    var showSettings: Bool = false
    var showSaveDialog: Bool = false
    var showErrorAlert: Bool = false
    var errorMessage: String = ""
    
    // MARK: - Computed Properties
    
    var hasSelection: Bool {
        !selectedPieceIds.isEmpty
    }
    
    var canConfirmPlacement: Bool {
        selectedCanvasPoints.count == selectedPendingPoints.count && 
        !selectedCanvasPoints.isEmpty
    }
    
    // MARK: - Mutation Methods
    
    mutating func clearSelectionState() {
        selectedPieceIds.removeAll()
        selectedCanvasPoints.removeAll()
        selectedPendingPoints.removeAll()
        pendingPieceType = nil
        pendingPieceRotation = 0
        previewTransform = nil
        previewPiece = nil
    }
    
    mutating func clearManipulationState() {
        manipulatingPieceId = nil
        ghostTransform = nil
        showSnapIndicator = false
    }
    
    mutating func selectPiece(_ pieceId: String) {
        selectedPieceIds.insert(pieceId)
    }
    
    mutating func deselectPiece(_ pieceId: String) {
        selectedPieceIds.remove(pieceId)
    }
    
    mutating func togglePieceSelection(_ pieceId: String) {
        if selectedPieceIds.contains(pieceId) {
            selectedPieceIds.remove(pieceId)
        } else {
            selectedPieceIds.insert(pieceId)
        }
    }
    
    mutating func selectAllPieces(from pieces: [TangramPiece]) {
        selectedPieceIds = Set(pieces.map { $0.id })
    }
    
    mutating func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }
    
    mutating func dismissError() {
        errorMessage = ""
        showErrorAlert = false
    }
}