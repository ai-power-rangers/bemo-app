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
        VStack(spacing: 0) {
            // Editor toolbar with two rows
            TangramEditorToolbar(viewModel: viewModel)
            
            // State indicator - shows current editor state
            Text(viewModel.currentStateDescription)
                .font(.caption)
                .foregroundColor(TangramTheme.Text.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white))
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.white)
            
            // Main Canvas
            ZStack {
                GeometryReader { geometry in
                    ZStack {
                        canvasView
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(TangramTheme.Backgrounds.panel)
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
                
                // Canvas point selection UI
                if case .selectingCanvasConnections = viewModel.editorState, !viewModel.uiState.selectedCanvasPoints.isEmpty {
                VStack {
                    HStack {
                        Text("\(viewModel.uiState.selectedCanvasPoints.count) point(s) selected")
                            .font(.caption)
                            .foregroundColor(TangramTheme.Text.onColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(TangramTheme.UI.primaryButton.opacity(0.8))
                            .cornerRadius(8)
                        
                        Button(action: { viewModel.proceedToPendingPiece() }) {
                            Text("Next")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(TangramTheme.Text.onColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(TangramTheme.UI.success)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
            }  // End of Canvas point selection UI
            }  // End of ZStack for Main Canvas
            
            // Pending piece overlay - show in multiple states
            if case .selectingPendingConnections(let type, _) = viewModel.editorState {
                VStack {
                    PendingPieceOverlay(
                        viewModel: viewModel,
                        pieceType: type,
                        rotation: viewModel.uiState.pendingPieceRotation,
                        isFlipped: viewModel.uiState.pendingPieceIsFlipped,
                        isFirstPiece: false,
                        canvasSize: canvasSize
                    )
                    .padding(.top, 50)
                    
                    Spacer()
                }
            } else if case .manipulatingPendingPiece(let type, _, let rotation) = viewModel.editorState {
                VStack {
                    PendingPieceOverlay(
                        viewModel: viewModel,
                        pieceType: type,
                        rotation: rotation,
                        isFlipped: viewModel.uiState.pendingPieceIsFlipped,
                        isFirstPiece: false,
                        canvasSize: canvasSize
                    )
                    .padding(.top, 50)
                    
                    Spacer()
                }
            } else if case .manipulatingFirstPiece(let type, let rotation, let isFlipped) = viewModel.editorState {
                PendingPieceOverlay(
                    viewModel: viewModel,
                    pieceType: type,
                    rotation: rotation,
                    isFlipped: isFlipped,
                    isFirstPiece: true,
                    canvasSize: canvasSize
                )
            } else {
                // Empty else block
            }
        }
        .alert("Placement Error", isPresented: $viewModel.uiState.showErrorAlert) {
            Button("OK") { 
                viewModel.dismissError() 
            }
        } message: {
            Text(viewModel.uiState.errorMessage)
        }
    }  // End of body
    
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
            context.stroke(path, with: .color(TangramTheme.DevTools.gridLine), lineWidth: 0.5)
        }
    }
    
    private var piecesLayer: some View {
        ForEach(viewModel.puzzle.pieces) { piece in
            pieceWithInteractions(piece)
                .onAppear {
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
                manipulationConstraints: nil,
                onRotation: { _ in },
                onSlide: { _ in },
                onManipulationEnd: { }
            )
            .opacity(0.5)  // Make it semi-transparent
            .allowsHitTesting(false)  // Don't interfere with interactions
        }
    }
    
    private func pieceWithInteractions(_ piece: TangramPiece) -> some View {
        ZStack {
            PieceView(
                piece: {
                    if viewModel.uiState.manipulatingPieceId == piece.id,
                       let ghostTransform = viewModel.uiState.ghostTransform {
                        return TangramPiece(type: piece.type, transform: ghostTransform)
                    } else {
                        return piece
                    }
                }(),
                isSelected: viewModel.uiState.selectedPieceIds.contains(piece.id),
                isGhost: viewModel.uiState.manipulatingPieceId == piece.id,
                showConnectionPoints: false,
                availableConnectionPoints: [],
                selectedConnectionPoints: [],
                manipulationMode: viewModel.uiState.selectedPieceIds.contains(piece.id) ? viewModel.pieceManipulationModes[piece.id] : nil,
                manipulationConstraints: viewModel.uiState.selectedPieceIds.contains(piece.id) ? viewModel.manipulationConstraints[piece.id] : nil,
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
                            case .fixed:
                                break
                            case .free:
                                // Handle free movement if needed
                                break
                            }
                        }
                    }
                },
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
        // Determine colors based on selection and matching
        let colors = getConnectionPointColors(for: point, isSelected: isSelected)
        
        Group {
            switch point.type {
            case .vertex:
                Circle()
                    .fill(colors.fill)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(colors.stroke, lineWidth: 2)
                    )
            case .edge:
                Rectangle()
                    .fill(colors.fill)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Rectangle()
                            .stroke(colors.stroke, lineWidth: 2)
                    )
            }
        }
    }
    
    private func getConnectionPointColors(for point: TangramEditorViewModel.ConnectionPoint, isSelected: Bool) -> (fill: Color, stroke: Color) {
        if isSelected {
            // Selected points are green
            return (fill: TangramTheme.UI.success.opacity(0.8), stroke: TangramTheme.UI.success)
        } else {
            // Check if we're in pending connection state and this type is needed
            if case .selectingPendingConnections = viewModel.editorState {
                // Count how many of this type are already selected on canvas
                let canvasVertexCount = viewModel.uiState.selectedCanvasPoints.filter { 
                    if case .vertex = $0.type { return true } else { return false }
                }.count
                let canvasEdgeCount = viewModel.uiState.selectedCanvasPoints.filter { 
                    if case .edge = $0.type { return true } else { return false }
                }.count
                
                // Count how many of this type are selected on pending piece
                let pendingVertexCount = viewModel.uiState.selectedPendingPoints.filter { 
                    if case .vertex = $0.type { return true } else { return false }
                }.count
                let pendingEdgeCount = viewModel.uiState.selectedPendingPoints.filter { 
                    if case .edge = $0.type { return true } else { return false }
                }.count
                
                // Determine if this type can still be selected
                switch point.type {
                case .vertex:
                    // Show as available if we need more vertices on pending piece
                    if pendingVertexCount < canvasVertexCount {
                        return (fill: TangramTheme.UI.primaryButton.opacity(0.3), stroke: TangramTheme.UI.primaryButton.opacity(0.5))
                    } else {
                        return (fill: TangramTheme.UI.disabled.opacity(0.2), stroke: TangramTheme.UI.disabled.opacity(0.3))
                    }
                case .edge:
                    // Show as available if we need more edges on pending piece
                    if pendingEdgeCount < canvasEdgeCount {
                        return (fill: TangramTheme.UI.warning.opacity(0.3), stroke: TangramTheme.UI.warning.opacity(0.5))
                    } else {
                        return (fill: TangramTheme.UI.disabled.opacity(0.2), stroke: TangramTheme.UI.disabled.opacity(0.3))
                    }
                }
            } else {
                // Normal state - show type colors
                switch point.type {
                case .vertex:
                    return (fill: TangramTheme.UI.primaryButton.opacity(0.6), stroke: TangramTheme.UI.primaryButton)
                case .edge:
                    return (fill: TangramTheme.UI.warning.opacity(0.6), stroke: TangramTheme.UI.warning)
                }
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
                    .foregroundColor(TangramTheme.UI.destructive)
                    
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
        case .idle, .error, .selectingNextPiece, .selectingFirstPiece, .pieceSelected:
            return true
        case .manipulatingFirstPiece, .manipulatingPendingPiece, .selectingCanvasConnections, .selectingPendingConnections:
            return false
        default:
            return true  // Allow selection by default
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
    let isFlipped: Bool
    let isFirstPiece: Bool
    let canvasSize: CGSize
    
    var body: some View {
        PendingPieceView(
            viewModel: viewModel,
            pieceType: pieceType,
            rotation: rotation,
            isFlipped: isFlipped,
            isFirstPiece: isFirstPiece,
            canvasSize: canvasSize
        )
    }
}

#Preview {
    TangramEditorCanvasView(viewModel: .preview())
}