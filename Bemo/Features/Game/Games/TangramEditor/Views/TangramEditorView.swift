//
//  TangramEditorView.swift
//  Bemo
//
//  Main view for the tangram puzzle editor
//

import SwiftUI

struct TangramEditorView: View {
    @StateObject private var viewModel = TangramEditorViewModel()
    
    var body: some View {
        VStack {
            Text("Tangram Editor")
                .font(.largeTitle)
                .padding()
            
            Text("Puzzle: \(viewModel.puzzle.name)")
                .font(.headline)
            
            if viewModel.validationState.isValid {
                Text("✅ Valid")
                    .foregroundColor(.green)
            } else {
                VStack(alignment: .leading) {
                    Text("❌ Invalid:")
                        .foregroundColor(.red)
                    ForEach(viewModel.validationState.errors, id: \.self) { error in
                        Text("• \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Spacer()
            
            // TODO: Add piece canvas
            // TODO: Add piece palette
            // TODO: Add connection tools
            
            Text("UI Implementation Coming Soon")
                .foregroundColor(.gray)
                .italic()
            
            Spacer()
        }
        .padding()
        .onAppear {
            viewModel.validate()
        }
    }
}