//
//  TangramEditorCanvasView.swift
//  Bemo
//
//  Canvas view for tangram editor with piece manipulation
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
                    viewModel.uiState.currentCanvasSize = geometry.size
                    initializeEditor()
                }
                .onChange(of: geometry.size) { oldSize, newSize in
                    canvasSize = newSize
                    viewModel.uiState.currentCanvasSize = newSize
                }
            }
            
            // Selection controls floating near selected pieces
            if !viewModel.uiState.selectedPieceIds.isEmpty, let firstSelectedId = viewModel.uiState.selectedPieceIds.first,
               let selectedPiece = viewModel.puzzle.pieces.first(where: { $0.id == firstSelectedId }) {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Button(action: { viewModel.removeSelectedPieces() }) {
                            Image(systemName: "trash")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(Color.red))
                        }
                        
                        Button(action: { rotateSelectedPieces(by: 45) }) {
                            Image(systemName: "rotate.right")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(Color.blue))
                        }
                        
                        Button(action: { rotateSelectedPieces(by: -45) }) {
                            Image(systemName: "rotate.left")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(Color.blue))
                        }
                        
                        Button(action: { flipSelectedPieces() }) {
                            Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(Color.purple))
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.black.opacity(0.8))
                    )
                }
                .position(
                    x: min(max(100, extractTranslation(from: selectedPiece.transform).x), canvasSize.width - 100),
                    y: max(50, extractTranslation(from: selectedPiece.transform).y - 100)
                )
                .transition(.scale.combined(with: .opacity))
            }
            
            // Canvas point selection UI
            if case .selectingCanvasConnections = viewModel.editorState, !viewModel.uiState.selectedCanvasPoints.isEmpty {
                VStack {
                    HStack {
                        Text("\(viewModel.uiState.selectedCanvasPoints.count) point(s) selected")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.8))
                            .cornerRadius(8)
                        
                        Button(action: { viewModel.proceedToPendingPiece() }) {
                            Text("Next")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Color.green)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
            }
            
            // Pending piece overlay - show in multiple states
            let _ = print("[CANVAS VIEW] Current editorState: \(viewModel.editorState)")
            if case .selectingPendingConnections(let type, _) = viewModel.editorState {
                let _ = print("[CANVAS VIEW] Showing pending piece for selectingPendingConnections")
                VStack {
                    PendingPieceOverlay(
                        viewModel: viewModel,
                        pieceType: type,
                        rotation: viewModel.uiState.pendingPieceRotation,
                        isFirstPiece: false,
                        canvasSize: canvasSize
                    )
                    .padding(.top, 50)
                    
                    Spacer()
                }
            } else if case .manipulatingPendingPiece(let type, _, let rotation) = viewModel.editorState {
                let _ = print("[CANVAS VIEW] Showing pending piece for manipulatingPendingPiece")
                VStack {
                    PendingPieceOverlay(
                        viewModel: viewModel,
                        pieceType: type,
                        rotation: rotation,
                        isFirstPiece: false,
                        canvasSize: canvasSize
                    )
                    .padding(.top, 50)
                    
                    Spacer()
                }
            } else if case .manipulatingFirstPiece(let type, let rotation, _) = viewModel.editorState {
                let _ = print("[CANVAS VIEW] Showing pending piece for manipulatingFirstPiece")
                PendingPieceOverlay(
                    viewModel: viewModel,
                    pieceType: type,
                    rotation: rotation,
                    isFirstPiece: true,
                    canvasSize: canvasSize
                )
            } else {
                let _ = print("[CANVAS VIEW] NOT showing pending piece - state is: \(viewModel.editorState)")
            }
        }
        .alert("Placement Error", isPresented: $viewModel.uiState.showErrorAlert) {
            Button("OK") { 
                viewModel.dismissError() 
            }
        } message: {
            Text(viewModel.uiState.errorMessage)
        }
    }
    
    // MARK: - Canvas View
    
    private var canvasView: some View {
        ZStack {
            gridBackground
            piecesLayer
            previewLayer
        }
    }
    
    private var gridBackground: some View {
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
    }
    
    private var piecesLayer: some View {
        ForEach(viewModel.puzzle.pieces) { piece in
            pieceWithInteractions(piece)
                .onAppear {
                    print("DEBUG Canvas: Rendering piece \(piece.id) with transform \(piece.transform)")
                }
        }
    }
    
    @ViewBuilder
    private var previewLayer: some View {
        // Show preview piece when selecting connections
        if let previewPiece = viewModel.uiState.previewPiece {
            PieceView(
                piece: previewPiece,
                isSelected: false,
                isGhost: true,  // Show as ghost/transparent
                showConnectionPoints: false,
                availableConnectionPoints: [],
                selectedConnectionPoints: [],
                manipulationMode: nil,
                onRotation: { _ in },
                onSlide: { _ in },
                onManipulationEnd: { },
                onLockToggle: { }
            )
            .opacity(0.5)  // Make it semi-transparent
            .allowsHitTesting(false)  // Don't interfere with interactions
        }
    }
    
    private func pieceWithInteractions(_ piece: TangramPiece) -> some View {
        ZStack {
            PieceView(
                piece: viewModel.uiState.manipulatingPieceId == piece.id && viewModel.uiState.ghostTransform != nil ? 
                    TangramPiece(type: piece.type, transform: viewModel.uiState.ghostTransform!) : piece,
                isSelected: viewModel.uiState.selectedPieceIds.contains(piece.id),
                isGhost: viewModel.uiState.manipulatingPieceId == piece.id,
                showConnectionPoints: false,
                availableConnectionPoints: [],
                selectedConnectionPoints: [],
                manipulationMode: viewModel.pieceManipulationModes[piece.id],
                onRotation: { angle in
                    viewModel.handleRotation(pieceId: piece.id, angle: angle)
                },
                onSlide: { distance in
                    viewModel.handleSlide(pieceId: piece.id, distance: distance)
                },
                onManipulationEnd: {
                    if viewModel.uiState.manipulatingPieceId == piece.id {
                        // Determine if it was rotation or slide based on mode
                        if let mode = viewModel.pieceManipulationModes[piece.id] {
                            switch mode {
                            case .rotatable:
                                viewModel.confirmRotation()
                            case .slidable:
                                viewModel.confirmSlide()
                            case .locked:
                                break
                            }
                        }
                    }
                },
                onLockToggle: {
                    viewModel.togglePieceLock(id: piece.id)
                }
            )
            .onTapGesture(count: 2) {
                if canSelectPieces {
                    viewModel.selectAllPieces()
                }
            }
            .onTapGesture {
                if canSelectPieces {
                    handlePieceTap(piece)
                }
            }
            
            // Show selected connection points (visible during both selection and pending states)
            let showSelectedPoints = { () -> Bool in
                if case .selectingCanvasConnections = viewModel.editorState { return true }
                if case .selectingPendingConnections = viewModel.editorState { return true }
                if case .manipulatingPendingPiece = viewModel.editorState { return true }
                return false
            }()
            
            if showSelectedPoints {
                ForEach(viewModel.uiState.selectedCanvasPoints.filter { $0.pieceId == piece.id }, id: \.id) { point in
                    connectionPointView(point, isSelected: true)
                        .position(point.position)
                        .allowsHitTesting(false)  // Don't interfere with piece interaction
                }
            }
            
            // Connection point tap overlays
            if case .selectingCanvasConnections = viewModel.editorState {
                ForEach(viewModel.getConnectionPoints(for: piece.id), id: \.id) { point in
                    let isSelected = viewModel.uiState.selectedCanvasPoints.contains { $0.id == point.id }
                    connectionPointView(point, isSelected: isSelected)
                        .position(point.position)
                        .onTapGesture {
                            viewModel.toggleCanvasPoint(point)
                        }
                }
            }
        }
    }
    
    @ViewBuilder
    private func connectionPointView(_ point: TangramEditorViewModel.ConnectionPoint, isSelected: Bool) -> some View {
        let fillColor = isSelected ? Color.green.opacity(0.8) : Color.blue.opacity(0.6)
        let strokeColor = isSelected ? Color.green : Color.blue
        
        Group {
            switch point.type {
            case .vertex:
                Circle()
                    .fill(fillColor)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(strokeColor, lineWidth: 2)
                    )
            case .edge:
                Rectangle()
                    .fill(isSelected ? Color.green.opacity(0.8) : Color.orange.opacity(0.6))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Rectangle()
                            .stroke(isSelected ? Color.green : Color.orange, lineWidth: 2)
                    )
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
                
                Section("Settings") {
                    HStack {
                        Text("Grid Snap")
                        Spacer()
                        Toggle("", isOn: .constant(true))
                    }
                    
                    HStack {
                        Text("Show Guidelines")
                        Spacer()
                        Toggle("", isOn: .constant(false))
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
                        viewModel.uiState.showSettings = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var canSelectPieces: Bool {
        switch viewModel.editorState {
        case .idle, .error:
            return true
        case .manipulatingFirstPiece, .manipulatingPendingPiece, .selectingCanvasConnections:
            return false
        default:
            return false
        }
    }
    
    private func initializeEditor() {
        if viewModel.puzzle.pieces.isEmpty {
            viewModel.validate()
        } else {
            viewModel.recenterPuzzle()
            viewModel.validate()
        }
    }
    
    private func handlePieceTap(_ piece: TangramPiece) {
        viewModel.togglePieceSelection(piece.id)
    }
    
    private func rotateSelectedPieces(by angle: Double) {
        // Implementation for rotating selected pieces
    }
    
    private func flipSelectedPieces() {
        // Implementation for flipping selected pieces (parallelogram only)
    }
    
    private func extractTranslation(from transform: CGAffineTransform) -> CGPoint {
        return CGPoint(x: transform.tx, y: transform.ty)
    }
}

// MARK: - Supporting Types

enum EditorConstraintOption: String, CaseIterable {
    case angleSnap = "Angle Snap"
    case edgeSnap = "Edge Snap"
    case vertexSnap = "Vertex Snap"
    
    var description: String { rawValue }
}

// MARK: - Pending Piece Overlay

struct PendingPieceOverlay: View {
    let viewModel: TangramEditorViewModel
    let pieceType: PieceType
    let rotation: Double
    let isFirstPiece: Bool
    let canvasSize: CGSize
    
    var body: some View {
        PendingPieceView(
            viewModel: viewModel,
            pieceType: pieceType,
            rotation: rotation,
            isFirstPiece: isFirstPiece,
            canvasSize: canvasSize
        )
    }
}

#Preview {
    TangramEditorCanvasView(viewModel: .preview())
}