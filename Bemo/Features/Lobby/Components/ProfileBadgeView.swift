//
//  ProfileBadgeView.swift
//  Bemo
//
//  Displays user profile badge with initial or avatar
//

// WHAT: A circular badge showing the user's initial or avatar image
// ARCHITECTURE: Reusable UI component used in GameLobbyView header
// USAGE: ProfileBadgeView(name: "John", avatar: nil)

import SwiftUI

struct ProfileBadgeView: View {
    let name: String?
    let avatarSymbol: String?
    let avatarColor: String?
    let size: CGFloat
    
    init(name: String? = nil, avatarSymbol: String? = nil, avatarColor: String? = nil, size: CGFloat = 40) {
        self.name = name
        self.avatarSymbol = avatarSymbol
        self.avatarColor = avatarColor
        self.size = size
    }
    
    private var displayInitial: String {
        guard let name = name, !name.isEmpty else {
            return "?"
        }
        return String(name.prefix(1)).uppercased()
    }
    
    var body: some View {
        if let symbol = avatarSymbol, let colorName = avatarColor {
            // Use the actual avatar
            AvatarView(
                symbol: symbol,
                colorName: colorName,
                size: size
            )
        } else {
            // Fallback to initials
            ZStack {
                Circle()
                    .fill(BemoTheme.Colors.primary)
                    .frame(width: size, height: size)
                
                Text(displayInitial)
                    .foregroundColor(.white)
                    .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ProfileBadgeView(name: "Alice")
        ProfileBadgeView(name: "Bob", size: 60)
        ProfileBadgeView(name: nil)
        ProfileBadgeView(name: "Emma", avatarSymbol: "star.fill", avatarColor: "purple")
    }
    .padding()
}