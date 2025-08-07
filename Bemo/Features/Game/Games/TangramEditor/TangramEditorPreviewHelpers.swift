//
//  TangramEditorPreviewHelpers.swift
//  Bemo
//
//  Helper utilities for SwiftUI previews in Tangram Editor
//

import Foundation
import SwiftUI

// MARK: - Preview Helpers

#if DEBUG
extension TangramEditorDependencyContainer {
    /// Creates a dependency container suitable for SwiftUI previews
    @MainActor
    static func preview() -> TangramEditorDependencyContainer {
        return TangramEditorDependencyContainer()
    }
}

extension TangramEditorViewModel {
    /// Creates a view model suitable for SwiftUI previews
    @MainActor
    static func preview(puzzle: TangramPuzzle? = nil) -> TangramEditorViewModel {
        let container = TangramEditorDependencyContainer.preview()
        return container.makeViewModel(puzzle: puzzle)
    }
}
#endif