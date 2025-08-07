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
        NavigationStack {
            VStack(spacing: 0) {
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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Show different toolbar items based on navigation state
                if viewModel.uiState.navigationState == .library {
                    // Library toolbar items
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            // Exit to game lobby - need to call quit on the game delegate
                            // This will be handled through the viewModel
                            viewModel.requestQuit()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16))
                                Text("Back")
                                    .font(.system(size: 16))
                            }
                        }
                    }
                    
                    ToolbarItem(placement: .principal) {
                        Text("Puzzle Library")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { viewModel.createNewPuzzle() }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    TangramEditorContainerView(viewModel: .preview())
}