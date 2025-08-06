//
//  TangramEditorView.swift
//  Bemo
//
//  Main view for the tangram puzzle editor
//

import SwiftUI

struct TangramEditorView: View {
    var viewModel: TangramEditorViewModel
    
    @State private var selectedConstraintValue: Double = 0
    @State private var canvasSize: CGSize = .zero
    @State private var showControls = false
    @State private var showSaveAlert = false
    @State private var puzzleName = ""
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top bar - Status and controls
                topBar
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .padding(.top) // Add top safe area padding
                    .background(Color.gray.opacity(0.05))
                
                // Main Canvas
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
                
                // Bottom Panel - Piece Palette
                bottomPiecePanel
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.1))
            }
            
            // Pending Piece View (top-right corner)
            VStack {
                HStack {
                    Spacer()
                    if case .pendingFirstPiece(let type, let rotation) = viewModel.editorState {
                        PendingPieceView(
                            viewModel: viewModel,
                            pieceType: type,
                            rotation: rotation,
                            isFirstPiece: true,
                            canvasSize: canvasSize
                        )
                        .padding()
                    } else if case .pendingSubsequentPiece(let type, let rotation) = viewModel.editorState {
                        PendingPieceView(
                            viewModel: viewModel,
                            pieceType: type,
                            rotation: rotation,
                            isFirstPiece: false,
                            canvasSize: canvasSize
                        )
                        .padding()
                    }
                }
                Spacer()
            }
        }
        .sheet(isPresented: $showControls) {
            controlPanel
                .presentationDetents([.medium])
        }
        .alert("Save Puzzle", isPresented: $showSaveAlert) {
            TextField("Puzzle Name", text: $puzzleName)
            Button("Save") {
                if !puzzleName.isEmpty {
                    viewModel.puzzle.name = puzzleName
                    Task {
                        try? await viewModel.save()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for your puzzle")
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack(spacing: 12) {
            // Validation Status (left side)
            validationStatusCompact
            
            Spacer()
            
            // Selection actions (center)
            if !viewModel.selectedPieceIds.isEmpty {
                HStack(spacing: 8) {
                    Button(action: { viewModel.clearSelection() }) {
                        Image(systemName: "xmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    
                    Button(action: { viewModel.removeSelectedPieces() }) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(.red)
                    
                    Text("\(viewModel.selectedPieceIds.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Action buttons (right side)
            HStack(spacing: 8) {
                // Save button (only when valid)
                if viewModel.validationState.isValid && viewModel.puzzle.pieces.count >= 2 {
                    Button(action: { showSaveAlert = true }) {
                        Label("Save", systemImage: "square.and.arrow.down")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.green)
                }
                
                // Controls button
                Button(action: { showControls.toggle() }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                }
            }
        }
    }
    
    private var connectionStateCompact: some View {
        HStack(spacing: 8) {
            switch viewModel.editorState {
            case .idle:
                if viewModel.puzzle.pieces.count > 0 {
                    Text("Select a piece to add")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    EmptyView()
                }
            case .pendingFirstPiece:
                Label("Configure and place first piece", systemImage: "1.circle.fill")
                    .foregroundColor(.blue)
            case .selectingCanvasPoints:
                HStack {
                    Label("Select 1-2 connection points (\(viewModel.selectedCanvasPoints.count) selected)", systemImage: "hand.tap.fill")
                        .foregroundColor(.orange)
                    if !viewModel.selectedCanvasPoints.isEmpty {
                        Button("Clear") {
                            viewModel.selectedCanvasPoints.removeAll()
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }
            case .pendingSubsequentPiece:
                Label("Match connection points on new piece", systemImage: "link.circle.fill")
                    .foregroundColor(.blue)
            case .previewingPlacement:
                Label("Preview placement", systemImage: "eye.fill")
                    .foregroundColor(.green)
            case .error(let msg):
                Text(msg)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .font(.caption)
    }
    
    private var validationStatusCompact: some View {
        HStack(spacing: 4) {
            if viewModel.puzzle.pieces.isEmpty {
                // No pieces yet
                EmptyView()
            } else if viewModel.validationState.isValid {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Valid Puzzle")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Invalid")
                        .foregroundColor(.orange)
                    if let firstError = viewModel.validationState.errors.first {
                        Text(firstError)
                            .font(.caption2)
                            .foregroundColor(.orange.opacity(0.8))
                            .lineLimit(1)
                    }
                }
            }
        }
        .font(.caption)
    }
    
    // MARK: - Bottom Piece Panel
    
    private var bottomPiecePanel: some View {
        HStack(spacing: 8) {
            // Piece buttons
            ForEach(PieceType.allCases, id: \.self) { pieceType in
                let isPlaced = viewModel.puzzle.pieces.contains { $0.type == pieceType }
                Button(action: {
                    if !isPlaced {
                        addPiece(type: pieceType)
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
                .buttonStyle(.plain)
                .disabled(isPlaced)
                .opacity(isPlaced ? 0.5 : 1.0)
            }
            
            Spacer()
            
            // Quick action - reset only
            Button(action: { viewModel.reset() }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title3)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.red)
        }
        .frame(height: 60)
    }
    
    private func shortName(for type: PieceType) -> String {
        switch type {
        case .smallTriangle1, .smallTriangle2: return "T-S"
        case .mediumTriangle: return "T-M"
        case .largeTriangle1, .largeTriangle2: return "T-L"
        case .square: return "S"
        case .parallelogram: return "P"
        }
    }
    
    private func pieceColor(for type: PieceType) -> Color {
        return type.color
    }
    
    private func addPiece(type: PieceType) {
        viewModel.startAddingPiece(type: type)
    }
    
    // MARK: - Canvas View
    
    private var canvasView: some View {
        ZStack {
            // Render all pieces
            ForEach(viewModel.puzzle.pieces) { piece in
                PieceView(
                    piece: piece,
                    isSelected: viewModel.selectedPieceIds.contains(piece.id),
                    pieceColor: pieceColor(for: piece.type)
                )
                .onTapGesture(count: 2) {
                    // Double tap selects all
                    viewModel.selectAllPieces()
                }
                .onTapGesture {
                    // Single tap toggles selection
                    viewModel.selectPiece(id: piece.id)
                }
            }
            
            // Show connection points when selecting on canvas or when placing subsequent piece
            switch viewModel.editorState {
            case .selectingCanvasPoints, .pendingSubsequentPiece:
                ForEach(viewModel.availableConnectionPoints, id: \.id) { point in
                    ConnectionPointView(
                        point: point,
                        isSelected: viewModel.selectedCanvasPoints.contains { $0.id == point.id },
                        isVertex: {
                            if case .vertex = point.type { return true }
                            return false
                        }()
                    )
                    .onTapGesture {
                        if case .selectingCanvasPoints = viewModel.editorState {
                            viewModel.toggleCanvasPoint(point)
                        }
                    }
                }
            default:
                EmptyView()
            }
            
            // Show preview of piece placement
            if let transform = viewModel.previewTransform,
               case .pendingSubsequentPiece(let type, _) = viewModel.editorState {
                PieceShape(type: type)
                    .fill(pieceColor(for: type).opacity(0.3))
                    .overlay(
                        PieceShape(type: type)
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    )
                    .transformEffect(transform)
                    .allowsHitTesting(false)
            }
            
            // Connection lines
            ForEach(viewModel.puzzle.connections) { connection in
                ConnectionLineView(connection: connection, pieces: viewModel.puzzle.pieces)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Control Panel (Modal)
    
    private var controlPanel: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Edit Mode Controls
                    editModeControls
                    
                    Divider()
                    
                    // Validation Details
                    validationDetailsView
                    
                    Divider()
                    
                    // Connections List
                    if !viewModel.puzzle.connections.isEmpty {
                        connectionsListView
                        Divider()
                    }
                    
                    // Constraint Controls (show for single selection)
                    if viewModel.selectedPieceIds.count == 1,
                       let selectedId = viewModel.selectedPieceIds.first,
                       let selectedPiece = viewModel.puzzle.pieces.first(where: { $0.id == selectedId }) {
                        constraintControls(for: selectedPiece)
                        Divider()
                    }
                    
                    // Action Buttons
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Editor Controls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showControls = false }
                }
            }
        }
    }
    
    private var validationDetailsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Validation")
                .font(.headline)
            
            if viewModel.validationState.isValid {
                Label("Valid Puzzle", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Invalid", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                    ForEach(viewModel.validationState.errors, id: \.self) { error in
                        Text("• \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    private var editModeControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mode")
                .font(.headline)
            
            Picker("Edit Mode", selection: Binding(
                get: { viewModel.editMode },
                set: { viewModel.editMode = $0 }
            )) {
                Text("Select").tag(TangramEditorViewModel.EditMode.select)
                Text("Rotate").tag(TangramEditorViewModel.EditMode.rotate)
                Text("Move").tag(TangramEditorViewModel.EditMode.move)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Show cancel button if we're in a pending state
            switch viewModel.editorState {
            case .pendingFirstPiece, .pendingSubsequentPiece:
                Button("Cancel Adding Piece") {
                    viewModel.cancelPendingPiece()
                    showControls = false
                }
                .buttonStyle(.bordered)
            default:
                EmptyView()
            }
        }
    }
    
    private var connectionsListView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connections (\(viewModel.puzzle.connections.count))")
                .font(.headline)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.puzzle.connections) { connection in
                        HStack {
                            Text(describeConnection(connection))
                                .font(.caption)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Button(action: {
                                viewModel.removeConnection(id: connection.id)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 8)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(4)
                    }
                }
            }
            .frame(maxHeight: 100)
        }
    }
    
    private func describeConnection(_ connection: Connection) -> String {
        switch connection.type {
        case .vertexToVertex(let pieceA, let vertexA, let pieceB, let vertexB):
            let pieceAType = viewModel.puzzle.pieces.first(where: { $0.id == pieceA })?.type.displayName ?? "?"
            let pieceBType = viewModel.puzzle.pieces.first(where: { $0.id == pieceB })?.type.displayName ?? "?"
            return "\(pieceAType) V\(vertexA) ↔ \(pieceBType) V\(vertexB)"
        case .edgeToEdge(let pieceA, let edgeA, let pieceB, let edgeB):
            let pieceAType = viewModel.puzzle.pieces.first(where: { $0.id == pieceA })?.type.displayName ?? "?"
            let pieceBType = viewModel.puzzle.pieces.first(where: { $0.id == pieceB })?.type.displayName ?? "?"
            return "\(pieceAType) E\(edgeA) ↔ \(pieceBType) E\(edgeB)"
        }
    }
    
    private func constraintControls(for piece: TangramPiece) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Constraints")
                .font(.headline)
            
            // Find connections for this piece
            let connections = viewModel.puzzle.connections.filter { 
                $0.pieceAId == piece.id || $0.pieceBId == piece.id 
            }
            
            ForEach(connections) { connection in
                VStack(alignment: .leading) {
                    switch connection.type {
                    case .vertexToVertex(let pieceA, let vertexA, let pieceB, let vertexB):
                        Text("Vertex Connection")
                            .font(.caption)
                        
                        if connection.constraint.affectedPieceId == piece.id {
                            // This piece can rotate
                            Slider(value: $selectedConstraintValue, in: -Double.pi...Double.pi) { _ in
                                if let vertex = getSharedVertex(pieceA: pieceA, vertexA: vertexA, pieceB: pieceB, vertexB: vertexB) {
                                    viewModel.rotatePieceAroundVertex(
                                        pieceId: piece.id,
                                        vertex: vertex,
                                        angle: selectedConstraintValue
                                    )
                                }
                            }
                            Text("Rotation: \(selectedConstraintValue, specifier: "%.2f")")
                                .font(.caption)
                        }
                        
                    case .edgeToEdge(let pieceA, let edgeA, let pieceB, let edgeB):
                        Text("Edge Connection")
                            .font(.caption)
                        
                        if case .translation(let along, let range) = connection.constraint.type,
                           connection.constraint.affectedPieceId == piece.id {
                            Slider(value: $selectedConstraintValue, in: range) { _ in
                                viewModel.slidePieceAlongEdge(
                                    pieceId: piece.id,
                                    edgeVector: along,
                                    distance: selectedConstraintValue
                                )
                            }
                            Text("Slide: \(selectedConstraintValue, specifier: "%.2f")")
                                .font(.caption)
                        }
                    }
                }
                .padding(8)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(4)
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 10) {
            Text("Actions")
                .font(.headline)
            
            if !viewModel.selectedPieceIds.isEmpty {
                Button("Remove Selected (\(viewModel.selectedPieceIds.count))") {
                    viewModel.removeSelectedPieces()
                    showControls = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .frame(maxWidth: .infinity)
            }
            
            Button("Clear All Pieces") {
                viewModel.reset()
                showControls = false
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(viewModel.puzzle.pieces.isEmpty)
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Helpers
    
    private func initializeEditor() {
        // Don't auto-add pieces - let user choose what to add
    }
    
    private func getSharedVertex(pieceA: String, vertexA: Int, pieceB: String, vertexB: Int) -> CGPoint? {
        guard let vertices = viewModel.getTransformedVertices(for: pieceA),
              vertexA < vertices.count else { return nil }
        return vertices[vertexA]
    }
}

// MARK: - Supporting Views

struct PieceView: View {
    let piece: TangramPiece
    let isSelected: Bool
    let pieceColor: Color
    
    var body: some View {
        PieceShape(type: piece.type)
            .fill(pieceColor)
            .overlay(
                PieceShape(type: piece.type)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .transformEffect(piece.transform)
    }
    
    private var borderColor: Color {
        isSelected ? .blue : .black
    }
    
    private var borderWidth: Double {
        isSelected ? 4 : 1
    }
}

struct PieceShape: Shape {
    let type: PieceType
    
    func path(in rect: CGRect) -> Path {
        let vertices = TangramGeometry.vertices(for: type)
        var path = Path()
        
        if let first = vertices.first {
            path.move(to: CGPoint(x: first.x * 50, y: first.y * 50))
            for vertex in vertices.dropFirst() {
                path.addLine(to: CGPoint(x: vertex.x * 50, y: vertex.y * 50))
            }
            path.closeSubpath()
        }
        
        return path
    }
}

struct PiecePreview: View {
    let type: PieceType
    
    var body: some View {
        PieceShape(type: type)
            .fill(Color.gray)
            .scaleEffect(0.3)
    }
}

struct ConnectionPointView: View {
    let point: TangramEditorViewModel.ConnectionPoint
    let isSelected: Bool
    let isVertex: Bool
    
    var body: some View {
        Group {
            if isVertex {
                // Vertex indicator - simple circle
                Circle()
                    .fill(isSelected ? Color.blue.opacity(0.4) : Color.gray.opacity(0.2))
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.blue : Color.gray, lineWidth: 2)
                    )
                    .frame(width: 16, height: 16)
            } else {
                // Edge indicator - simple square
                Rectangle()
                    .fill(isSelected ? Color.orange.opacity(0.4) : Color.gray.opacity(0.2))
                    .overlay(
                        Rectangle()
                            .stroke(isSelected ? Color.orange : Color.gray, lineWidth: 2)
                    )
                    .frame(width: 16, height: 16)
            }
        }
        .scaleEffect(isSelected ? 1.3 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .position(point.position)
    }
}

struct ConnectionLineView: View {
    let connection: Connection
    let pieces: [TangramPiece]
    
    var body: some View {
        Path { path in
            if let points = getConnectionPoints() {
                path.move(to: points.0)
                path.addLine(to: points.1)
            }
        }
        .stroke(Color.green, lineWidth: 2)
    }
    
    private func getConnectionPoints() -> (CGPoint, CGPoint)? {
        switch connection.type {
        case .vertexToVertex(let pieceA, let vertexA, let pieceB, let vertexB):
            guard let piece1 = pieces.first(where: { $0.id == pieceA }),
                  let piece2 = pieces.first(where: { $0.id == pieceB }) else { return nil }
            
            let vertices1 = GeometryEngine.transformVertices(
                TangramGeometry.vertices(for: piece1.type),
                with: piece1.transform
            )
            let vertices2 = GeometryEngine.transformVertices(
                TangramGeometry.vertices(for: piece2.type),
                with: piece2.transform
            )
            
            guard vertexA < vertices1.count, vertexB < vertices2.count else { return nil }
            return (vertices1[vertexA], vertices2[vertexB])
            
        case .edgeToEdge(let pieceA, let edgeA, let pieceB, let edgeB):
            guard let piece1 = pieces.first(where: { $0.id == pieceA }),
                  let piece2 = pieces.first(where: { $0.id == pieceB }) else { return nil }
            
            let edges1 = TangramGeometry.edges(for: piece1.type)
            let edges2 = TangramGeometry.edges(for: piece2.type)
            
            guard edgeA < edges1.count, edgeB < edges2.count else { return nil }
            
            let vertices1 = GeometryEngine.transformVertices(
                TangramGeometry.vertices(for: piece1.type),
                with: piece1.transform
            )
            let vertices2 = GeometryEngine.transformVertices(
                TangramGeometry.vertices(for: piece2.type),
                with: piece2.transform
            )
            
            let edge1Mid = CGPoint(
                x: (vertices1[edges1[edgeA].startVertex].x + vertices1[edges1[edgeA].endVertex].x) / 2,
                y: (vertices1[edges1[edgeA].startVertex].y + vertices1[edges1[edgeA].endVertex].y) / 2
            )
            let edge2Mid = CGPoint(
                x: (vertices2[edges2[edgeB].startVertex].x + vertices2[edges2[edgeB].endVertex].x) / 2,
                y: (vertices2[edges2[edgeB].startVertex].y + vertices2[edges2[edgeB].endVertex].y) / 2
            )
            
            return (edge1Mid, edge2Mid)
        }
    }
}

