//
//  ProfileSetupView.swift
//  Bemo
//
//  Profile setup screen for creating child profiles after authentication
//

// WHAT: Profile setup flow for creating child profiles after successful authentication. Handles profile creation and validation.
// ARCHITECTURE: View in MVVM-S. Uses ProfileSetupViewModel for profile creation logic and API communication.
// USAGE: Presented by AppCoordinator after successful authentication when no child profiles exist.

import SwiftUI

struct ProfileSetupView: View {
    @State private var viewModel: ProfileSetupViewModel
    @State private var childName = ""
    @State private var childAge = 5
    @State private var selectedGender = "Not specified"
    @State private var selectedAvatar = Avatar.random()
    @State private var showAvatarPicker = false
    @FocusState private var isNameFieldFocused: Bool
    
    private let genderOptions = ["Male", "Female", "Not specified"]
    
    init(viewModel: ProfileSetupViewModel) {
        self._viewModel = State(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    headerSection
                    
                    // Profile form
                    profileFormSection
                    
                    // Action buttons
                    actionButtonsSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
            .navigationTitle("Create Profile")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.canGoBack {
                        Button(action: {
                            viewModel.goBack()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Back")
                                    .font(.body)
                            }
                            .foregroundColor(.blue)
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: { viewModel.signOut() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                }
                .disabled(viewModel.isLoading)
                .background(.ultraThinMaterial)
            }
            .disabled(viewModel.isLoading)
        }
        .alert("Profile Creation Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .overlay {
            if viewModel.isLoading {
                LoadingOverlay()
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
                                showAvatarPicker = false
                            }
                        }
                    }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Create Your Child's Profile")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("Tell us a bit about your child to personalize their learning experience.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var profileFormSection: some View {
        VStack(spacing: 24) {
            // Avatar selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose Avatar")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    AvatarView(avatar: selectedAvatar, size: 60)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedAvatar.displayName)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Button("Change Avatar") {
                            showAvatarPicker = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.leading, 8)
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Name input
            VStack(alignment: .leading, spacing: 8) {
                Text("Child's Name")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("Enter name", text: $childName)
                    .textFieldStyle(.roundedBorder)
                    .focused($isNameFieldFocused)
                    .onSubmit {
                        isNameFieldFocused = false
                    }
            }
            
            // Age selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Age")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(spacing: 16) {
                    Text("\(childAge) years old")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    HStack {
                        Text("3")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Slider(value: Binding(
                            get: { Double(childAge) },
                            set: { childAge = Int($0) }
                        ), in: 3...12, step: 1)
                        
                        Text("12")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Gender selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Gender")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Picker("Gender", selection: $selectedGender) {
                    ForEach(genderOptions, id: \.self) { gender in
                        Text(gender).tag(gender)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 8)
            
            // Age-appropriate content note
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                
                Text("We'll customize the experience based on your child's information")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(.vertical, 16)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                createProfile()
            }) {
                Text("Create Profile")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isCreateButtonEnabled ? Color.blue : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(!isCreateButtonEnabled)
        }
    }
    
    private var isCreateButtonEnabled: Bool {
        !childName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isLoading
    }
    
    private func createProfile() {
        let trimmedName = childName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        viewModel.createChildProfile(
            name: trimmedName,
            age: childAge,
            gender: selectedGender,
            avatarSymbol: selectedAvatar.symbol,
            avatarColor: selectedAvatar.colorName
        )
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
                
                Text("Creating profile...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color.black.opacity(0.8))
            .cornerRadius(16)
        }
    }
}

// MARK: - Previews

struct ProfileSetupView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSetupView(viewModel: ProfileSetupViewModel(
            authenticatedUser: AuthenticatedUser(
                id: "test",
                appleUserIdentifier: "test",
                email: "test@example.com",
                fullName: nil,
                accessToken: "token",
                nonce: nil
            ),
            profileService: ProfileService(),
            apiService: APIService(),
            authenticationService: AuthenticationService(),
            onProfileSetupComplete: {}
        ))
    }
}
