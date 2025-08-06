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
        HStack(spacing: 8) {
            // Piece buttons
            ForEach(PieceType.allCases, id: \.self) { pieceType in
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
                        .background(isPlaced ? Color.gray.opacity(0.1) : pieceType.color.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isPlaced ? Color.gray : pieceType.color, lineWidth: 2)
                        )
                        .cornerRadius(8)
                }
                .disabled(isPlaced || isPendingPiece)
                .opacity(isPlaced ? 0.5 : 1.0)
            }
            
            Spacer()
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