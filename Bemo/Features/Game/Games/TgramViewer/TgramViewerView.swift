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
                Color("AppBackground")
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
                            // Show CV overlay image if available
                            if let overlayImage = viewModel.overlayImage {
                                Image(uiImage: overlayImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                // Grid background when no overlay
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
                            
                            // Show status overlay
                            VStack {
                                HStack {
                                    // Session status
                                    if viewModel.isSessionActive {
                                        Label("Live", systemImage: "video.fill")
                                            .font(BemoTheme.font(for: .caption))
                                            .padding(8)
                                            .background(Color.green.opacity(0.8))
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    } else if viewModel.isPlayingRecording {
                                        Label("Playback", systemImage: "play.fill")
                                            .font(BemoTheme.font(for: .caption))
                                            .padding(8)
                                            .background(Color.blue.opacity(0.8))
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }
                                    
                                    // Recording indicator
                                    if viewModel.isRecording {
                                        Label("REC", systemImage: "record.circle.fill")
                                            .font(BemoTheme.font(for: .caption))
                                            .padding(8)
                                            .background(Color.red.opacity(0.8))
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }
                                    
                                    Spacer()
                                    
                                    // Detection info
                                    if viewModel.isSessionActive || viewModel.isPlayingRecording {
                                        Label("\(viewModel.detectionCount) detected", systemImage: "viewfinder")
                                            .font(BemoTheme.font(for: .caption))
                                            .padding(8)
                                            .background(Color.black.opacity(0.7))
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                        
                                        Label(String(format: "%.1f FPS", viewModel.fps), systemImage: "speedometer")
                                            .font(BemoTheme.font(for: .caption))
                                            .padding(8)
                                            .background(Color.black.opacity(0.7))
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }
                                }
                                Spacer()
                            }
                            .padding()
                        }
                        .onAppear {
                            viewModel.updateCanvasSize(to: geometry.size)
                        }
                        .onChange(of: geometry.size) { previous, newSize in
                            viewModel.updateCanvasSize(to: newSize)
                        }
                    }
                    .padding(BemoTheme.Spacing.medium)
                }
            }
            .navigationTitle("CV Output Viewer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        viewModel.toggleMode()
                    }) {
                        HStack(spacing: 6) {
                            if viewModel.isSessionActive {
                                Image(systemName: "video.fill")
                                Text("Live")
                            } else if viewModel.isPlayingRecording {
                                Image(systemName: "play.fill")
                                Text("Playback")
                            } else {
                                Image(systemName: "video")
                                Text("Start")
                            }
                        }
                        .foregroundColor(viewModel.isSessionActive ? .green : (viewModel.isPlayingRecording ? .blue : .primary))
                    }
                    .font(BemoTheme.font(for: .body))
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isSessionActive {
                        Button(action: {
                            viewModel.toggleRecording()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: viewModel.isRecording ? "record.circle.fill" : "record.circle")
                                Text(viewModel.isRecording ? "Stop Rec" : "Record")
                            }
                            .foregroundColor(viewModel.isRecording ? .red : .primary)
                        }
                        .font(BemoTheme.font(for: .body))
                    }
                }
            }
        }
        .onAppear {
            // Configure navigation bar appearance with AppBackground color
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color("AppBackground"))
            appearance.titleTextAttributes = [.foregroundColor: UIColor(Color("AppPrimaryTextColor"))]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color("AppPrimaryTextColor"))]
            
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            
            // Start CV session automatically
            viewModel.startCVSession()
        }
        .onDisappear {
            // Clean up when view disappears
            viewModel.reset()
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
