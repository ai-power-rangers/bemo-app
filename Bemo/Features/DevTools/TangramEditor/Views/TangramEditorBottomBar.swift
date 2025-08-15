//
//  TangramEditorBottomBar.swift
//  Bemo
//
//  Bottom bar for the tangram editor
//

import SwiftUI

struct TangramEditorBottomBar: View {
    @Bindable var viewModel: TangramEditorViewModel
    
    var body: some View {
        // Only show when in editor mode
        if viewModel.uiState.navigationState != .editor {
            return AnyView(EmptyView())
        }
        
        return AnyView(bottomBarContent)
    }
    
    private var bottomBarContent: some View {
        VStack(spacing: 8) {
            // Piece selection (only in appropriate states)
            if shouldShowPieceSelection {
                HStack(spacing: 8) {
                    Spacer()
                    
                    // Piece buttons
                    ForEach(availablePieceTypes, id: \.self) { pieceType in
                        let isPlaced = viewModel.puzzle.pieces.contains { $0.type == pieceType }
                        Button(action: {
                            if !isPlaced {
                                viewModel.startAddingPiece(type: pieceType)
                            }
                        }) {
                            Text(shortName(for: pieceType))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .frame(width: 44, height: 44)
                                .background(isPlaced ? TangramTheme.UI.disabled.opacity(0.1) : pieceType.color.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isPlaced ? TangramTheme.UI.disabled : pieceType.color, lineWidth: 2)
                                )
                                .cornerRadius(8)
                        }
                        .disabled(isPlaced || !canSelectPiece)
                        .opacity(isPlaced ? 0.3 : 1.0)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(
            TangramTheme.Backgrounds.toolbar
                .background(.ultraThinMaterial)
        )
    }
    
    private var shouldShowPieceSelection: Bool {
        switch viewModel.editorState {
        case .idle, .selectingFirstPiece, .selectingNextPiece:
            return true
        default:
            return false
        }
    }
    
    private var canSelectPiece: Bool {
        switch viewModel.editorState {
        case .idle, .selectingFirstPiece, .selectingNextPiece:
            return true
        default:
            return false
        }
    }
    
    private var availablePieceTypes: [PieceType] {
        switch viewModel.editorState {
        case .selectingFirstPiece:
            return PieceType.allCases
        case .selectingNextPiece, .idle:
            return PieceType.allCases.filter { type in
                !viewModel.puzzle.pieces.contains { $0.type == type }
            }
        default:
            return []
        }
    }
    
    private var isPendingPiece: Bool {
        switch viewModel.editorState {
        case .manipulatingFirstPiece, .manipulatingPendingPiece, .previewingPlacement:
            return true
        default:
            return false
        }
    }
    
    private func shortName(for pieceType: PieceType) -> String {
        switch pieceType {
        case .smallTriangle1: return "T1"
        case .smallTriangle2: return "T2"
        case .mediumTriangle: return "TM"
        case .largeTriangle1: return "L1"
        case .largeTriangle2: return "L2"
        case .square: return "SQ"
        case .parallelogram: return "PR"
        }
    }
}