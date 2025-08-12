//
//  TgramViewerView.swift
//  Bemo
//
//  Main view for the TgramViewer game
//

// WHAT: Primary view for TgramViewer, displays CV-detected tangram pieces
// ARCHITECTURE: View in MVVM-S pattern, observes TgramViewerViewModel
// USAGE: Created by TgramViewerGame.makeGameView, displays pieces on canvas

import SwiftUI

struct TgramViewerView: View {
    @State private var viewModel: TgramViewerViewModel
    
    init(viewModel: TgramViewerViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color("GameBackground", bundle: nil)
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView("Loading CV data...")
                        .font(BemoTheme.font(for: .body))
                        .foregroundColor(BemoTheme.Colors.gray2)
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: BemoTheme.Spacing.medium) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(BemoTheme.Colors.primary)
                        
                        Text("Error Loading Data")
                            .font(BemoTheme.font(for: .heading2))
                            .foregroundColor(BemoTheme.Colors.primary)
                        
                        Text(error)
                            .font(BemoTheme.font(for: .body))
                            .foregroundColor(BemoTheme.Colors.gray2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, BemoTheme.Spacing.large)
                        
                        Button(action: viewModel.reset) {
                            Text("Retry")
                                .foregroundColor(.white)
                                .padding(.horizontal, BemoTheme.Spacing.large)
                                .padding(.vertical, BemoTheme.Spacing.small)
                                .background(BemoTheme.Colors.primary)
                                .cornerRadius(BemoTheme.CornerRadius.medium)
                        }
                    }
                } else {
                    // Main canvas
                    GeometryReader { geometry in
                        ZStack {
                            // Grid background
                            GridBackground()
                            
                            // Pieces
                            ForEach(viewModel.pieces) { piece in
                                TgramPieceView(piece: piece)
                            }
                            
                            // Origin marker
                            Circle()
                                .fill(Color.red.opacity(0.5))
                                .frame(width: 10, height: 10)
                                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        }
                        .onAppear {
                            viewModel.updateCanvasSize(to: geometry.size)
                        }
                        .onChange(of: geometry.size) { newSize in
                            viewModel.updateCanvasSize(to: newSize)
                        }
                    }
                    .padding(BemoTheme.Spacing.medium)
                }
            }
            .navigationTitle("CV Output Viewer")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Piece View

struct TgramPieceView: View {
    let piece: TgramViewerViewModel.DisplayPiece
    
    var body: some View {
        Path { path in
            if let first = piece.vertices.first {
                path.move(to: first)
                for vertex in piece.vertices.dropFirst() {
                    path.addLine(to: vertex)
                }
                path.closeSubpath()
            }
        }
        .fill(piece.color.opacity(0.7))
        .overlay(
            Path { path in
                if let first = piece.vertices.first {
                    path.move(to: first)
                    for vertex in piece.vertices.dropFirst() {
                        path.addLine(to: vertex)
                    }
                    path.closeSubpath()
                }
            }
            .stroke(Color.black, lineWidth: 2)
        )
        .rotationEffect(Angle(degrees: piece.rotation))
    }
}

// MARK: - Grid Background

struct GridBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let gridSize: CGFloat = 50
                let width = geometry.size.width
                let height = geometry.size.height
                
                // Vertical lines
                for x in stride(from: 0, through: width, by: gridSize) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
                
                // Horizontal lines
                for y in stride(from: 0, through: height, by: gridSize) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        }
    }
}

// MARK: - Preview

struct TgramViewerView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock delegate for preview
        let mockDelegate = MockGameDelegate()
        let viewModel = TgramViewerViewModel(delegate: mockDelegate)
        
        TgramViewerView(viewModel: viewModel)
            .previewDevice("iPhone 14 Pro")
            .previewDisplayName("TgramViewer - CV Output")
    }
}

// Mock delegate for preview
class MockGameDelegate: GameDelegate {
    func gameDidRequestHint() {
        print("")
    }
    
    func gameDidEncounterError(_ error: any Error) {
        print("")
    }
    
    func gameDidDetectFrustration(level: Float) {
        print("")
    }
    
    func gameDidCompleteLevel(xpAwarded: Int) {
        print("Level completed with \(xpAwarded) XP")
    }
    
    func gameDidRequestQuit() {
        print("Game quit requested")
    }
    
    func gameDidRequestPause() {
        print("Game pause requested")
    }
    
    func gameDidUpdateScore(_ score: Int) {
        print("Score updated: \(score)")
    }
    
    func gameDidUpdateProgress(_ progress: Float) {
        print("Progress updated: \(progress)")
    }
}
