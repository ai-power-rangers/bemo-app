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
        }
    }
}

#Preview {
    TangramEditorContainerView(viewModel: TangramEditorViewModel(puzzle: nil))
}