//
//  SavePuzzleDialog.swift
//  Bemo
//
//  Enhanced save dialog for tangram puzzles with metadata
//

import SwiftUI

struct SavePuzzleDialog: View {
    @Bindable var viewModel: TangramEditorViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var puzzleName: String = ""
    @State private var selectedCategory: PuzzleCategory = .custom
    @State private var selectedDifficulty: PuzzleDifficulty = .medium
    @State private var tags: String = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isDeveloperMode = false  // Toggle for developer mode
    
    var body: some View {
        NavigationView {
            Form {
                // Name Section
                Section(header: Text("Puzzle Name")) {
                    TextField("Enter puzzle name", text: $puzzleName)
                        .textFieldStyle(.roundedBorder)
                    
                    if puzzleName.isEmpty {
                        Text("A name is required to save the puzzle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Category Section
                Section(header: Text("Category")) {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(PuzzleCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Difficulty Section
                Section(header: Text("Difficulty")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            ForEach(PuzzleDifficulty.allCases, id: \.self) { difficulty in
                                Button(action: { selectedDifficulty = difficulty }) {
                                    VStack(spacing: 4) {
                                        HStack(spacing: 2) {
                                            ForEach(1...5, id: \.self) { star in
                                                Image(systemName: star <= difficulty.rawValue ? "star.fill" : "star")
                                                    .font(.caption2)
                                                    .foregroundColor(
                                                        selectedDifficulty == difficulty ? .orange : .gray
                                                    )
                                            }
                                        }
                                        Text(difficulty.displayName)
                                            .font(.caption2)
                                            .foregroundColor(
                                                selectedDifficulty == difficulty ? .primary : .secondary
                                            )
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedDifficulty == difficulty ? 
                                                  Color(.systemGray5) : Color.clear)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                // Tags Section (Optional)
                Section(header: Text("Tags (Optional)")) {
                    TextField("Enter tags separated by commas", text: $tags)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("Tags help with searching and organizing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Developer Mode Section (for creating bundled puzzles)
                #if DEBUG
                Section(header: Text("Developer Options")) {
                    Toggle("Save as Official Puzzle", isOn: $isDeveloperMode)
                    
                    if isDeveloperMode {
                        Text("This puzzle will be marked as an official puzzle and won't be editable by parents")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                #endif
                
                // Puzzle Info
                Section(header: Text("Puzzle Information")) {
                    HStack {
                        Text("Pieces")
                        Spacer()
                        Text("\(viewModel.puzzle.pieces.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Connections")
                        Spacer()
                        Text("\(viewModel.puzzle.connections.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        if viewModel.validationState.isValid {
                            Label("Valid", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Label("Invalid", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if isDeveloperMode {
                        HStack {
                            Text("Source")
                            Spacer()
                            Label("Official", systemImage: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Save Puzzle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await savePuzzle()
                        }
                    }
                    .disabled(puzzleName.isEmpty || isSaving)
                }
            }
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Saving...")
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(radius: 4)
                        }
                }
            }
        }
        .onAppear {
            // Pre-fill with existing data if editing
            puzzleName = viewModel.puzzle.name
            selectedCategory = viewModel.puzzle.category
            selectedDifficulty = viewModel.puzzle.difficulty
            tags = viewModel.puzzle.tags.joined(separator: ", ")
        }
        .alert("Save Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func savePuzzle() async {
        isSaving = true
        
        // Update puzzle with dialog values
        viewModel.puzzle.name = puzzleName
        viewModel.puzzle.category = selectedCategory
        viewModel.puzzle.difficulty = selectedDifficulty
        
        // Set source based on developer mode toggle
        viewModel.puzzle.source = isDeveloperMode ? .bundled : .user
        
        // Parse and set tags
        if !tags.isEmpty {
            viewModel.puzzle.tags = tags
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        
        do {
            try await viewModel.save()
            dismiss()
            
            // After successful save, return to library
            viewModel.navigationState = .library
        } catch {
            errorMessage = "Failed to save puzzle: \(error.localizedDescription)"
            showError = true
            isSaving = false
        }
    }
}

#Preview {
    SavePuzzleDialog(viewModel: TangramEditorViewModel(puzzle: nil))
}