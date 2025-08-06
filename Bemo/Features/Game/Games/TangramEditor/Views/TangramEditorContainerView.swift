//
//  TangramEditorContainerView.swift
//  Bemo
//
//  Container view managing navigation between library and editor
//

import SwiftUI

struct TangramEditorContainerView: View {
    @Bindable var viewModel: TangramEditorViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            if viewModel.navigationState == .editor {
                TangramEditorTopBar(viewModel: viewModel, delegate: viewModel.delegate)
                    .background(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
            }
            
            // Main content
            ZStack {
                switch viewModel.navigationState {
                case .library:
                    PuzzleLibraryView(viewModel: viewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .trailing)
                        ))
                    
                case .editor:
                    TangramEditorCanvasView(viewModel: viewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                    
                case .settings:
                    // Settings view placeholder - to be implemented
                    Text("Settings")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGroupedBackground))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom bar
            if viewModel.navigationState == .editor {
                TangramEditorBottomBar(viewModel: viewModel)
                    .background(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: -2)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.navigationState)
        .sheet(isPresented: .init(
            get: { viewModel.showSaveDialog },
            set: { viewModel.showSaveDialog = $0 }
        )) {
            SavePuzzleDialog(viewModel: viewModel)
        }
    }
}

#Preview {
    TangramEditorContainerView(viewModel: .preview())
}