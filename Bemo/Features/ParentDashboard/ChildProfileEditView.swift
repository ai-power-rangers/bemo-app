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
    
    private let genderOptions = ["Boy", "Girl", "Prefer not to say"]
    
    private var genderForAPI: String {
        switch gender {
        case "Boy": return "Male"
        case "Girl": return "Female"
        default: return "Not specified"
        }
    }
    
    private var genderFromAPI: String {
        switch profile.gender {
        case "Male": return "Boy"
        case "Female": return "Girl"
        default: return "Prefer not to say"
        }
    }
    
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
        self._gender = State(initialValue: {
            switch profile.gender {
            case "Male": return "Boy"
            case "Female": return "Girl"
            default: return "Prefer not to say"
            }
        }())
        self._selectedAvatar = State(initialValue: Avatar.from(
            symbol: profile.avatarSymbol,
            colorName: profile.avatarColor
        ))
        self._soundEnabled = State(initialValue: profile.preferences.soundEnabled)
        self._musicEnabled = State(initialValue: profile.preferences.musicEnabled)
        self._difficultySetting = State(initialValue: profile.preferences.difficultySetting)
    }
    
    // MARK: - Body Components
    
    private var avatarSection: some View {
        VStack(spacing: BemoTheme.Spacing.medium) {
            Button(action: { showAvatarPicker = true }) {
                VStack(spacing: BemoTheme.Spacing.small) {
                    AvatarView(avatar: selectedAvatar, size: 80)
                        .overlay(
                            Circle()
                                .stroke(BemoTheme.Colors.primary.opacity(0.2), lineWidth: 2)
                        )
                    
                    Text("Change Avatar")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color("AppPrimaryTextColor"))
                }
            }
            .onChange(of: selectedAvatar) { _ in hasChanges = true }
        }
        .padding(.top, BemoTheme.Spacing.large)
    }
    
    private var profileInfoSection: some View {
        VStack(alignment: .leading, spacing: BemoTheme.Spacing.medium) {
            Text("Profile Information")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(Color("AppPrimaryTextColor"))
                .padding(.horizontal, BemoTheme.Spacing.large)
            
            VStack(spacing: BemoTheme.Spacing.medium) {
                // Name field
                VStack(alignment: .leading, spacing: BemoTheme.Spacing.xsmall) {
                    Text("Name")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color("AppPrimaryTextColor").opacity(0.6))
                        .padding(.horizontal, BemoTheme.Spacing.large)
                    
                    TextField("Child's name", text: $name)
                        .font(.system(size: 17, design: .rounded))
                        .padding(BemoTheme.Spacing.medium)
                        .background(
                            RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                                        .stroke(Color.gray.opacity(0.08), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, BemoTheme.Spacing.large)
                        .onChange(of: name) { _ in hasChanges = true }
                }
                
                // Age selector
                VStack(alignment: .leading, spacing: BemoTheme.Spacing.medium) {
                    HStack {
                        Text("Age")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color("AppPrimaryTextColor").opacity(0.6))
                        
                        Spacer()
                        
                        Text("\(age) years old")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(BemoTheme.Colors.primary)
                    }
                    .padding(.horizontal, BemoTheme.Spacing.large)
                    
                    ZStack(alignment: .leading) {
                        // Track
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                            .frame(height: 8)
                        
                        // Fill
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        BemoTheme.Colors.primary,
                                        BemoTheme.Colors.tertiary
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, CGFloat(age - 3) / 9.0 * (UIScreen.main.bounds.width - 80)), height: 8)
                    }
                    .overlay(
                        Slider(value: Binding(
                            get: { Double(age) },
                            set: { age = Int($0) }
                        ), in: 3...12, step: 1)
                            .tint(.clear)
                            .onChange(of: age) { _ in hasChanges = true }
                    )
                    .padding(.horizontal, BemoTheme.Spacing.large)
                    
                    HStack {
                        Text("3")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(Color("AppPrimaryTextColor").opacity(0.5))
                        Spacer()
                        Text("12")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(Color("AppPrimaryTextColor").opacity(0.5))
                    }
                    .padding(.horizontal, BemoTheme.Spacing.large)
                }
                
                // Gender selection
                VStack(alignment: .leading, spacing: BemoTheme.Spacing.xsmall) {
                    Text("Gender")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color("AppPrimaryTextColor").opacity(0.6))
                        .padding(.horizontal, BemoTheme.Spacing.large)
                    
                    HStack(spacing: BemoTheme.Spacing.xsmall) {
                        ForEach(genderOptions, id: \.self) { option in
                            Button(action: {
                                gender = option
                                hasChanges = true
                            }) {
                                Text(option)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(gender == option ? .white : Color("AppPrimaryTextColor"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, BemoTheme.Spacing.small)
                                    .background(
                                        RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                                            .fill(gender == option
                                                ? BemoTheme.Colors.primary
                                                : Color.white)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                                                    .stroke(
                                                        gender == option
                                                            ? Color.clear
                                                            : Color.gray.opacity(0.08),
                                                        lineWidth: 1
                                                    )
                                            )
                                    )
                                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: gender)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, BemoTheme.Spacing.large)
                }
            }
        }
    }
    
    private var gameSettingsSection: some View {
        VStack(alignment: .leading, spacing: BemoTheme.Spacing.medium) {
            Text("Game Settings")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(Color("AppPrimaryTextColor"))
                .padding(.horizontal, BemoTheme.Spacing.large)
            
            VStack(spacing: BemoTheme.Spacing.small) {
                // Sound toggle
                ToggleRow(
                    icon: "speaker.wave.2.fill",
                    title: "Sound Effects",
                    isOn: $soundEnabled,
                    onChange: { hasChanges = true }
                )
                
                // Music toggle
                ToggleRow(
                    icon: "music.note",
                    title: "Background Music",
                    isOn: $musicEnabled,
                    onChange: { hasChanges = true }
                )
                
                // Difficulty selector
                VStack(alignment: .leading, spacing: BemoTheme.Spacing.xsmall) {
                    HStack {
                        Image(systemName: "dial.medium.fill")
                            .font(.system(size: 18))
                            .foregroundColor(BemoTheme.Colors.primary)
                            .frame(width: 28)
                        
                        Text("Difficulty")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(Color("AppPrimaryTextColor").opacity(0.85))
                        
                        Spacer()
                    }
                    
                    HStack(spacing: BemoTheme.Spacing.xsmall) {
                        ForEach([
                            ("Easy", UserPreferences.DifficultySetting.easy),
                            ("Normal", UserPreferences.DifficultySetting.normal),
                            ("Hard", UserPreferences.DifficultySetting.hard)
                        ], id: \.1) { label, setting in
                            Button(action: {
                                difficultySetting = setting
                                hasChanges = true
                            }) {
                                Text(label)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(difficultySetting == setting ? .white : Color("AppPrimaryTextColor"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, BemoTheme.Spacing.xsmall)
                                    .background(
                                        RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.small)
                                            .fill(difficultySetting == setting
                                                ? BemoTheme.Colors.primary
                                                : Color.white)
                                    )
                                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: difficultySetting)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(BemoTheme.Spacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                                .stroke(Color.gray.opacity(0.08), lineWidth: 1)
                        )
                )
                .padding(.horizontal, BemoTheme.Spacing.large)
            }
        }
    }
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: BemoTheme.Spacing.medium) {
            Text("Statistics")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(Color("AppPrimaryTextColor"))
                .padding(.horizontal, BemoTheme.Spacing.large)
            
            HStack(spacing: BemoTheme.Spacing.medium) {
                ChildProfileStatCard(
                    title: "Total XP",
                    value: "\(profile.totalXP)",
                    icon: "bolt.fill",
                    color: Color(hex: "#3B82F6")
                )
                
                ChildProfileStatCard(
                    title: "Level",
                    value: "\((profile.totalXP / 100) + 1)",
                    icon: "star.fill",
                    color: Color(hex: "#F97316")
                )
            }
            .padding(.horizontal, BemoTheme.Spacing.large)
        }
    }
    
    @ViewBuilder
    private var deleteButton: some View {
        if onDelete != nil {
            Button(action: {
                showDeleteConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16))
                    
                    Text("Delete Profile")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                }
                .foregroundColor(Color("AppPrimaryTextColor"))
                .frame(maxWidth: .infinity)
                .padding(BemoTheme.Spacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                        .fill(Color.red.opacity(0.08))
                )
            }
            .padding(.horizontal, BemoTheme.Spacing.large)
            .padding(.top, BemoTheme.Spacing.medium)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // App background color from assets
                Color("AppBackground")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: BemoTheme.Spacing.large) {
                        avatarSection
                        profileInfoSection
                        gameSettingsSection
                        statisticsSection
                        deleteButton
                        
                        // Bottom padding
                        Color.clear.frame(height: BemoTheme.Spacing.xxlarge)
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
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(Color("AppPrimaryTextColor"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(Color("AppPrimaryTextColor"))
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
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .foregroundColor(BemoTheme.Colors.primary)
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
    
    private func saveChanges() {
        // Create updated profile
        var updatedProfile = profile
        updatedProfile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedProfile.age = age
        updatedProfile.gender = genderForAPI
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

// MARK: - Toggle Row

struct ToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    let onChange: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(BemoTheme.Colors.primary)
                .frame(width: 28)
            
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(Color("AppPrimaryTextColor").opacity(0.85))
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(BemoTheme.Colors.primary)
                .onChange(of: isOn) { _ in onChange() }
        }
        .padding(BemoTheme.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                        .stroke(Color.gray.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal, BemoTheme.Spacing.large)
    }
}

// MARK: - ChildProfileStatCard Card

struct ChildProfileStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: BemoTheme.Spacing.small) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(Color("AppPrimaryTextColor").opacity(0.7))
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color("AppPrimaryTextColor"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BemoTheme.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                .fill(color.opacity(0.08))
        )
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
