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
    
    private let pieceScale: CGFloat = 20  // Smaller scale for preview
    
    var body: some View {
        HStack(spacing: 8) {
            // Compact piece preview
            ZStack {
                // Draw the piece
                PieceShapeForPending(type: pieceType, scale: pieceScale)
                    .fill(pieceColor.opacity(0.3))
                    .overlay(
                        PieceShapeForPending(type: pieceType, scale: pieceScale)
                            .stroke(pieceColor, lineWidth: 2)
                    )
                    .rotationEffect(Angle(radians: rotation))
                    .frame(width: 80, height: 80)
                
                // Show connection points for subsequent pieces
                if !isFirstPiece {
                    ForEach(viewModel.getConnectionPointsForPendingPiece(type: pieceType, scale: pieceScale * 0.67), id: \.id) { point in
                        PendingConnectionPoint(
                            point: point,
                            rotation: rotation,
                            isSelected: viewModel.selectedPendingPoints.contains { $0.id == point.id },
                            isCompatible: isPointCompatible(point),
                            scale: pieceScale * 0.67
                        )
                        .onTapGesture {
                            if !isFirstPiece {
                                viewModel.togglePendingPoint(point)
                            }
                        }
                    }
                }
            }
            .frame(width: 80, height: 80)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // Control buttons
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    // Cancel
                    Button(action: { viewModel.cancelPendingPiece() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .frame(width: 32, height: 32)
                    
                    // Rotate
                    Button(action: { viewModel.rotatePendingPiece(by: Double.pi/4) }) {
                        Image(systemName: "rotate.right")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.bordered)
                    .frame(width: 32, height: 32)
                    
                    // Flip (for parallelogram)
                    if pieceType == .parallelogram {
                        Button(action: { viewModel.flipPendingPiece() }) {
                            Image(systemName: "arrow.left.and.right")
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.bordered)
                        .frame(width: 32, height: 32)
                    }
                    
                    // Confirm
                    Button(action: { viewModel.confirmPendingPiece(canvasSize: canvasSize) }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .frame(width: 32, height: 32)
                    .disabled(!canPlacePiece())
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.green.opacity(0.2))
                    )
                }
                
                // Connection status text
                if !isFirstPiece {
                    connectionStatusText
                }
            }
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: isDragging ? 8 : 4)
        .offset(dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation
                }
                .onEnded { value in
                    isDragging = false
                    dragOffset = value.translation
                }
        )
        .animation(.easeInOut(duration: 0.2), value: isDragging)
    }
    
    private var connectionStatusText: some View {
        Group {
            if viewModel.selectedCanvasPoints.isEmpty {
                Text("Select points")
                    .font(.caption2)
                    .foregroundColor(.orange)
            } else if viewModel.selectedPendingPoints.count == viewModel.selectedCanvasPoints.count {
                Text("Ready!")
                    .font(.caption2)
                    .foregroundColor(.green)
            } else {
                Text("Match \(viewModel.selectedCanvasPoints.count)")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
    }
    
    private func canPlacePiece() -> Bool {
        if isFirstPiece {
            return true
        } else {
            return !viewModel.selectedCanvasPoints.isEmpty && 
                   viewModel.selectedPendingPoints.count == viewModel.selectedCanvasPoints.count
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
        let rotatedPosition = rotatePoint(point.position, angle: rotation)
        let displayPosition = CGPoint(
            x: 40 + rotatedPosition.x,  // Center at 40 (half of 80)
            y: 40 + rotatedPosition.y
        )
        
        Group {
            switch point.type {
            case .vertex:
                Circle()
                    .fill(fillColor.opacity(0.3))
                    .overlay(
                        Circle()
                            .stroke(strokeColor, lineWidth: 1.5)
                    )
                    .frame(width: 12, height: 12)
            case .edge:
                Rectangle()
                    .fill(fillColor.opacity(0.3))
                    .overlay(
                        Rectangle()
                            .stroke(strokeColor, lineWidth: 1.5)
                    )
                    .frame(width: 12, height: 12)
            }
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
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
    
    private func rotatePoint(_ point: CGPoint, angle: Double) -> CGPoint {
        let cos = cos(angle)
        let sin = sin(angle)
        return CGPoint(
            x: point.x * cos - point.y * sin,
            y: point.x * sin + point.y * cos
        )
    }
}