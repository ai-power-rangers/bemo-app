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
            GeometryReader { geometry in
                let cardSize = min(geometry.size.width, geometry.size.height)
                let iconSize = cardSize * 0.35
                let fontSize = cardSize * 0.11
                let verticalPadding = cardSize * 0.15
                let spacing = cardSize * 0.12
                
                VStack(spacing: spacing) {
                    // Game Icon
                    if game.hasCustomIcon {
                        Image(game.iconName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: iconSize, height: iconSize)
                    } else {
                        Image(systemName: game.iconName)
                            .font(.system(size: iconSize * 0.83, weight: .medium))
                            .foregroundColor(Color(hex: "#666666"))
                            .frame(width: iconSize, height: iconSize)
                    }
                    
                    // Game Title
                    Text(game.title)
                        .font(.system(size: fontSize, weight: .semibold))
                        .foregroundColor(Color(hex: "#333333"))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, verticalPadding)
            }
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
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
    let hasCustomIcon: Bool
    let colorScheme: Int
    let isLocked: Bool
    
    init(game: Game, colorScheme: Int = 1, isLocked: Bool = false) {
        self.id = game.id
        self.game = game
        self.devTool = nil
        self.title = game.title
        let iconInfo = Self.iconInfoForGame(game.id)
        self.iconName = iconInfo.name
        self.hasCustomIcon = iconInfo.isCustom
        self.colorScheme = colorScheme
        self.isLocked = isLocked
    }
    
    init(devTool: DevTool, colorScheme: Int = 1, isLocked: Bool = false) {
        self.id = devTool.id
        self.game = nil
        self.devTool = devTool
        self.title = devTool.title
        let iconInfo = Self.iconInfoForGame(devTool.id)
        self.iconName = iconInfo.name
        self.hasCustomIcon = iconInfo.isCustom
        self.colorScheme = colorScheme
        self.isLocked = isLocked
    }
    
    // Direct initializer for custom items (like "Coming Soon")
    init(id: String, game: Game?, devTool: DevTool?, title: String, iconName: String, hasCustomIcon: Bool, colorScheme: Int = 1, isLocked: Bool = false) {
        self.id = id
        self.game = game
        self.devTool = devTool
        self.title = title
        self.iconName = iconName
        self.hasCustomIcon = hasCustomIcon
        self.colorScheme = colorScheme
        self.isLocked = isLocked
    }
    
    private static func iconInfoForGame(_ gameId: String) -> (name: String, isCustom: Bool) {
        switch gameId {
        case "tangram":
            return ("tangram_icon", true)
        case "aquamath":
            return ("icons8-accounting-100", true)
        case "spellquest":
            return ("icons8-toys-100", true)
        case "animation_lab":
            return ("icons8-chemistry-100", true)
        case "coming_soon":
            return ("icons8-surprise-box-100", true)
        case "tangram-editor":
            return ("pencil.and.ruler.fill", false)
        case "numbers":
            return ("number", false)
        case "letters":
            return ("textformat.abc", false)
        default:
            return ("gamecontroller", false)
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