//
//  GameCardView.swift
//  Bemo
//
//  Game card tile for displaying games in the lobby
//

// WHAT: Card component displaying game icon and title with colored background
// ARCHITECTURE: UI component used in GameLobbyView grid
// USAGE: GameCardView(game: gameItem, onTap: { })

import SwiftUI

struct GameCardView: View {
    let game: GameItem
    let onTap: () -> Void
    
    private var cardColors: (background: Color, foreground: Color) {
        switch game.colorScheme {
        case 1:
            return (BemoTheme.Colors.card1Background, BemoTheme.Colors.card1Foreground)
        case 2:
            return (BemoTheme.Colors.card2Background, BemoTheme.Colors.card2Foreground)
        case 3:
            return (BemoTheme.Colors.card3Background, BemoTheme.Colors.card3Foreground)
        case 4:
            return (BemoTheme.Colors.card4Background, BemoTheme.Colors.card4Foreground)
        default:
            return (BemoTheme.Colors.card1Background, BemoTheme.Colors.card1Foreground)
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Organic rounded shape matching website style
                RoundedRectangle(cornerRadius: 30)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [
                            cardColors.background,
                            cardColors.background.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(cardColors.foreground.opacity(0.3), lineWidth: 2)
                    )
                    .shadow(color: cardColors.foreground.opacity(0.2), radius: 12, x: 0, y: 6)
                
                VStack(spacing: 20) {
                    // Game Icon
                    Image(systemName: game.iconName)
                        .font(.system(size: 48, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .background(
                            Circle()
                                .fill(cardColors.foreground.opacity(0.9))
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    // Game Title
                    Text(game.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
}

// MARK: - Game Item Model

struct GameItem: Identifiable {
    let id: String
    let game: Game?
    let devTool: DevTool?
    let title: String
    let iconName: String
    let colorScheme: Int
    let isLocked: Bool
    
    init(game: Game, colorScheme: Int = 1, isLocked: Bool = false) {
        self.id = game.id
        self.game = game
        self.devTool = nil
        self.title = game.title
        self.iconName = Self.iconForGame(game.id)
        self.colorScheme = colorScheme
        self.isLocked = isLocked
    }
    
    init(devTool: DevTool, colorScheme: Int = 1, isLocked: Bool = false) {
        self.id = devTool.id
        self.game = nil
        self.devTool = devTool
        self.title = devTool.title
        self.iconName = Self.iconForGame(devTool.id)
        self.colorScheme = colorScheme
        self.isLocked = isLocked
    }
    
    private static func iconForGame(_ gameId: String) -> String {
        switch gameId {
        case "tangram":
            return "square.grid.2x2"
        case "tangram-editor":
            return "pencil.and.ruler.fill"
        case "numbers":
            return "number"
        case "letters":
            return "textformat.abc"
        default:
            return "gamecontroller"
        }
    }
}

// MARK: - Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        // Create mock games for preview
        let tangramGame = TangramGame()
        
        HStack(spacing: 20) {
            GameCardView(
                game: GameItem(game: tangramGame, colorScheme: 1),
                onTap: { print("Game 1 tapped") }
            )
            
            GameCardView(
                game: GameItem(game: tangramGame, colorScheme: 2),
                onTap: { print("Game 2 tapped") }
            )
        }
        .padding()
    }
    .background(BemoTheme.Colors.background)
}