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
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
                
                if viewModel.navigationState == .editor {
                    Button(action: {
                        viewModel.toggleSettings()
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
            }
            .frame(width: viewModel.navigationState == .editor ? 120 : 80, alignment: .leading)
            
            Spacer(minLength: 0)
            
            // Center: Piece controls (when pending piece is active)
            if isPendingPiece {
                HStack(spacing: 12) {
                    // Cancel
                    Button(action: { viewModel.cancelPendingPiece() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                    }
                    
                    // Rotate
                    Button(action: { viewModel.rotatePendingPiece(by: Double.pi/4) }) {
                        Image(systemName: "rotate.right")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                    
                    // Flip (for parallelogram)
                    if case .pendingFirstPiece(let type, _) = viewModel.editorState, type == .parallelogram {
                        Button(action: { viewModel.flipPendingPiece() }) {
                            Image(systemName: "arrow.left.and.right")
                                .font(.title3)
                                .foregroundColor(.primary)
                        }
                    } else if case .pendingSubsequentPiece(let type, _) = viewModel.editorState, type == .parallelogram {
                        Button(action: { viewModel.flipPendingPiece() }) {
                            Image(systemName: "arrow.left.and.right")
                                .font(.title3)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Confirm
                    Button(action: { 
                        viewModel.confirmPendingPiece(canvasSize: viewModel.currentCanvasSize) 
                    }) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(canPlacePiece() ? .green : .gray)
                    }
                    .disabled(!canPlacePiece())
                }
            } else {
                // Validation status when not placing piece (compact)
                if !viewModel.puzzle.pieces.isEmpty {
                    if viewModel.validationState.isValid {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer(minLength: 0)
            
            // Right side: Save button (fixed width)
            HStack {
                if viewModel.validationState.isValid && viewModel.puzzle.pieces.count >= 2 {
                    Button(action: { viewModel.requestSave() }) {
                        Text("Save")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.green)
                }
            }
            .frame(width: 60, alignment: .trailing)
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