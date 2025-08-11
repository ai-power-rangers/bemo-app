//
//  TangramDebugView.swift
//  Bemo
//
//  Debug view for testing Tangram game without CV input
//

// WHAT: Provides mock CV controls for testing Tangram gameplay
// ARCHITECTURE: Debug utility view, only included in debug builds
// USAGE: Conditionally included in TangramGameView for development/testing

#if DEBUG

import SwiftUI

struct TangramDebugView: View {
    @Binding var mockPieces: [RecognizedPiece]
    @Binding var showCVMock: Bool
    
    var body: some View {
        VStack {
            Toggle("Show CV Mock", isOn: $showCVMock)
                .padding()
            
            if showCVMock {
                CVMockControlView(mockPieces: $mockPieces)
                    .frame(height: 200)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .padding()
            }
        }
    }
}

/// Mock control view for simulating CV piece detection
struct CVMockControlView: View {
    @Binding var mockPieces: [RecognizedPiece]
    @State private var piecePositions: [String: CGPoint] = [:]
    @State private var pieceRotations: [String: Double] = [:]
    
    private let pieceTypes = TangramPieceType.allCases
    
    var body: some View {
        VStack {
            Text("Mock CV Controls")
                .font(.headline)
                .padding(.top)
            
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(pieceTypes, id: \.id) { pieceType in
                        pieceControlRow(for: pieceType)
                    }
                }
                .padding()
            }
            
            HStack {
                Button("Clear All") {
                    clearAllMockPieces()
                }
                .buttonStyle(.bordered)
                
                Button("Add All Random") {
                    addAllRandomPieces()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
    
    @ViewBuilder
    private func pieceControlRow(for pieceType: TangramPieceType) -> some View {
        HStack {
            Text(pieceType.displayName)
                .frame(width: 120, alignment: .leading)
            
            VStack {
                HStack {
                    Text("X:")
                    TextField("X", value: Binding<Double>(
                        get: { 
                            if let x = piecePositions[pieceType.rawValue]?.x {
                                return Double(x)
                            }
                            return 0
                        },
                        set: { newValue in
                            piecePositions[pieceType.rawValue] = CGPoint(
                                x: CGFloat(newValue),
                                y: piecePositions[pieceType.rawValue]?.y ?? 0
                            )
                            updateMockPiece(pieceType)
                        }
                    ), format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
                    
                    Text("Y:")
                    TextField("Y", value: Binding<Double>(
                        get: { 
                            if let y = piecePositions[pieceType.rawValue]?.y {
                                return Double(y)
                            }
                            return 0
                        },
                        set: { newValue in
                            piecePositions[pieceType.rawValue] = CGPoint(
                                x: piecePositions[pieceType.rawValue]?.x ?? 0,
                                y: CGFloat(newValue)
                            )
                            updateMockPiece(pieceType)
                        }
                    ), format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
                    
                    Text("R:")
                    TextField("Rotation", value: Binding<Double>(
                        get: { pieceRotations[pieceType.rawValue] ?? 0 },
                        set: { newValue in
                            pieceRotations[pieceType.rawValue] = newValue
                            updateMockPiece(pieceType)
                        }
                    ), format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
                }
            }
            
            Button("Add") {
                addMockPiece(pieceType)
            }
            .buttonStyle(.borderedProminent)
            
            Button("Remove") {
                removeMockPiece(pieceType)
            }
            .buttonStyle(.bordered)
        }
    }
    
    private func clearAllMockPieces() {
        mockPieces.removeAll()
        piecePositions.removeAll()
        pieceRotations.removeAll()
    }
    
    private func updateMockPiece(_ pieceType: TangramPieceType) {
        if let index = mockPieces.firstIndex(where: { $0.pieceTypeId == pieceType.rawValue }) {
            let position = piecePositions[pieceType.rawValue] ?? CGPoint(x: 300, y: 300)
            let rotation = pieceRotations[pieceType.rawValue] ?? 0
            
            mockPieces[index] = RecognizedPiece(
                id: pieceType.rawValue,
                pieceTypeId: pieceType.rawValue,
                position: position,
                rotation: rotation,
                velocity: CGVector(dx: 0, dy: 0),
                isMoving: false,
                confidence: 0.95,
                timestamp: Date(),
                frameNumber: 0
            )
        }
    }
    
    private func addMockPiece(_ pieceType: TangramPieceType) {
        let position = piecePositions[pieceType.rawValue] ?? CGPoint(x: 300, y: 300)
        let rotation = pieceRotations[pieceType.rawValue] ?? 0
        
        let mockPiece = RecognizedPiece(
            id: pieceType.rawValue,
            pieceTypeId: pieceType.rawValue,
            position: position,
            rotation: rotation,
            velocity: CGVector(dx: 0, dy: 0),
            isMoving: false,
            confidence: 0.95,
            timestamp: Date(),
            frameNumber: 0
        )
        
        // Remove existing piece of same type
        mockPieces.removeAll { $0.pieceTypeId == pieceType.rawValue }
        mockPieces.append(mockPiece)
    }
    
    private func removeMockPiece(_ pieceType: TangramPieceType) {
        mockPieces.removeAll { $0.pieceTypeId == pieceType.rawValue }
    }
    
    private func addAllRandomPieces() {
        mockPieces.removeAll()
        
        for (index, pieceType) in pieceTypes.enumerated() {
            let position = CGPoint(
                x: 200 + Double(index % 3) * 100,
                y: 200 + Double(index / 3) * 100
            )
            let rotation = Double.random(in: 0...360)
            
            piecePositions[pieceType.rawValue] = position
            pieceRotations[pieceType.rawValue] = rotation
            
            let mockPiece = RecognizedPiece(
                id: pieceType.rawValue,
                pieceTypeId: pieceType.rawValue,
                position: position,
                rotation: rotation,
                velocity: CGVector(dx: 0, dy: 0),
                isMoving: false,
                confidence: 0.95,
                timestamp: Date(),
                frameNumber: 0
            )
            
            mockPieces.append(mockPiece)
        }
    }
}

#endif