//
//  TangramEditorTopBar.swift
//  Bemo
//
//  Top bar for the tangram editor
//

import SwiftUI

struct TangramEditorTopBar: View {
    @Bindable var viewModel: TangramEditorViewModel
    let delegate: DevToolDelegate?
    
    var body: some View {
        HStack {
            // Left side: Back button
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
            .frame(width: 100, alignment: .leading)
            
            Spacer()
            
            // Center: Piece controls (when pending piece is active)
            if isPendingPiece {
                HStack(spacing: 16) {
                    // Cancel
                    Button(action: { viewModel.cancelPendingPiece() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(TangramTheme.UI.destructive)
                    }
                    
                    // Rotate
                    Button(action: { viewModel.rotatePendingPiece(by: 45) }) {
                        Image(systemName: "rotate.right")
                            .font(.title2)
                            .foregroundColor(TangramTheme.Text.primary)
                    }
                    
                    // Flip (for parallelogram)
                    if case .manipulatingFirstPiece(let type, _, _) = viewModel.editorState, type == .parallelogram {
                        Button(action: { viewModel.flipPendingPiece() }) {
                            Image(systemName: "arrow.left.and.right")
                                .font(.title2)
                                .foregroundColor(TangramTheme.Text.primary)
                        }
                    } else if case .manipulatingPendingPiece(let type, _, _) = viewModel.editorState, type == .parallelogram {
                        Button(action: { viewModel.flipPendingPiece() }) {
                            Image(systemName: "arrow.left.and.right")
                                .font(.title2)
                                .foregroundColor(TangramTheme.Text.primary)
                        }
                    }
                    
                    // Confirm
                    Button(action: { 
                        viewModel.confirmPendingPiece(canvasSize: viewModel.uiState.currentCanvasSize) 
                    }) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(canPlacePiece() ? TangramTheme.UI.success : TangramTheme.UI.disabled)
                    }
                    .disabled(!canPlacePiece())
                }
            } else {
                // Undo/Redo and validation status when not placing piece
                HStack(spacing: 16) {
                    // Undo button
                    Button(action: { viewModel.undo() }) {
                        Image(systemName: "arrow.uturn.backward.circle")
                            .font(.title2)
                            .foregroundColor(viewModel.canUndo ? TangramTheme.Text.primary : TangramTheme.UI.disabled)
                    }
                    .disabled(!viewModel.canUndo)
                    
                    // Redo button  
                    Button(action: { viewModel.redo() }) {
                        Image(systemName: "arrow.uturn.forward.circle")
                            .font(.title2)
                            .foregroundColor(viewModel.canRedo ? TangramTheme.Text.primary : TangramTheme.UI.disabled)
                    }
                    .disabled(!viewModel.canRedo)
                    
                    // Validation status
                    if !viewModel.puzzle.pieces.isEmpty {
                        if viewModel.validationState.isValid {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.body)
                                .foregroundColor(TangramTheme.UI.success)
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.body)
                                .foregroundColor(TangramTheme.UI.warning)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Right side: Save button
            Button(action: { viewModel.requestSave() }) {
                Text("Save")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(TangramTheme.Text.onColor)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(viewModel.validationState.isValid && viewModel.puzzle.pieces.count >= 2 ? TangramTheme.UI.primaryButton : TangramTheme.UI.disabled))
            }
            .disabled(!(viewModel.validationState.isValid && viewModel.puzzle.pieces.count >= 2))
            .frame(width: 100, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(TangramTheme.Backgrounds.toolbar)
    }
    
    private var isPendingPiece: Bool {
        switch viewModel.editorState {
        case .manipulatingFirstPiece, .manipulatingPendingPiece, .selectingPendingConnections, .previewingPlacement:
            return true
        default:
            return false
        }
    }
    
    private func canPlacePiece() -> Bool {
        switch viewModel.editorState {
        case .manipulatingFirstPiece:
            return true
        case .manipulatingPendingPiece, .selectingPendingConnections:
            // Can place when we have matching connection counts and a valid preview
            return !viewModel.uiState.selectedCanvasPoints.isEmpty &&
                   viewModel.uiState.selectedPendingPoints.count == viewModel.uiState.selectedCanvasPoints.count &&
                   viewModel.uiState.previewPiece != nil
        case .previewingPlacement:
            return true  // Already have a valid preview
        default:
            return false
        }
    }
}