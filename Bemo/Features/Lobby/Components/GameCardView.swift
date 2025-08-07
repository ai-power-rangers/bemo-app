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
            VStack(spacing: BemoTheme.Spacing.small) {
                // Game Icon
                Image(systemName: game.iconName)
                    .font(.system(size: 48))
                    .foregroundColor(cardColors.foreground)
                    .frame(height: 60)
                
                // Game Title
                Text(game.title)
                    .font(BemoTheme.font(for: .body))
                    .foregroundColor(cardColors.foreground)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .padding(BemoTheme.Spacing.medium)
            .background(cardColors.background)
            .cornerRadius(BemoTheme.CornerRadius.large)
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