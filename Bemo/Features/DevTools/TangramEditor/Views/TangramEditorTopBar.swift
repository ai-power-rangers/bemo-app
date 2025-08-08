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
                .foregroundColor(.blue)
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
                            .foregroundColor(.red)
                    }
                    
                    // Rotate
                    Button(action: { viewModel.rotatePendingPiece(by: 45) }) {
                        Image(systemName: "rotate.right")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                    
                    // Flip (for parallelogram)
                    if case .manipulatingFirstPiece(let type, _, _) = viewModel.editorState, type == .parallelogram {
                        Button(action: { viewModel.flipPendingPiece() }) {
                            Image(systemName: "arrow.left.and.right")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                    } else if case .manipulatingPendingPiece(let type, _, _) = viewModel.editorState, type == .parallelogram {
                        Button(action: { viewModel.flipPendingPiece() }) {
                            Image(systemName: "arrow.left.and.right")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Confirm
                    Button(action: { 
                        viewModel.confirmPendingPiece(canvasSize: viewModel.uiState.currentCanvasSize) 
                    }) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(canPlacePiece() ? .green : .gray)
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
                            .foregroundColor(viewModel.canUndo ? .primary : .gray)
                    }
                    .disabled(!viewModel.canUndo)
                    
                    // Redo button  
                    Button(action: { viewModel.redo() }) {
                        Image(systemName: "arrow.uturn.forward.circle")
                            .font(.title2)
                            .foregroundColor(viewModel.canRedo ? .primary : .gray)
                    }
                    .disabled(!viewModel.canRedo)
                    
                    // Validation status
                    if !viewModel.puzzle.pieces.isEmpty {
                        if viewModel.validationState.isValid {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.body)
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.body)
                                .foregroundColor(.orange)
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
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(viewModel.validationState.isValid && viewModel.puzzle.pieces.count >= 2 ? Color.blue : Color.gray))
            }
            .disabled(!(viewModel.validationState.isValid && viewModel.puzzle.pieces.count >= 2))
            .frame(width: 100, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
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