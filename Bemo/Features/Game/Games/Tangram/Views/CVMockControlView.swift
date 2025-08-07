//
//  CVMockControlView.swift
//  Bemo
//
//  Development tool for simulating CV piece recognition
//

// WHAT: Mock control panel for simulating computer vision input during development
// ARCHITECTURE: View in MVVM-S, provides UI controls to simulate piece placement/removal
// USAGE: Shown in development mode to test CV processing without actual CV service

import SwiftUI

struct CVMockControlView: View {
    
    // MARK: - Properties
    
    @Binding var mockPieces: [RecognizedPiece]
    let onPiecesChanged: ([RecognizedPiece]) -> Void
    @State private var isExpanded = false
    @State private var selectedPieceType: PieceType?
    
    // MARK: - Simulated piece positions for testing
    
    private let mockPositions: [CGPoint] = [
        CGPoint(x: 150, y: 200),
        CGPoint(x: 250, y: 200),
        CGPoint(x: 350, y: 200),
        CGPoint(x: 200, y: 300),
        CGPoint(x: 300, y: 300),
        CGPoint(x: 250, y: 400),
        CGPoint(x: 350, y: 400)
    ]
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: "hammer.fill")
                    .foregroundColor(.orange)
                Text("CV Simulator")
                    .font(.headline)
                Spacer()
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.8))
            .foregroundColor(.white)
            
            if isExpanded {
                VStack(spacing: 12) {
                    // Quick actions
                    HStack(spacing: 10) {
                        Button("Place All") {
                            placeAllPiecesCorrectly()
                        }
                        .buttonStyle(MockButtonStyle(color: .green))
                        
                        Button("Scramble") {
                            scramblePieces()
                        }
                        .buttonStyle(MockButtonStyle(color: .orange))
                        
                        Button("Clear All") {
                            clearAllPieces()
                        }
                        .buttonStyle(MockButtonStyle(color: .red))
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
                    // Individual piece controls
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(PieceType.allCases, id: \.self) { pieceType in
                                PieceControlRow(
                                    pieceType: pieceType,
                                    isPlaced: isPiecePlaced(pieceType),
                                    onPlace: { placePiece(pieceType, correct: true) },
                                    onPlaceWrong: { placePiece(pieceType, correct: false) },
                                    onRemove: { removePiece(pieceType) },
                                    onRotate: { rotatePiece(pieceType) }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxHeight: 300)
                    
                    // Status
                    HStack {
                        Text("Pieces placed: \(mockPieces.count)/7")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 10)
                .background(Color.black.opacity(0.9))
            }
        }
        .background(Color.black.opacity(0.95))
        .cornerRadius(12)
        .shadow(radius: 10)
        .frame(maxWidth: 400)
    }
    
    // MARK: - Helper Methods
    
    private func isPiecePlaced(_ type: PieceType) -> Bool {
        mockPieces.contains { piece in
            piece.pieceTypeId == type.rawValue
        }
    }
    
    private func placePiece(_ type: PieceType, correct: Bool) {
        // Remove existing piece of this type
        removePiece(type)
        
        // Create new mock piece with proper CV data
        let index = PieceType.allCases.firstIndex(of: type) ?? 0
        let basePosition = index < mockPositions.count ? mockPositions[index] : CGPoint(x: 200, y: 200)
        
        // Add some randomness if placing incorrectly
        let position = correct ? basePosition : CGPoint(
            x: basePosition.x + Double.random(in: -50...50),
            y: basePosition.y + Double.random(in: -50...50)
        )
        
        let rotation = correct ? 0.0 : Double.random(in: 0...360)
        
        let mockPiece = RecognizedPiece(
            id: "piece_\(type.rawValue)_\(UUID().uuidString.prefix(8))",
            pieceTypeId: type.rawValue,
            position: position,
            rotation: rotation,
            velocity: CGVector(dx: 0, dy: 0), // Stationary when placed
            isMoving: false,
            confidence: correct ? 0.95 : 0.75,
            timestamp: Date(),
            frameNumber: Int.random(in: 1000...9999)
        )
        
        mockPieces.append(mockPiece)
        onPiecesChanged(mockPieces)
    }
    
    private func removePiece(_ type: PieceType) {
        mockPieces.removeAll { piece in
            piece.pieceTypeId == type.rawValue
        }
        onPiecesChanged(mockPieces)
    }
    
    private func rotatePiece(_ type: PieceType) {
        if let index = mockPieces.firstIndex(where: { $0.pieceTypeId == type.rawValue }) {
            let piece = mockPieces[index]
            let newPiece = RecognizedPiece(
                id: piece.id,
                pieceTypeId: piece.pieceTypeId,
                position: piece.position,
                rotation: piece.rotation + 45,
                velocity: CGVector(dx: 0, dy: 0),
                isMoving: false,
                confidence: piece.confidence,
                timestamp: Date(),
                frameNumber: piece.frameNumber + 1
            )
            mockPieces[index] = newPiece
            onPiecesChanged(mockPieces)
        }
    }
    
    private func placeAllPiecesCorrectly() {
        clearAllPieces()
        for (index, pieceType) in PieceType.allCases.enumerated() {
            let position = index < mockPositions.count ? mockPositions[index] : CGPoint(x: 200, y: 200)
            let mockPiece = RecognizedPiece(
                id: "piece_\(pieceType.rawValue)_\(UUID().uuidString.prefix(8))",
                pieceTypeId: pieceType.rawValue,
                position: position,
                rotation: 0,
                velocity: CGVector(dx: 0, dy: 0),
                isMoving: false,
                confidence: 0.95,
                timestamp: Date(),
                frameNumber: Int.random(in: 1000...9999)
            )
            mockPieces.append(mockPiece)
        }
        onPiecesChanged(mockPieces)
    }
    
    private func scramblePieces() {
        clearAllPieces()
        for pieceType in PieceType.allCases.shuffled().prefix(Int.random(in: 3...7)) {
            placePiece(pieceType, correct: false)
        }
    }
    
    private func clearAllPieces() {
        mockPieces.removeAll()
        onPiecesChanged(mockPieces)
    }
    
}

