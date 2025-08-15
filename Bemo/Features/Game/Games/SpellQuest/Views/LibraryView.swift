//
//  LibraryView.swift
//  Bemo
//
//  Album selection screen for SpellQuest
//

// WHAT: Allows players to select which puzzle albums to play
// ARCHITECTURE: View layer in MVVM-S
// USAGE: Shown after mode selection, before gameplay starts

import SwiftUI

struct LibraryView: View {
    let viewModel: SpellQuestGameViewModel
    @State private var selectedAlbums: Set<String> = []
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    HStack {
                        Button(action: {
                            viewModel.backToModeSelect()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(Color("AppPrimaryTextColor"))
                        }
                        
                        Spacer()
                        
                        Text("Select Albums")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color("AppPrimaryTextColor"))
                        
                        Spacer()
                        
                        // Placeholder for balance
                        Color.clear
                            .frame(width: 30, height: 30)
                    }
                    .padding(.horizontal)
                    
                    Text("Choose puzzle collections to play")
                        .font(.subheadline)
                        .foregroundColor(Color("AppPrimaryTextColor").opacity(0.7))
                }
                .padding(.top)
                .padding(.bottom, 20)
                
                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        // Installed Albums Section
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Installed Albums")
                                .font(.headline)
                                .foregroundColor(Color("AppPrimaryTextColor"))
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                ForEach(viewModel.installedAlbums) { album in
                                    AlbumRow(
                                        album: album,
                                        isSelected: selectedAlbums.contains(album.id),
                                        action: {
                                            toggleAlbum(album.id)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Discover More Section (disabled for Stage 1)
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Discover More")
                                .font(.headline)
                                .foregroundColor(Color("AppPrimaryTextColor"))
                                .padding(.horizontal)
                            
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title)
                                    .foregroundColor(Color("AppPrimaryTextColor").opacity(0.4))
                                
                                Text("More albums coming soon!")
                                    .font(.subheadline)
                                    .foregroundColor(Color("AppPrimaryTextColor").opacity(0.4))
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 100) // Space for button
                }
                
                Spacer(minLength: 0)
            }
            
            // Continue Button - Fixed at bottom
            VStack {
                Spacer()
                
                Button(action: {
                    viewModel.selectAlbums(selectedAlbums)
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedAlbums.isEmpty ? Color.gray : Color.blue)
                        )
                }
                .disabled(selectedAlbums.isEmpty)
                .padding(.horizontal)
                .padding(.bottom)
                .background(
                    Color(UIColor.systemBackground)
                        .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .edgesIgnoringSafeArea(.bottom)
    }
    
    private func toggleAlbum(_ albumId: String) {
        if selectedAlbums.contains(albumId) {
            selectedAlbums.remove(albumId)
        } else {
            selectedAlbums.insert(albumId)
        }
    }
}

private struct AlbumRow: View {
    let album: SpellQuestAlbum
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .green : Color("AppPrimaryTextColor").opacity(0.4))
                
                // Album info
                VStack(alignment: .leading, spacing: 4) {
                    Text(album.title)
                        .font(.headline)
                        .foregroundColor(Color("AppPrimaryTextColor"))
                    
                    Text("\(album.puzzles.count) puzzles")
                        .font(.caption)
                        .foregroundColor(Color("AppPrimaryTextColor").opacity(0.6))
                }
                
                Spacer()
                
                // Difficulty badge
                Text(album.difficulty.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(difficultyColor(album.difficulty))
                    )
                    .foregroundColor(.white)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func difficultyColor(_ difficulty: SpellQuestAlbum.DifficultyLevel) -> Color {
        switch difficulty {
        case .easy:
            return .green
        case .normal:
            return .orange
        case .hard:
            return .red
        }
    }
}