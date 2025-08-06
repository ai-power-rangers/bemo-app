//
//  PieceView.swift
//  Bemo
//
//  View for displaying a tangram piece in the editor
//

import SwiftUI

struct PieceView: View {
    let piece: TangramPiece
    let isSelected: Bool
    let isGhost: Bool
    let showConnectionPoints: Bool
    let availableConnectionPoints: [TangramEditorViewModel.ConnectionPoint]
    let selectedConnectionPoints: [TangramEditorViewModel.ConnectionPoint]
    
    var body: some View {
        ZStack {
            // Main piece shape
            PieceShape(type: piece.type)
                .fill(fillColor)
                .overlay(
                    PieceShape(type: piece.type)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
                .transformEffect(piece.transform)
            
            // Connection points overlay
            if showConnectionPoints && !availableConnectionPoints.isEmpty {
                ForEach(availableConnectionPoints, id: \.id) { point in
                    ConnectionPointView(
                        point: point,
                        isSelected: selectedConnectionPoints.contains { $0.id == point.id },
                        onTap: nil  // Tap handling done at parent level
                    )
                }
            }
        }
    }
    
    private var fillColor: Color {
        if isGhost {
            return piece.type.color.opacity(0.3)
        } else {
            return piece.type.color.opacity(0.7)
        }
    }
    
    private var borderColor: Color {
        if isGhost {
            return Color.gray
        } else if isSelected {
            return Color.blue
        } else {
            return Color.black
        }
    }
    
    private var borderWidth: Double {
        isSelected ? 3 : 1
    }
}

struct PieceShape: Shape {
    let type: PieceType
    
    func path(in rect: CGRect) -> Path {
        let vertices = TangramGeometry.vertices(for: type)
        var path = Path()
        
        if let first = vertices.first {
            // Scale vertices by 50 to match visual size
            path.move(to: CGPoint(x: first.x * 50, y: first.y * 50))
            for vertex in vertices.dropFirst() {
                path.addLine(to: CGPoint(x: vertex.x * 50, y: vertex.y * 50))
            }
            path.closeSubpath()
        }
        
        return path
    }
}

struct ConnectionPointView: View {
    let point: TangramEditorViewModel.ConnectionPoint
    let isSelected: Bool
    let onTap: (() -> Void)?
    
    var body: some View {
        Group {
            switch point.type {
            case .vertex:
                Circle()
                    .fill(isSelected ? Color.green.opacity(0.8) : Color.blue.opacity(0.6))
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.green : Color.blue, lineWidth: 2)
                    )
                    .frame(width: 20, height: 20)
            case .edge:
                Rectangle()
                    .fill(isSelected ? Color.green.opacity(0.8) : Color.orange.opacity(0.6))
                    .overlay(
                        Rectangle()
                            .stroke(isSelected ? Color.green : Color.orange, lineWidth: 2)
                    )
                    .frame(width: 20, height: 20)
            }
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .position(point.position)
        .onTapGesture {
            onTap?()
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}