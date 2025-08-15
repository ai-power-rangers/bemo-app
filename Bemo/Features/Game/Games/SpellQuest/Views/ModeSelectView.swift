//
//  ModeSelectView.swift
//  Bemo
//
//  Game mode selection screen for SpellQuest
//

// WHAT: Presents four game mode options for player selection
// ARCHITECTURE: View layer in MVVM-S
// USAGE: First screen shown when SpellQuest launches

import SwiftUI

struct ModeSelectView: View {
    let viewModel: SpellQuestGameViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            // Title
            Text("Choose Your Quest")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Select a game mode to begin")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Mode cards
            VStack(spacing: 20) {
                ForEach(SpellQuestGameMode.allCases, id: \.self) { mode in
                    ModeCard(
                        mode: mode,
                        action: {
                            viewModel.selectMode(mode)
                        }
                    )
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top, 50)
    }
}

private struct ModeCard: View {
    let mode: SpellQuestGameMode
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                // Icon
                Image(systemName: mode.systemImage)
                    .font(.system(size: 30))
                    .foregroundColor(iconColor)
                    .frame(width: 50, height: 50)
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(cardBackground)
            .cornerRadius(15)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(ModeScaleButtonStyle())
    }
    
    private var iconColor: Color {
        switch mode {
        case .zen:
            return .green
        case .zenJunior:
            return .purple
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(Color(UIColor.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(iconColor.opacity(0.3), lineWidth: 1)
            )
    }
}

// Custom button style for press animation
private struct ModeScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
