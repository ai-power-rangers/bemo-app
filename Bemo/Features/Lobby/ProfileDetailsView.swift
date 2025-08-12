//
//  ProfileDetailsView.swift
//  Bemo
//
//  Sheet view showing current child profile details with option to switch profiles
//

// WHAT: Modal sheet displaying active child's profile information, stats, and profile management options
// ARCHITECTURE: SwiftUI View component presented from GameLobbyView. Displays ProfileService data.
// USAGE: Shown when profile badge is tapped. Provides profile info, achievements, and switch profile option.

import SwiftUI

struct ProfileDetailsView: View {
    let profile: UserProfile
    let onSwitchProfile: () -> Void
    let onDismiss: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private var level: Int {
        (profile.totalXP / 100) + 1
    }
    
    private var xpToNextLevel: Int {
        let nextLevelXP = (level) * 100
        return nextLevelXP - profile.totalXP
    }
    
    private var progressToNextLevel: Double {
        let currentLevelXP = (level - 1) * 100
        let nextLevelXP = level * 100
        let progressXP = profile.totalXP - currentLevelXP
        let neededXP = nextLevelXP - currentLevelXP
        return Double(progressXP) / Double(neededXP)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeaderSection
                    
                    // Stats Section
                    statsSection
                    
                    // Progress Section
                    progressSection
                    
                    // Settings Section
                    settingsSection
                    
                    // Switch Profile Button
                    switchProfileButton
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private var profileHeaderSection: some View {
        VStack(spacing: 16) {
            // Avatar - using the actual avatar from profile
            AvatarView(
                avatar: Avatar(
                    symbol: profile.avatarSymbol,
                    color: Avatar.colorFromName(profile.avatarColor),
                    colorName: profile.avatarColor
                ),
                size: 100
            )
            
            // Name and Level
            VStack(spacing: 8) {
                Text(profile.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 14))
                    Text("Level \(level)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stats")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                StatCard(
                    icon: "star.fill",
                    iconColor: .yellow,
                    title: "Total XP",
                    value: "\(profile.totalXP)"
                )
                
                StatCard(
                    icon: "person.fill",
                    iconColor: .blue,
                    title: "Age",
                    value: "\(profile.age) years"
                )
                
                StatCard(
                    icon: "calendar",
                    iconColor: .green,
                    title: "Gender",
                    value: profile.gender
                )
            }
        }
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Level Progress")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Level \(level)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Level \(level + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: geometry.size.width * progressToNextLevel, height: 12)
                    }
                }
                .frame(height: 12)
                
                Text("\(xpToNextLevel) XP to next level")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preferences")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 0) {
                PreferenceRow(
                    icon: "speaker.wave.2.fill",
                    title: "Sound",
                    value: profile.preferences.soundEnabled ? "On" : "Off",
                    valueColor: profile.preferences.soundEnabled ? .green : .secondary
                )
                
                Divider()
                
                PreferenceRow(
                    icon: "music.note",
                    title: "Music",
                    value: profile.preferences.musicEnabled ? "On" : "Off",
                    valueColor: profile.preferences.musicEnabled ? .green : .secondary
                )
                
                Divider()
                
                PreferenceRow(
                    icon: "gauge.with.dots.needle.33percent",
                    title: "Difficulty",
                    value: profile.preferences.difficultySetting.rawValue.capitalized,
                    valueColor: .primary
                )
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var switchProfileButton: some View {
        Button(action: {
            dismiss()
            // Small delay to ensure sheet dismisses before showing modal
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onSwitchProfile()
            }
        }) {
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 18))
                Text("Switch Profile")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(iconColor)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct PreferenceRow: View {
    let icon: String
    let title: String
    let value: String
    let valueColor: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .foregroundColor(valueColor)
        }
        .padding()
    }
}

// MARK: - Previews

struct ProfileDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileDetailsView(
            profile: UserProfile(
                id: "1",
                userId: "parent1",
                name: "Emma",
                age: 7,
                gender: "Female",
                avatarSymbol: "star.fill",
                avatarColor: "yellow",
                totalXP: 450,
                preferences: UserPreferences()
            ),
            onSwitchProfile: {},
            onDismiss: {}
        )
    }
}