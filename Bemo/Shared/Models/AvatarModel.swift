//
//  AvatarModel.swift
//  Bemo
//
//  Avatar system for child profiles using SF Symbols
//

// WHAT: Defines available avatars and colors for child profiles using SF Symbols
// ARCHITECTURE: Shared model used across profile creation and display
// USAGE: Avatar.allAvatars for selection, Avatar.random() for default

import SwiftUI

struct Avatar: Identifiable, Equatable {
    let id = UUID()
    let symbol: String
    let color: Color
    let colorName: String // For storage
    
    // Get SF Symbol image
    var image: Image {
        Image(systemName: symbol)
    }
    
    // Display name for the avatar
    var displayName: String {
        Avatar.symbolNames[symbol] ?? "Avatar"
    }
}

extension Avatar {
    // Available SF Symbols for avatars (child-friendly animals and objects)
    static let availableSymbols = [
        // Animals
        "hare.fill",
        "tortoise.fill", 
        "bird.fill",
        "ant.fill",
        "ladybug.fill",
        "fish.fill",
        "pawprint.fill",
        
        // Nature
        "leaf.fill",
        "tree.fill",
        "flame.fill",
        "drop.fill",
        "snowflake",
        "sun.max.fill",
        "moon.fill",
        "star.fill",
        "cloud.fill",
        "bolt.fill",
        
        // Objects
        "heart.fill",
        "crown.fill",
        "sparkles",
        "balloon.fill",
        "gift.fill",
        "bell.fill",
        "flag.fill",
        "bookmark.fill",
        
        // Shapes & Fun
        "hexagon.fill",
        "triangle.fill",
        "diamond.fill",
        "seal.fill",
        "burst.fill",
        "wand.and.stars"
    ]
    
    // Friendly names for symbols
    static let symbolNames: [String: String] = [
        "hare.fill": "Bunny",
        "tortoise.fill": "Turtle",
        "bird.fill": "Bird",
        "ant.fill": "Ant",
        "ladybug.fill": "Ladybug",
        "fish.fill": "Fish",
        "pawprint.fill": "Paw",
        "leaf.fill": "Leaf",
        "tree.fill": "Tree",
        "flame.fill": "Fire",
        "drop.fill": "Water",
        "snowflake": "Snow",
        "sun.max.fill": "Sun",
        "moon.fill": "Moon",
        "star.fill": "Star",
        "cloud.fill": "Cloud",
        "bolt.fill": "Lightning",
        "heart.fill": "Heart",
        "crown.fill": "Crown",
        "sparkles": "Sparkles",
        "balloon.fill": "Balloon",
        "gift.fill": "Gift",
        "bell.fill": "Bell",
        "flag.fill": "Flag",
        "bookmark.fill": "Bookmark",
        "hexagon.fill": "Hexagon",
        "triangle.fill": "Triangle",
        "diamond.fill": "Diamond",
        "seal.fill": "Badge",
        "burst.fill": "Burst",
        "wand.and.stars": "Magic"
    ]
    
    // Available colors for avatars
    static let availableColors: [(color: Color, name: String)] = [
        (.blue, "blue"),
        (.purple, "purple"),
        (.pink, "pink"),
        (.red, "red"),
        (.orange, "orange"),
        (.yellow, "yellow"),
        (.green, "green"),
        (.mint, "mint"),
        (.teal, "teal"),
        (.cyan, "cyan"),
        (.indigo, "indigo"),
        (.brown, "brown")
    ]
    
    // Get all possible avatar combinations
    static var allAvatars: [Avatar] {
        var avatars: [Avatar] = []
        for symbol in availableSymbols {
            for colorInfo in availableColors {
                avatars.append(Avatar(
                    symbol: symbol,
                    color: colorInfo.color,
                    colorName: colorInfo.name
                ))
            }
        }
        return avatars
    }
    
    // Get avatars grouped by symbol (for organized selection)
    static func avatarsGroupedBySymbol() -> [(symbol: String, avatars: [Avatar])] {
        var grouped: [(symbol: String, avatars: [Avatar])] = []
        
        for symbol in availableSymbols {
            let avatarsForSymbol = availableColors.map { colorInfo in
                Avatar(symbol: symbol, color: colorInfo.color, colorName: colorInfo.name)
            }
            grouped.append((symbol: symbol, avatars: avatarsForSymbol))
        }
        
        return grouped
    }
    
    // Get a random avatar
    static func random() -> Avatar {
        let randomSymbol = availableSymbols.randomElement() ?? "star.fill"
        let randomColor = availableColors.randomElement() ?? (.blue, "blue")
        return Avatar(
            symbol: randomSymbol,
            color: randomColor.color,
            colorName: randomColor.name
        )
    }
    
    // Create avatar from stored strings
    static func from(symbol: String, colorName: String) -> Avatar {
        let color = availableColors.first(where: { $0.name == colorName })?.color ?? .blue
        return Avatar(
            symbol: symbol,
            color: color,
            colorName: colorName
        )
    }
    
    // Convert color name string to Color
    static func colorFromName(_ name: String) -> Color {
        availableColors.first(where: { $0.name == name })?.color ?? .blue
    }
}

// View component for displaying an avatar
struct AvatarView: View {
    let avatar: Avatar
    let size: CGFloat
    
    init(avatar: Avatar, size: CGFloat = 40) {
        self.avatar = avatar
        self.size = size
    }
    
    init(symbol: String, colorName: String, size: CGFloat = 40) {
        self.avatar = Avatar.from(symbol: symbol, colorName: colorName)
        self.size = size
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(avatar.color.opacity(0.2))
                .frame(width: size, height: size)
            
            avatar.image
                .font(.system(size: size * 0.5))
                .foregroundColor(avatar.color)
        }
    }
}

// Avatar picker component
struct AvatarPicker: View {
    @Binding var selectedAvatar: Avatar
    @State private var selectedSymbol: String
    @State private var selectedColor: Color
    @State private var selectedColorName: String
    
    let columns = [
        GridItem(.adaptive(minimum: 60))
    ]
    
    init(selectedAvatar: Binding<Avatar>) {
        self._selectedAvatar = selectedAvatar
        self._selectedSymbol = State(initialValue: selectedAvatar.wrappedValue.symbol)
        self._selectedColor = State(initialValue: selectedAvatar.wrappedValue.color)
        self._selectedColorName = State(initialValue: selectedAvatar.wrappedValue.colorName)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Preview
            VStack(spacing: 8) {
                AvatarView(avatar: selectedAvatar, size: 80)
                Text(selectedAvatar.displayName)
                    .font(.headline)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Symbol Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose Character")
                    .font(.headline)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Avatar.availableSymbols, id: \.self) { symbol in
                            Button(action: {
                                selectedSymbol = symbol
                                updateAvatar()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(selectedSymbol == symbol ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: symbol)
                                        .font(.system(size: 24))
                                        .foregroundColor(selectedSymbol == symbol ? .blue : .gray)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            // Color Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose Color")
                    .font(.headline)
                
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Avatar.availableColors, id: \.name) { colorInfo in
                        Button(action: {
                            selectedColor = colorInfo.color
                            selectedColorName = colorInfo.name
                            updateAvatar()
                        }) {
                            Circle()
                                .fill(colorInfo.color)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColorName == colorInfo.name ? Color.black : Color.clear, lineWidth: 3)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private func updateAvatar() {
        selectedAvatar = Avatar(
            symbol: selectedSymbol,
            color: selectedColor,
            colorName: selectedColorName
        )
    }
}