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
            if viewModel.uiState.navigationState == .editor {
                TangramEditorTopBar(viewModel: viewModel, delegate: viewModel.delegate)
                    .background(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                
                // State indicator - always visible under top bar
                Text(viewModel.currentStateDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.blue.opacity(0.1)))
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
            
            // Main content
            ZStack {
                switch viewModel.uiState.navigationState {
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
            if viewModel.uiState.navigationState == .editor {
                TangramEditorBottomBar(viewModel: viewModel)
                    .background(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: -2)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.uiState.navigationState)
        .sheet(isPresented: .init(
            get: { viewModel.uiState.showSaveDialog },
            set: { viewModel.uiState.showSaveDialog = $0 }
        )) {
            SavePuzzleDialog(viewModel: viewModel)
        }
        .toastOverlay(toastService: viewModel.toastService)
        .alert("Unsaved Changes", isPresented: $viewModel.showLibraryNavigationAlert) {
            Button("Save", role: .none) {
                viewModel.navigateToLibrary(saveChanges: true)
            }
            Button("Discard", role: .destructive) {
                viewModel.navigateToLibrary(saveChanges: false)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You have unsaved changes. What would you like to do?")
        }
    }
}

#Preview {
    TangramEditorContainerView(viewModel: .preview())
}