//
//  TangramGameView.swift
//  Bemo
//
//  SwiftUI view for the Tangram puzzle game
//

import SwiftUI

struct TangramGameView: View {
    @StateObject var viewModel: TangramGameViewModel
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Game content
                VStack {
                    // Target shape outline
                    Text("Make a \(viewModel.targetShapeName)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                    
                    // Target shape preview
                    ZStack {
                        // Target outline
                        ForEach(viewModel.targetOutlines) { outline in
                            ShapeOutlineView(outline: outline)
                        }
                        
                        // Placed pieces
                        ForEach(viewModel.placedPieces) { piece in
                            PlacedPieceView(piece: piece)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(20)
                    .padding()
                    
                    // Feedback area
                    if viewModel.showFeedback {
                        Text(viewModel.feedbackMessage)
                            .font(.title2)
                            .foregroundColor(viewModel.feedbackColor)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .transition(.scale)
                    }
                }
            }
        }
        .onAppear {
            viewModel.startGame()
        }
    }
}

struct ShapeOutlineView: View {
    let outline: TangramGameViewModel.ShapeOutline
    
    var body: some View {
        outline.shape
            .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 3, dash: [10, 5]))
            .frame(width: outline.size.width, height: outline.size.height)
            .position(outline.position)
            .rotationEffect(.degrees(outline.rotation))
    }
}

struct PlacedPieceView: View {
    let piece: TangramGameViewModel.PlacedPieceDisplay
    
    var body: some View {
        piece.shape
            .fill(piece.color)
            .frame(width: piece.size.width, height: piece.size.height)
            .position(piece.position)
            .rotationEffect(.degrees(piece.rotation))
            .shadow(radius: 5)
            .animation(.spring(), value: piece.position)
    }
}