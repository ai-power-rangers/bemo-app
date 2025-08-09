//
//  AutomatedPipelineTestView.swift
//  Bemo
//
//  Test view to visualize automated pipeline puzzle outputs
//

// WHAT: SwiftUI view to test and visualize automated pipeline puzzle generation
// ARCHITECTURE: View in MVVM-S pattern for testing pipeline outputs
// USAGE: Launch from TangramCV game to test automated puzzle loading

import SwiftUI
import SpriteKit

struct AutomatedPipelineTestView: View {
    @State private var loadedPuzzles: [GamePuzzleData] = []
    @State private var selectedPuzzle: GamePuzzleData?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingPuzzleDetails = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Automated Pipeline Test")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Load button
            Button(action: loadTestPuzzles) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.down.doc.fill")
                    }
                    Text("Load Pipeline Puzzles")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isLoading)
            
            // Error message
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Loaded puzzles list
            if !loadedPuzzles.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Loaded Puzzles:")
                        .font(.headline)
                    
                    ForEach(loadedPuzzles) { puzzle in
                        Button(action: { selectPuzzle(puzzle) }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(puzzle.name)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Text("Category: \(puzzle.category) | Difficulty: \(puzzle.difficulty)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedPuzzle?.id == puzzle.id ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            
            // Visualization area
            if let puzzle = selectedPuzzle {
                VStack {
                    Text("Visualizing: \(puzzle.name)")
                        .font(.headline)
                    
                    // Simple visualization using the transform data
                    PuzzleVisualizationView(puzzle: puzzle)
                        .frame(height: 300)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    
                    // Show details button
                    Button("Show Puzzle Details") {
                        showingPuzzleDetails = true
                    }
                    .padding()
                }
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingPuzzleDetails) {
            if let puzzle = selectedPuzzle {
                PuzzleDetailsView(puzzle: puzzle)
            }
        }
    }
    
    private func loadTestPuzzles() {
        isLoading = true
        errorMessage = nil
        
        Task {
            // Try loading from the yiran-tests directory
            let testPaths = [
                "/Users/mitchellwhite/Code/bemo-app/.mitch-docs/yiran-tests/cat_fixed_separation.json",
                "/Users/mitchellwhite/Code/bemo-app/.mitch-docs/yiran-tests/house_fixed_separation.json"
            ]
            
            var puzzles: [GamePuzzleData] = []
            
            for path in testPaths {
                if let puzzle = await AutomatedPipelineLoader.loadFromFile(at: path) {
                    puzzles.append(puzzle)
                }
            }
            
            await MainActor.run {
                if puzzles.isEmpty {
                    errorMessage = "No puzzles could be loaded. Check file paths."
                } else {
                    loadedPuzzles = puzzles
                    selectedPuzzle = puzzles.first
                }
                isLoading = false
            }
        }
    }
    
    private func selectPuzzle(_ puzzle: GamePuzzleData) {
        selectedPuzzle = puzzle
    }
}

// Simple visualization of the puzzle pieces
struct PuzzleVisualizationView: View {
    let puzzle: GamePuzzleData
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(puzzle.targetPieces.enumerated()), id: \.offset) { index, piece in
                    PipelineTestPieceShape(piece: piece)
                        .fill(pieceColor(for: piece.pieceType))
                        .overlay(
                            PipelineTestPieceShape(piece: piece)
                                .stroke(Color.black, lineWidth: 1)
                        )
                        .scaleEffect(0.3) // Scale down for visualization
                        .position(
                            x: piece.transform.tx * 0.3 + geometry.size.width / 2,
                            y: piece.transform.ty * 0.3 + geometry.size.height / 2
                        )
                }
            }
        }
    }
    
    private func pieceColor(for type: TangramPieceType) -> Color {
        switch type {
        case .smallTriangle1: return .red
        case .smallTriangle2: return .blue
        case .mediumTriangle: return .orange
        case .largeTriangle1: return .green
        case .largeTriangle2: return .yellow
        case .square: return .purple
        case .parallelogram: return .pink
        }
    }
}

// Custom shape for drawing pieces - renamed to avoid conflict
struct PipelineTestPieceShape: Shape {
    let piece: GamePuzzleData.TargetPiece
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Get vertices for the piece type
        let vertices = getVertices(for: piece.pieceType)
        
        // Apply transform
        let transformed = vertices.map { vertex in
            CGPoint(
                x: vertex.x * piece.transform.a + vertex.y * piece.transform.c,
                y: vertex.x * piece.transform.b + vertex.y * piece.transform.d
            )
        }
        
        if let first = transformed.first {
            path.move(to: first)
            for vertex in transformed.dropFirst() {
                path.addLine(to: vertex)
            }
            path.closeSubpath()
        }
        
        return path
    }
    
    private func getVertices(for type: TangramPieceType) -> [CGPoint] {
        let scale: CGFloat = 50.0
        switch type {
        case .smallTriangle1, .smallTriangle2:
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: scale, y: 0),
                CGPoint(x: 0, y: scale)
            ]
        case .mediumTriangle:
            let s = scale * sqrt(2)
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: s, y: 0),
                CGPoint(x: 0, y: s)
            ]
        case .largeTriangle1, .largeTriangle2:
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: scale * 2, y: 0),
                CGPoint(x: 0, y: scale * 2)
            ]
        case .square:
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: scale, y: 0),
                CGPoint(x: scale, y: scale),
                CGPoint(x: 0, y: scale)
            ]
        case .parallelogram:
            let s = scale / sqrt(2)
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: scale, y: 0),
                CGPoint(x: scale + s, y: s),
                CGPoint(x: s, y: s)
            ]
        }
    }
}

// Details view showing raw data
struct PuzzleDetailsView: View {
    let puzzle: GamePuzzleData
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    // Basic info
                    Group {
                        Text("ID: \(puzzle.id)")
                        Text("Name: \(puzzle.name)")
                        Text("Category: \(puzzle.category)")
                        Text("Difficulty: \(puzzle.difficulty)")
                    }
                    .font(.system(.body, design: .monospaced))
                    
                    Divider()
                    
                    // Pieces info
                    Text("Pieces (\(puzzle.targetPieces.count)):")
                        .font(.headline)
                    
                    ForEach(Array(puzzle.targetPieces.enumerated()), id: \.offset) { index, piece in
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Piece \(index + 1): \(piece.pieceType.rawValue)")
                                .fontWeight(.semibold)
                            Text("Position: (\(Int(piece.transform.tx)), \(Int(piece.transform.ty)))")
                            Text("Rotation: \(Int(piece.rotation))°")
                            Text("Transform Matrix:")
                            Text("  [\(String(format: "%.3f", piece.transform.a)), \(String(format: "%.3f", piece.transform.b))]")
                            Text("  [\(String(format: "%.3f", piece.transform.c)), \(String(format: "%.3f", piece.transform.d))]")
                        }
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Mock CV output
                    Text("Mock CV Output:")
                        .font(.headline)
                        .padding(.top)
                    
                    let cvOutput = AutomatedPipelineLoader.generateMockCVOutput(from: puzzle)
                    if let jsonData = try? JSONSerialization.data(withJSONObject: cvOutput, options: .prettyPrinted),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        ScrollView(.horizontal) {
                            Text(jsonString)
                                .font(.system(.caption2, design: .monospaced))
                                .padding()
                                .background(Color.black.opacity(0.05))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Puzzle Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct AutomatedPipelineTestView_Previews: PreviewProvider {
    static var previews: some View {
        AutomatedPipelineTestView()
    }
}