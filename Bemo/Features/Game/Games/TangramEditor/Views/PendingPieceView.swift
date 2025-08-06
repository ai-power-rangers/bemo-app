//
//  PendingPieceView.swift
//  Bemo
//
//  View for displaying and configuring a pending tangram piece
//

import SwiftUI

struct PendingPieceView: View {
    let viewModel: TangramEditorViewModel
    let pieceType: PieceType
    let rotation: Double
    let isFirstPiece: Bool
    let canvasSize: CGSize
    
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    
    private let pieceScale: CGFloat = 40  // Doubled from 20
    
    var body: some View {
        VStack(spacing: 12) {
            // Piece preview at actual size (50 scale)
            ZStack {
                // Draw the piece - more transparent for preview
                PieceShapeForPending(type: pieceType, scale: 50)
                    .fill(pieceColor.opacity(0.3))  // More transparent
                    .overlay(
                        PieceShapeForPending(type: pieceType, scale: 50)
                            .stroke(pieceColor.opacity(0.7), lineWidth: 2)  // Lighter stroke
                    )
                    .rotationEffect(Angle(degrees: rotation))
                
                // Show connection points only after canvas points are selected
                if !isFirstPiece && !viewModel.selectedCanvasPoints.isEmpty {
                    ForEach(viewModel.getConnectionPointsForPendingPiece(type: pieceType, scale: 1), id: \.id) { (point: TangramEditorViewModel.ConnectionPoint) in
                        PendingConnectionPoint(
                            point: point,
                            rotation: rotation,
                            isSelected: viewModel.selectedPendingPoints.contains { $0.id == point.id },
                            isCompatible: isPointCompatible(point),
                            scale: 1
                        )
                        .onTapGesture {
                            viewModel.togglePendingPoint(point)
                        }
                    }
                }
            }
            .frame(width: 250, height: 250)  // Increased to prevent cutoff
            
            // Connection status text
            if !isFirstPiece {
                connectionStatusText
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemBackground).opacity(0.9))
                    .cornerRadius(8)
            }
        }
        .offset(dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation
                }
                .onEnded { value in
                    isDragging = false
                    // Keep the final position
                }
        )
        .animation(.interactiveSpring(), value: isDragging)
    }
    
    private var connectionStatusText: some View {
        Group {
            if viewModel.selectedCanvasPoints.isEmpty {
                Text("Select connection points on canvas")
                    .foregroundColor(.orange)
            } else if viewModel.selectedPendingPoints.count == viewModel.selectedCanvasPoints.count {
                // Check if types match properly
                let canvasVertexCount = viewModel.selectedCanvasPoints.filter { 
                    if case .vertex = $0.type { return true } else { return false }
                }.count
                let canvasEdgeCount = viewModel.selectedCanvasPoints.filter { 
                    if case .edge = $0.type { return true } else { return false }
                }.count
                let pendingVertexCount = viewModel.selectedPendingPoints.filter { 
                    if case .vertex = $0.type { return true } else { return false }
                }.count
                let pendingEdgeCount = viewModel.selectedPendingPoints.filter { 
                    if case .edge = $0.type { return true } else { return false }
                }.count
                
                if canvasVertexCount == pendingVertexCount && canvasEdgeCount == pendingEdgeCount {
                    Text("Ready to place!")
                        .foregroundColor(.green)
                } else {
                    Text("Type mismatch! Need \(canvasVertexCount) vertex + \(canvasEdgeCount) edge")
                        .foregroundColor(.red)
                }
            } else {
                Text("Match \(viewModel.selectedCanvasPoints.count) point\(viewModel.selectedCanvasPoints.count == 1 ? "" : "s") on this piece")
                    .foregroundColor(.blue)
            }
        }
    }
    
    private func isPointCompatible(_ point: TangramEditorViewModel.ConnectionPoint) -> Bool {
        for canvasPoint in viewModel.selectedCanvasPoints {
            switch (point.type, canvasPoint.type) {
            case (.vertex, .vertex), (.edge, .edge):
                return true
            default:
                continue
            }
        }
        return false
    }
    
    private var pieceColor: Color {
        return pieceType.color
    }
}

struct PieceShapeForPending: Shape {
    let type: PieceType
    let scale: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let vertices = TangramGeometry.vertices(for: type)
        var path = Path()
        
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        
        if let first = vertices.first {
            path.move(to: CGPoint(
                x: center.x + first.x * scale,
                y: center.y + first.y * scale
            ))
            for vertex in vertices.dropFirst() {
                path.addLine(to: CGPoint(
                    x: center.x + vertex.x * scale,
                    y: center.y + vertex.y * scale
                ))
            }
            path.closeSubpath()
        }
        
        return path
    }
}

struct PendingConnectionPoint: View {
    let point: TangramEditorViewModel.ConnectionPoint
    let rotation: Double
    let isSelected: Bool
    let isCompatible: Bool
    let scale: CGFloat
    
    var body: some View {
        // The point.position is in local space (relative to piece origin)
        // We need to rotate it, then translate to the center of the preview area
        let rotationRadians = rotation * .pi / 180
        let cosAngle = cos(rotationRadians)
        let sinAngle = sin(rotationRadians)
        
        // Break down the rotation calculation into simpler parts
        let rotatedX = point.position.x * cosAngle - point.position.y * sinAngle
        let rotatedY = point.position.x * sinAngle + point.position.y * cosAngle
        let rotatedPosition = CGPoint(x: rotatedX, y: rotatedY)
        
        // Center at 125,125 to match where PieceShapeForPending draws the piece
        let displayPosition = CGPoint(
            x: 125 + rotatedPosition.x,
            y: 125 + rotatedPosition.y
        )
        
        Group {
            switch point.type {
            case .vertex:
                Circle()
                    .fill(fillColor.opacity(isSelected ? 0.8 : 0.3))
                    .overlay(
                        Circle()
                            .stroke(strokeColor, lineWidth: 2)
                    )
                    .frame(width: 16, height: 16)  // Larger touch target
            case .edge:
                Rectangle()
                    .fill(fillColor.opacity(isSelected ? 0.8 : 0.3))
                    .overlay(
                        Rectangle()
                            .stroke(strokeColor, lineWidth: 2)
                    )
                    .frame(width: 16, height: 16)  // Larger touch target
            }
        }
        .scaleEffect(isSelected ? 1.3 : 1.0)
        .opacity(isCompatible ? 1.0 : 0.3)
        .position(displayPosition)
        .allowsHitTesting(isCompatible)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var fillColor: Color {
        if !isCompatible { return .gray }
        if isSelected { return .green }
        switch point.type {
        case .vertex: return .blue
        case .edge: return .orange
        }
    }
    
    private var strokeColor: Color {
        if !isCompatible { return .gray }
        if isSelected { return .green }
        switch point.type {
        case .vertex: return .blue
        case .edge: return .orange
        }
    }
}