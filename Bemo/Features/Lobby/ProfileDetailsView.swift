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
    @State var profile: UserProfile
    let profileService: ProfileService?
    let audioService: AudioService?
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
            ZStack {
                Color("AppBackground")
                    .ignoresSafeArea()
                
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
            .onAppear {
                // Configure navigation bar appearance with AppBackground color
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor(Color("AppBackground"))
                appearance.titleTextAttributes = [.foregroundColor: UIColor(Color("AppPrimaryTextColor"))]
                appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color("AppPrimaryTextColor"))]
                
                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance
                UINavigationBar.appearance().compactAppearance = appearance
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
                    .foregroundColor(Color("AppPrimaryTextColor"))
                
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 14))
                    Text("Level \(level)")
                        .font(.headline)
                        .foregroundColor(Color("AppPrimaryTextColor"))
                }
            }
        }
    }
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stats")
                .font(.headline)
                .foregroundColor(Color("AppPrimaryTextColor"))
            
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
                .foregroundColor(Color("AppPrimaryTextColor"))
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Level \(level)")
                        .font(.caption)
                        .foregroundColor(Color("AppPrimaryTextColor"))
                    
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
                    .foregroundColor(Color("AppPrimaryTextColor"))
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
        }
    }
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preferences")
                .font(.headline)
                .foregroundColor(Color("AppPrimaryTextColor"))
            
            VStack(spacing: 0) {
                // Sound Effects Toggle
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    Text("Sound Effects")
                        .font(.body)
                        .foregroundColor(Color("AppPrimaryTextColor"))
                    
                    Spacer()
                    
                    Toggle("", isOn: $profile.preferences.soundEnabled)
                        .labelsHidden()
                        .onChange(of: profile.preferences.soundEnabled) { _, newValue in
                            // Update AudioService
                            audioService?.isSoundEffectsEnabled = newValue
                            // Save preferences
                            savePreferences()
                        }
                }
                .padding()
                
                Divider()
                
                // Background Music Toggle
                HStack {
                    Image(systemName: "music.note")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    Text("Background Music")
                        .font(.body)
                        .foregroundColor(Color("AppPrimaryTextColor"))
                    
                    Spacer()
                    
                    Toggle("", isOn: $profile.preferences.musicEnabled)
                        .labelsHidden()
                        .onChange(of: profile.preferences.musicEnabled) { _, newValue in
                            // Update AudioService
                            audioService?.isBackgroundMusicEnabled = newValue
                            // Save preferences
                            savePreferences()
                        }
                }
                .padding()
                
                Divider()
                
                PreferenceRow(
                    icon: "gauge.with.dots.needle.33percent",
                    title: "Difficulty",
                    value: profile.preferences.difficultySetting.rawValue.capitalized,
                    valueColor: Color("AppPrimaryTextColor")
                )
            }
            .background(Color.white)
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
    
    // MARK: - Helper Methods
    
    private func savePreferences() {
        // Update the profile in ProfileService
        profileService?.updatePreferences(profile.preferences, for: profile.id)
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
                .foregroundColor(Color("AppPrimaryTextColor"))
            
            Text(title)
                .font(.caption)
                .foregroundColor(Color("AppPrimaryTextColor"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white)
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
                .foregroundColor(Color("AppPrimaryTextColor"))
            
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
            profileService: nil,
            audioService: nil,
            onSwitchProfile: {},
            onDismiss: {}
        )
    }
}
