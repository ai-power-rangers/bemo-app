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
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 30) {
                    // Title
                    Text("Choose Your Quest")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color("AppPrimaryTextColor"))
                        .padding(.top, 50)
                    
                    Text("Select a game mode to begin")
                        .font(.subheadline)
                        .foregroundColor(Color("AppPrimaryTextColor").opacity(0.7))
                    
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
                    
                    Spacer(minLength: 50)
                }
                .frame(minHeight: geometry.size.height)
            }
        }
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
                        .foregroundColor(Color("AppPrimaryTextColor"))
                    
                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(Color("AppPrimaryTextColor").opacity(0.6))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 20))
                    .foregroundColor(Color("AppPrimaryTextColor").opacity(0.4))
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
            .fill(Color.white)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
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
