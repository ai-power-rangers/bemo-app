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
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Panel - Piece Palette
            piecePanel
                .frame(width: 200)
                .background(Color.gray.opacity(0.1))
            
            // Center - Canvas
            GeometryReader { geometry in
                ZStack {
                    canvasView
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                .onAppear {
                    canvasSize = geometry.size
                    initializeEditor()
                }
            }
            
            // Right Panel - Controls and Status
            controlPanel
                .frame(width: 300)
                .background(Color.gray.opacity(0.05))
        }
    }
    
    // MARK: - Piece Panel
    
    private var piecePanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Pieces")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 15) {
                    ForEach(PieceType.allCases, id: \.self) { pieceType in
                        Button(action: {
                            if viewModel.puzzle.pieces.isEmpty {
                                // First piece - place at center
                                let centerX = canvasSize.width / 2
                                let centerY = canvasSize.height / 2
                                viewModel.addPiece(type: pieceType, at: CGPoint(x: centerX, y: centerY))
                            } else {
                                // Add piece temporarily at origin for connection workflow
                                viewModel.addPiece(type: pieceType, at: .zero)
                                // Start connection mode - user will select existing piece first
                                viewModel.startConnectionMode()
                                // The new piece is already selected in addPiece
                            }
                        }) {
                            HStack {
                                PiecePreview(type: pieceType)
                                    .frame(width: 40, height: 40)
                                Text(pieceType.displayName)
                                    .font(.caption)
                                Spacer()
                            }
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding(.vertical)
    }
    
    // MARK: - Canvas View
    
    private var canvasView: some View {
        ZStack {
            // Render all pieces
            ForEach(viewModel.puzzle.pieces) { piece in
                PieceView(
                    piece: piece,
                    isSelected: viewModel.selectedPieceId == piece.id,
                    isAnchor: viewModel.anchorPieceId == piece.id,
                    connectionPoints: viewModel.selectedPieceId == piece.id ? viewModel.highlightedPoints : []
                )
                .onTapGesture {
                    handlePieceTap(piece)
                }
            }
            
            // Connection point indicators
            ForEach(viewModel.highlightedPoints, id: \.position) { point in
                ConnectionPointIndicator(
                    point: point,
                    isHighlighted: true,
                    isCompatible: true
                )
                .onTapGesture {
                    viewModel.selectConnectionPoint(point)
                }
            }
            
            // Connection lines
            ForEach(viewModel.puzzle.connections) { connection in
                ConnectionLineView(connection: connection, pieces: viewModel.puzzle.pieces)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Control Panel
    
    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Connection State Display
            connectionStateView
            
            Divider()
            
            // Validation Status
            validationStatusView
            
            Divider()
            
            // Edit Mode Controls
            editModeControls
            
            Divider()
            
            // Connections List
            if !viewModel.puzzle.connections.isEmpty {
                connectionsListView
                Divider()
            }
            
            // Constraint Controls
            if let selectedPiece = viewModel.puzzle.pieces.first(where: { $0.id == viewModel.selectedPieceId }) {
                constraintControls(for: selectedPiece)
            }
            
            Spacer()
            
            // Action Buttons
            actionButtons
        }
        .padding()
    }
    
    private var connectionStateView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connection State")
                .font(.headline)
            
            Group {
                switch viewModel.connectionState {
                case .idle:
                    Text("Idle")
                        .foregroundColor(.gray)
                case .selectingFirstPiece:
                    Text("Select first piece")
                        .foregroundColor(.blue)
                case .selectedFirstPiece(let pieceId, let point):
                    VStack(alignment: .leading) {
                        Text("First piece selected")
                            .foregroundColor(.green)
                        if let point = point {
                            Text("Point: \(describePoint(point))")
                                .font(.caption)
                        }
                    }
                case .selectingSecondPiece(let firstId, let firstPoint):
                    VStack(alignment: .leading) {
                        Text("Select second piece")
                            .foregroundColor(.blue)
                        Text("First: \(describePoint(firstPoint))")
                            .font(.caption)
                    }
                case .readyToConnect(let pending):
                    VStack(alignment: .leading) {
                        Text("Ready to connect!")
                            .foregroundColor(.green)
                        Button("Create Connection") {
                            viewModel.confirmConnection()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                case .error(let message):
                    Text("Error: \(message)")
                        .foregroundColor(.red)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(4)
        }
    }
    
    private var validationStatusView: some View {
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
                Text("Connect").tag(TangramEditorViewModel.EditMode.connect)
                Text("Rotate").tag(TangramEditorViewModel.EditMode.rotate)
                Text("Move").tag(TangramEditorViewModel.EditMode.move)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            if viewModel.editMode == .connect {
                Button("Cancel Connection") {
                    viewModel.cancelConnectionMode()
                }
                .buttonStyle(.bordered)
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
            Button("Re-center Puzzle") {
                viewModel.recenterPuzzle(canvasSize: canvasSize)
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            
            Button("Reset Puzzle") {
                viewModel.reset()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            
            Button("Remove Selected") {
                if let selectedId = viewModel.selectedPieceId {
                    viewModel.removePiece(id: selectedId)
                }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.selectedPieceId == nil)
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Helpers
    
    private func initializeEditor() {
        if viewModel.puzzle.pieces.isEmpty {
            // Add first piece at center
            let centerX = canvasSize.width / 2
            let centerY = canvasSize.height / 2
            viewModel.addPiece(type: .largeTriangle1, at: CGPoint(x: centerX, y: centerY))
        }
    }
    
    private func handlePieceTap(_ piece: TangramPiece) {
        if viewModel.editMode == .connect {
            viewModel.selectPieceForConnection(pieceId: piece.id)
        } else {
            viewModel.selectPiece(id: piece.id)
        }
    }
    
    private func describePoint(_ point: TangramEditorViewModel.ConnectionPoint) -> String {
        switch point.type {
        case .vertex(let index):
            return "Vertex \(index)"
        case .edge(let index):
            return "Edge \(index)"
        }
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
    let isAnchor: Bool
    let connectionPoints: [TangramEditorViewModel.ConnectionPoint]
    
    var body: some View {
        PieceShape(type: piece.type)
            .fill(pieceColor(for: piece.type))
            .overlay(
                PieceShape(type: piece.type)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .transformEffect(piece.transform)
    }
    
    private var borderColor: Color {
        if isAnchor {
            return .orange
        } else if isSelected {
            return .blue
        } else {
            return .black
        }
    }
    
    private var borderWidth: Double {
        isSelected || isAnchor ? 3 : 1
    }
    
    private func pieceColor(for type: PieceType) -> Color {
        switch type {
        case .smallTriangle1, .smallTriangle2: return .blue.opacity(0.7)
        case .mediumTriangle: return .green.opacity(0.7)
        case .largeTriangle1, .largeTriangle2: return .red.opacity(0.7)
        case .square: return .yellow.opacity(0.7)
        case .parallelogram: return .purple.opacity(0.7)
        }
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

struct ConnectionPointIndicator: View {
    let point: TangramEditorViewModel.ConnectionPoint
    let isHighlighted: Bool
    let isCompatible: Bool
    
    var body: some View {
        Group {
            switch point.type {
            case .vertex:
                Circle()
                    .fill(isCompatible ? Color.blue : Color.red)
                    .frame(width: 12, height: 12)
            case .edge:
                Rectangle()
                    .fill(isCompatible ? Color.orange : Color.red)
                    .frame(width: 16, height: 8)
            }
        }
        .opacity(isHighlighted ? 1.0 : 0.5)
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

