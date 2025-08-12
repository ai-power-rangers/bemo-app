//
//  ChildProfileEditView.swift
//  Bemo
//
//  Edit screen for child profiles in parent dashboard
//

// WHAT: Modal sheet for editing child profile details including name, age, avatar, and preferences
// ARCHITECTURE: SwiftUI View component for parent dashboard. Updates ProfileService data.
// USAGE: Presented from ParentDashboardView when editing a child profile. Allows full profile customization.

import SwiftUI

struct ChildProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    
    let profile: UserProfile
    let profileService: ProfileService
    let onSave: (UserProfile) -> Void
    let onDelete: (() -> Void)?
    
    @State private var name: String
    @State private var age: Int
    @State private var gender: String
    @State private var selectedAvatar: Avatar
    @State private var soundEnabled: Bool
    @State private var musicEnabled: Bool
    @State private var difficultySetting: UserPreferences.DifficultySetting
    
    @State private var showDeleteConfirmation = false
    @State private var showAvatarPicker = false
    @State private var hasChanges = false
    
    private let genderOptions = ["Male", "Female", "Not specified"]
    
    init(
        profile: UserProfile,
        profileService: ProfileService,
        onSave: @escaping (UserProfile) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.profile = profile
        self.profileService = profileService
        self.onSave = onSave
        self.onDelete = onDelete
        
        // Initialize state with current profile values
        self._name = State(initialValue: profile.name)
        self._age = State(initialValue: profile.age)
        self._gender = State(initialValue: profile.gender)
        self._selectedAvatar = State(initialValue: Avatar.from(
            symbol: profile.avatarSymbol,
            colorName: profile.avatarColor
        ))
        self._soundEnabled = State(initialValue: profile.preferences.soundEnabled)
        self._musicEnabled = State(initialValue: profile.preferences.musicEnabled)
        self._difficultySetting = State(initialValue: profile.preferences.difficultySetting)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Avatar Section
                Section {
                    HStack {
                        AvatarView(avatar: selectedAvatar, size: 60)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedAvatar.displayName)
                                .font(.headline)
                            Button("Change Avatar") {
                                showAvatarPicker = true
                            }
                            .font(.caption)
                        }
                        .padding(.leading, 8)
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                // Profile Information
                Section(header: Text("Profile Information")) {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Name", text: $name)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: name) { hasChanges = true }
                    }
                    
                    HStack {
                        Text("Age")
                        Spacer()
                        Picker("Age", selection: $age) {
                            ForEach(3...12, id: \.self) { age in
                                Text("\(age) years").tag(age)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: age) { hasChanges = true }
                    }
                    
                    Picker("Gender", selection: $gender) {
                        ForEach(genderOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .onChange(of: gender) { hasChanges = true }
                }
                
                // Game Settings
                Section(header: Text("Game Settings")) {
                    Toggle("Sound Effects", isOn: $soundEnabled)
                        .onChange(of: soundEnabled) { hasChanges = true }
                    
                    Toggle("Background Music", isOn: $musicEnabled)
                        .onChange(of: musicEnabled) { hasChanges = true }
                    
                    Picker("Difficulty", selection: $difficultySetting) {
                        Text("Easy").tag(UserPreferences.DifficultySetting.easy)
                        Text("Normal").tag(UserPreferences.DifficultySetting.normal)
                        Text("Hard").tag(UserPreferences.DifficultySetting.hard)
                    }
                    .onChange(of: difficultySetting) { hasChanges = true }
                }
                
                // Stats (Read-only)
                Section(header: Text("Statistics")) {
                    HStack {
                        Text("Total XP")
                        Spacer()
                        Text("\(profile.totalXP)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Level")
                        Spacer()
                        Text("\((profile.totalXP / 100) + 1)")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Delete Profile
                if onDelete != nil {
                    Section {
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            HStack {
                                Spacer()
                                Text("Delete Profile")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!hasChanges || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showAvatarPicker) {
                NavigationView {
                    AvatarPicker(selectedAvatar: $selectedAvatar)
                        .padding()
                        .navigationTitle("Choose Avatar")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    hasChanges = true
                                    showAvatarPicker = false
                                }
                            }
                        }
                }
            }
            .alert("Delete Profile", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete \(profile.name)'s profile? This action cannot be undone.")
            }
        }
    }
    
    private func saveChanges() {
        // Create updated profile
        var updatedProfile = profile
        updatedProfile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedProfile.age = age
        updatedProfile.gender = gender
        updatedProfile.avatarSymbol = selectedAvatar.symbol
        updatedProfile.avatarColor = selectedAvatar.colorName
        updatedProfile.preferences.soundEnabled = soundEnabled
        updatedProfile.preferences.musicEnabled = musicEnabled
        updatedProfile.preferences.difficultySetting = difficultySetting
        
        // Save and dismiss
        onSave(updatedProfile)
        dismiss()
    }
}

// MARK: - Preview

struct ChildProfileEditView_Previews: PreviewProvider {
    static var previews: some View {
        ChildProfileEditView(
            profile: UserProfile(
                id: "1",
                userId: "parent1",
                name: "Emma",
                age: 7,
                gender: "Female",
                avatarSymbol: "star.fill",
                avatarColor: "yellow",
                totalXP: 250,
                preferences: UserPreferences()
            ),
            profileService: ProfileService(),
            onSave: { _ in },
            onDelete: {}
        )
    }
}