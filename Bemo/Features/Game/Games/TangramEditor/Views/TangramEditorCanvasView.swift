//
//  TangramEditorCanvasView.swift
//  Bemo
//
//  Canvas view for the tangram editor (without bars)
//

import SwiftUI

struct TangramEditorCanvasView: View {
    @Bindable var viewModel: TangramEditorViewModel
    
    @State private var canvasSize: CGSize = .zero
    
    var body: some View {
        ZStack {
            // Main Canvas (full screen)
            GeometryReader { geometry in
                ZStack {
                    canvasView
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                .onAppear {
                    canvasSize = geometry.size
                    viewModel.currentCanvasSize = geometry.size
                    initializeEditor()
                }
                .onChange(of: geometry.size) { newSize in
                    canvasSize = newSize
                    viewModel.currentCanvasSize = newSize
                }
            }
            
            // Selection controls floating near selected pieces
            if !viewModel.selectedPieceIds.isEmpty, let firstSelectedId = viewModel.selectedPieceIds.first,
               let selectedPiece = viewModel.puzzle.pieces.first(where: { $0.id == firstSelectedId }) {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        // Clear selection
                        Button(action: { viewModel.clearSelection() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        
                        // Delete selected
                        Button(action: { viewModel.removeSelectedPieces() }) {
                            Image(systemName: "trash.circle.fill")
                                .font(.title3)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(8)
                    .background(Color(.systemBackground).opacity(0.95))
                    .cornerRadius(8)
                    .shadow(radius: 4)
                }
                .position(x: selectedPiece.transform.tx, y: selectedPiece.transform.ty - 80)
            }
            
            // Pending Piece View (at top center of canvas)
            if case .pendingFirstPiece(let type, let rotation) = viewModel.editorState {
                VStack {
                    PendingPieceView(
                        viewModel: viewModel,
                        pieceType: type,
                        rotation: rotation,
                        isFirstPiece: true,
                        canvasSize: canvasSize
                    )
                    Spacer()
                }
                .padding(.top, 20) // Small padding from top
            } else if case .pendingSubsequentPiece(let type, let rotation) = viewModel.editorState {
                VStack {
                    PendingPieceView(
                        viewModel: viewModel,
                        pieceType: type,
                        rotation: rotation,
                        isFirstPiece: false,
                        canvasSize: canvasSize
                    )
                    Spacer()
                }
                .padding(.top, 20) // Small padding from top
            }
        }
        .sheet(isPresented: $viewModel.showSettings) {
            controlPanel
                .presentationDetents([.medium])
        }
        .alert("Save Puzzle", isPresented: $viewModel.showSaveDialog) {
            TextField("Puzzle Name", text: .constant(viewModel.puzzle.name))
            Button("Save") {
                Task {
                    try? await viewModel.save()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for your puzzle")
        }
    }
    
    // MARK: - Canvas View
    
    private var canvasView: some View {
        ZStack {
            // Grid background
            Canvas { context, size in
                let gridSize = TangramConstants.gridSize
                let path = Path { path in
                    // Vertical lines
                    for x in stride(from: 0, through: size.width, by: gridSize) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    // Horizontal lines
                    for y in stride(from: 0, through: size.height, by: gridSize) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                }
                context.stroke(path, with: .color(.gray.opacity(0.1)), lineWidth: 0.5)
            }
            
            // Existing pieces
            ForEach(viewModel.puzzle.pieces) { piece in
                ZStack {
                    PieceView(
                        piece: piece,
                        isSelected: viewModel.selectedPieceIds.contains(piece.id),
                        isGhost: false,
                        showConnectionPoints: false,  // We draw them separately above for better control
                        availableConnectionPoints: [],
                        selectedConnectionPoints: []
                    )
                    .onTapGesture(count: 2) {
                        // Double tap to select all (only when not working with pending piece)
                        if !isPendingPiece {
                            viewModel.selectAllPieces()
                        }
                    }
                    .onTapGesture {
                        // Only allow selection when not working with pending piece
                        if !isPendingPiece {
                            handlePieceTap(piece)
                        }
                    }
                    
                    // Show selected connection points during pending piece placement
                    if case .pendingSubsequentPiece = viewModel.editorState {
                        ForEach(viewModel.selectedCanvasPoints.filter { $0.pieceId == piece.id }, id: \.id) { point in
                            Group {
                                switch point.type {
                                case .vertex:
                                    Circle()
                                        .fill(Color.green.opacity(0.8))
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.green, lineWidth: 2)
                                                .frame(width: 20, height: 20)
                                        )
                                case .edge:
                                    Rectangle()
                                        .fill(Color.green.opacity(0.8))
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Rectangle()
                                                .stroke(Color.green, lineWidth: 2)
                                                .frame(width: 20, height: 20)
                                        )
                                }
                            }
                            .position(point.position)
                        }
                    }
                    
                    // Connection point tap overlays - show them on top of the piece
                    if viewModel.editorState == .selectingCanvasPoints {
                        ForEach(viewModel.getConnectionPoints(for: piece.id), id: \.id) { point in
                            ZStack {
                                // Visual indicator
                                Group {
                                    switch point.type {
                                    case .vertex:
                                        Circle()
                                            .fill(viewModel.selectedCanvasPoints.contains { $0.id == point.id } ? 
                                                  Color.green.opacity(0.8) : Color.blue.opacity(0.6))
                                            .frame(width: 20, height: 20)
                                    case .edge:
                                        Rectangle()
                                            .fill(viewModel.selectedCanvasPoints.contains { $0.id == point.id } ? 
                                                  Color.green.opacity(0.8) : Color.orange.opacity(0.6))
                                            .frame(width: 20, height: 20)
                                    }
                                }
                                .overlay(
                                    Group {
                                        switch point.type {
                                        case .vertex:
                                            Circle()
                                                .stroke(viewModel.selectedCanvasPoints.contains { $0.id == point.id } ? 
                                                       Color.green : Color.blue, lineWidth: 2)
                                                .frame(width: 20, height: 20)
                                        case .edge:
                                            Rectangle()
                                                .stroke(viewModel.selectedCanvasPoints.contains { $0.id == point.id } ? 
                                                       Color.green : Color.orange, lineWidth: 2)
                                                .frame(width: 20, height: 20)
                                        }
                                    }
                                )
                            }
                            .position(point.position)
                            .onTapGesture {
                                viewModel.toggleCanvasPoint(point)
                            }
                        }
                    }
                }
            }
            
            // Preview ghost piece
            if case .previewingPlacement = viewModel.editorState,
               let preview = viewModel.previewPiece {
                PieceView(
                    piece: preview,
                    isSelected: false,
                    isGhost: true,
                    showConnectionPoints: false,
                    availableConnectionPoints: [],
                    selectedConnectionPoints: []
                )
                .allowsHitTesting(false)
            }
        }
    }
    
    // MARK: - Control Panel
    
    private var controlPanel: some View {
        NavigationView {
            Form {
                Section("Constraints") {
                    ForEach(EditorConstraintOption.allCases, id: \.self) { constraint in
                        HStack {
                            Text(constraint.description)
                            Spacer()
                            Toggle("", isOn: .constant(false))
                        }
                    }
                }
                
                Section("Actions") {
                    Button("Clear Puzzle") {
                        viewModel.clearPuzzle()
                    }
                    .foregroundColor(.red)
                    
                    Button("Validate") {
                        viewModel.validate()
                    }
                }
            }
            .navigationTitle("Editor Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.showSettings = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var isPendingPiece: Bool {
        switch viewModel.editorState {
        case .pendingFirstPiece, .pendingSubsequentPiece:
            return true
        default:
            return false
        }
    }
    
    private func initializeEditor() {
        if viewModel.puzzle.pieces.isEmpty {
            // Start with an empty puzzle
            viewModel.validate()
        } else {
            // Recenter existing puzzle
            viewModel.recenterPuzzle()
            viewModel.validate()
        }
    }
    
    private func handlePieceTap(_ piece: TangramPiece) {
        switch viewModel.editorState {
        case .selectingCanvasPoints:
            // Tap on connection points is handled by PieceView
            break
        default:
            // Normal selection
            viewModel.togglePieceSelection(piece.id)
        }
    }
}

// MARK: - Helper Enums

enum EditorConstraintOption: CaseIterable {
    case minimumPieces
    case maximumPieces
    case requireAllPieces
    case allowRotation
    case allowFlipping
    
    var description: String {
        switch self {
        case .minimumPieces: return "Minimum Pieces"
        case .maximumPieces: return "Maximum Pieces"
        case .requireAllPieces: return "Require All Pieces"
        case .allowRotation: return "Allow Rotation"
        case .allowFlipping: return "Allow Flipping"
        }
    }
}