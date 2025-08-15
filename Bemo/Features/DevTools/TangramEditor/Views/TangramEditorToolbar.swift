//
//  TangramEditorToolbar.swift
//  Bemo
//
//  Two-row toolbar for the tangram editor with all controls
//

import SwiftUI

struct TangramEditorToolbar: View {
    @Bindable var viewModel: TangramEditorViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // First row: Navigation, Title, Save
            HStack {
                // Left: Back to Library
                Button(action: {
                    // Navigate directly back to library - no unsaved changes dialog
                    // Any unsaved work is discarded
                    viewModel.navigateToLibrary()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Library")
                    }
                    .font(.body)
                    .foregroundColor(TangramTheme.UI.primaryButton)
                }
                
                Spacer()
                
                // Center: Title
                Text("Tangram Editor")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Right: Save button
                Button(action: { viewModel.requestSave() }) {
                    Text("Save")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(canSave ? TangramTheme.Text.onColor : TangramTheme.UI.disabled)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(canSave ? TangramTheme.UI.primaryButton : TangramTheme.UI.disabled.opacity(0.3)))
                }
                .disabled(!canSave)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // Second row: Editor-specific controls (reduced height)
            HStack(spacing: 16) {
                // Undo/Redo group
                HStack(spacing: 10) {
                    Button(action: { viewModel.undo() }) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.body)
                            .foregroundColor(viewModel.canUndo ? TangramTheme.Text.primary : TangramTheme.UI.disabled)
                    }
                    .disabled(!viewModel.canUndo)
                    
                    Button(action: { viewModel.redo() }) {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.body)
                            .foregroundColor(viewModel.canRedo ? TangramTheme.Text.primary : TangramTheme.UI.disabled)
                    }
                    .disabled(!viewModel.canRedo)
                }
                
                Divider()
                    .frame(height: 16)
                
                // Piece manipulation controls (always visible but disabled when not applicable)
                HStack(spacing: 10) {
                    // Rotate left
                    Button(action: { 
                        if isPendingPiece {
                            viewModel.rotatePendingPiece(by: -45)
                        } else if hasSelectedPiece {
                            viewModel.rotateSelectedPieces(by: -45)
                        }
                    }) {
                        Image(systemName: "rotate.left")
                            .font(.body)
                            .foregroundColor(canRotate ? TangramTheme.Text.primary : TangramTheme.UI.disabled)
                    }
                    .disabled(!canRotate)
                    
                    // Rotate right
                    Button(action: { 
                        if isPendingPiece {
                            viewModel.rotatePendingPiece(by: 45)
                        } else if hasSelectedPiece {
                            viewModel.rotateSelectedPieces(by: 45)
                        }
                    }) {
                        Image(systemName: "rotate.right")
                            .font(.body)
                            .foregroundColor(canRotate ? TangramTheme.Text.primary : TangramTheme.UI.disabled)
                    }
                    .disabled(!canRotate)
                    
                    // Flip (for parallelogram only)
                    Button(action: { 
                        if isPendingPiece {
                            viewModel.flipPendingPiece()
                        } else if hasSelectedPiece {
                            viewModel.flipSelectedPieces()
                        }
                    }) {
                        Image(systemName: "arrow.left.and.right")
                            .font(.body)
                            .foregroundColor(canFlip ? TangramTheme.Text.primary : TangramTheme.UI.disabled)
                    }
                    .disabled(!canFlip)
                    
                    // Cancel
                    Button(action: { viewModel.cancelPendingPiece() }) {
                        Image(systemName: "xmark.circle")
                            .font(.body)
                            .foregroundColor(isPendingPiece ? TangramTheme.UI.destructive : TangramTheme.UI.disabled)
                    }
                    .disabled(!isPendingPiece)
                    
                    // Confirm
                    Button(action: { 
                        viewModel.confirmPendingPiece(canvasSize: viewModel.uiState.currentCanvasSize) 
                    }) {
                        Image(systemName: "checkmark.circle")
                            .font(.body)
                            .foregroundColor(canConfirm ? TangramTheme.UI.success : TangramTheme.UI.disabled)
                    }
                    .disabled(!canConfirm)
                }
                
                Divider()
                    .frame(height: 16)
                
                // Delete button (for selected pieces)
                Button(action: { viewModel.removeSelectedPieces() }) {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundColor(hasSelectedPiece ? TangramTheme.UI.destructive : TangramTheme.UI.disabled)
                }
                .disabled(!hasSelectedPiece)
                
                Spacer()
                
                // Validation status indicator
                if !viewModel.puzzle.pieces.isEmpty {
                    HStack(spacing: 4) {
                        if viewModel.validationState.isValid {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(TangramTheme.UI.success)
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(TangramTheme.UI.warning)
                        }
                        Text(viewModel.validationState.isValid ? "Valid" : "Invalid")
                            .font(.caption)
                            .foregroundColor(viewModel.validationState.isValid ? TangramTheme.UI.success : TangramTheme.UI.warning)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
        }
        .background(TangramTheme.Backgrounds.toolbar)
        .overlay(
            Rectangle()
                .fill(TangramTheme.UI.separator)
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - Helper Properties
    
    private var canSave: Bool {
        viewModel.validationState.isValid && viewModel.puzzle.pieces.count >= 2
    }
    
    private var isPendingPiece: Bool {
        switch viewModel.editorState {
        case .manipulatingFirstPiece, .manipulatingPendingPiece, .selectingPendingConnections, .previewingPlacement:
            return true
        default:
            return false
        }
    }
    
    private var hasSelectedPiece: Bool {
        !viewModel.uiState.selectedPieceIds.isEmpty
    }
    
    private var canRotate: Bool {
        isPendingPiece || hasSelectedPiece
    }
    
    private var canFlip: Bool {
        if isPendingPiece {
            // Check if it's a parallelogram
            switch viewModel.editorState {
            case .manipulatingFirstPiece(let type, _, _), 
                 .manipulatingPendingPiece(let type, _, _),
                 .selectingPendingConnections(let type, _):
                return type == .parallelogram
            default:
                return false
            }
        } else if hasSelectedPiece {
            // Check if any selected piece is a parallelogram
            return viewModel.puzzle.pieces.contains { piece in
                viewModel.uiState.selectedPieceIds.contains(piece.id) && piece.type == .parallelogram
            }
        }
        return false
    }
    
    private var canConfirm: Bool {
        switch viewModel.editorState {
        case .manipulatingFirstPiece:
            return true
        case .manipulatingPendingPiece, .selectingPendingConnections:
            // Use the unified validation from UIState
            // This requires BOTH valid connection matching AND a valid preview
            return viewModel.uiState.canPlacePiece
        case .previewingPlacement:
            return true
        default:
            return false
        }
    }
}