// MARK: - Supporting Views

struct PieceControlRow: View {
    let pieceType: PieceType
    let isPlaced: Bool
    let onPlace: () -> Void
    let onPlaceWrong: () -> Void
    let onRemove: () -> Void
    let onRotate: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Piece indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(pieceType.color)
                .frame(width: 20, height: 20)
            
            Text(pieceType.displayName)
                .font(.caption)
                .foregroundColor(.white)
                .frame(width: 100, alignment: .leading)
            
            Spacer()
            
            // Control buttons
            if isPlaced {
                Button(action: onRotate) {
                    Image(systemName: "rotate.right")
                        .font(.caption)
                }
                .buttonStyle(MiniButtonStyle(color: .blue))
                
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(MiniButtonStyle(color: .red))
            } else {
                Button("Place", action: onPlace)
                    .buttonStyle(MiniButtonStyle(color: .green))
                
                Button("Wrong", action: onPlaceWrong)
                    .buttonStyle(MiniButtonStyle(color: .orange))
            }
        }
        .padding(.vertical, 4)
    }
}

struct MockButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(configuration.isPressed ? 0.6 : 0.8))
            .foregroundColor(.white)
            .cornerRadius(6)
    }
}

struct MiniButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(configuration.isPressed ? 0.6 : 0.8))
            .foregroundColor(.white)
            .cornerRadius(4)
    }
}

// MARK: - Preview

struct CVMockControlView_Previews: PreviewProvider {
    static var previews: some View {
        CVMockControlView(
            mockPieces: .constant([]),
            onPiecesChanged: { _ in }
        )
        .padding()
        .background(Color.gray)
    }
}