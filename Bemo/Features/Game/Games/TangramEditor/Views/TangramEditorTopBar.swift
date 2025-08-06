//
//  TangramEditorTopBar.swift
//  Bemo
//
//  Top bar for the tangram editor
//

import SwiftUI

struct TangramEditorTopBar: View {
    @Bindable var viewModel: TangramEditorViewModel
    let delegate: GameDelegate?
    
    var body: some View {
        HStack(spacing: 12) {
            // Left side: Back/Quit and Settings (fixed width)
            HStack(spacing: 8) {
                // Show back button when in editor, quit button when in library
                if viewModel.navigationState == .editor {
                    Button(action: {
                        viewModel.navigationState = .library
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Library")
                        }
                        .font(.caption)
                    }
                } else {
                    Button(action: {
                        delegate?.gameDidRequestQuit()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                }
                
            }
            .frame(width: 80, alignment: .leading)
            
            Spacer(minLength: 0)
            
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
                    if case .pendingFirstPiece(let type, _) = viewModel.editorState, type == .parallelogram {
                        Button(action: { viewModel.flipPendingPiece() }) {
                            Image(systemName: "arrow.left.and.right")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                    } else if case .pendingSubsequentPiece(let type, _) = viewModel.editorState, type == .parallelogram {
                        Button(action: { viewModel.flipPendingPiece() }) {
                            Image(systemName: "arrow.left.and.right")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Confirm
                    Button(action: { 
                        viewModel.confirmPendingPiece(canvasSize: viewModel.currentCanvasSize) 
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
            
            Spacer(minLength: 0)
            
            // Right side: Save button (fixed width)
            HStack {
                if viewModel.validationState.isValid && viewModel.puzzle.pieces.count >= 2 {
                    Button(action: { viewModel.requestSave() }) {
                        Label("Save", systemImage: "square.and.arrow.down")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .tint(.green)
                }
            }
            .frame(width: 100, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(
            Color(.systemBackground).opacity(0.95)
                .background(.ultraThinMaterial)
        )
    }
    
    private var isPendingPiece: Bool {
        switch viewModel.editorState {
        case .pendingFirstPiece, .pendingSubsequentPiece:
            return true
        default:
            return false
        }
    }
    
    private func canPlacePiece() -> Bool {
        switch viewModel.editorState {
        case .pendingFirstPiece:
            return true
        case .pendingSubsequentPiece:
            return !viewModel.selectedCanvasPoints.isEmpty &&
                   viewModel.selectedPendingPoints.count == viewModel.selectedCanvasPoints.count
        default:
            return false
        }
    }
}