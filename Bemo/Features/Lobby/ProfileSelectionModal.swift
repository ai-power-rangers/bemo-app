//
//  ProfileSelectionModal.swift
//  Bemo
//
//  Modal view for selecting between available child profiles or adding a new one
//

// WHAT: Modal interface for switching between child profiles and adding new profiles. Shows existing profiles and add button.
// ARCHITECTURE: SwiftUI View component used by GameLobbyView. Displays ProfileService data with selection callbacks.
// USAGE: Presented when profile badge is tapped or when user has profiles but none selected. Handles profile switching and new profile creation.

import SwiftUI

struct ProfileSelectionModal: View {
    let profiles: [UserProfile]
    let onProfileSelected: (UserProfile) -> Void
    let onAddProfile: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.2.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Who's Playing?")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Select a profile to continue")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Profiles list
                if profiles.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No profiles yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Create your first child profile to get started")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(profiles, id: \.id) { profile in
                                ProfileRowView(profile: profile) {
                                    onProfileSelected(profile)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Add profile button
                Button(action: onAddProfile) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                        Text("Add Child Profile")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Select Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

struct ProfileRowView: View {
    let profile: UserProfile
    let action: () -> Void
    
    private var level: Int {
        (profile.totalXP / 100) + 1
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Profile avatar
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                // Profile info
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text("Level \(level)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("•")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        Text("\(profile.totalXP) XP")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        Text("Age \(profile.age)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Selection indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Previews

struct ProfileSelectionModal_Previews: PreviewProvider {
    static var previews: some View {
        // Preview with profiles
        ProfileSelectionModal(
            profiles: [
                UserProfile(
                    id: "1",
                    userId: "parent1",
                    name: "Emma",
                    age: 7,
                    gender: "Female",
                    avatarSymbol: "star.fill",
                    avatarColor: "purple",
                    totalXP: 250,
                    preferences: UserPreferences()
                ),
                UserProfile(
                    id: "2",
                    userId: "parent1",
                    name: "Lucas",
                    age: 5,
                    gender: "Male",
                    avatarSymbol: "heart.fill",
                    avatarColor: "blue",
                    totalXP: 150,
                    preferences: UserPreferences()
                )
            ],
            onProfileSelected: { _ in },
            onAddProfile: { },
            onDismiss: { }
        )
        
        // Preview without profiles
        ProfileSelectionModal(
            profiles: [],
            onProfileSelected: { _ in },
            onAddProfile: { },
            onDismiss: { }
        )
        .previewDisplayName("No Profiles")
    }
}