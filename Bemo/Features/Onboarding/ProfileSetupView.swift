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
    @State private var selectedGender = "Prefer not to say"
    @State private var selectedAvatar = Avatar.random()
    @State private var showAvatarPicker = false
    @State private var animateContent = false
    @FocusState private var isNameFieldFocused: Bool
    
    private let genderOptions = ["Boy", "Girl", "Prefer not to say"]
    
    private var genderForAPI: String {
        switch selectedGender {
        case "Boy": return "Male"
        case "Girl": return "Female"
        default: return "Not specified"
        }
    }
    
    init(viewModel: ProfileSetupViewModel) {
        self._viewModel = State(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // App background color from assets
                Color("AppBackground")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: BemoTheme.Spacing.xlarge) {
                        // Header
                        headerSection
                            .padding(.top, BemoTheme.Spacing.large)
                        
                        // Profile form
                        profileFormSection
                        
                        // Action buttons
                        actionButtonsSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, BemoTheme.Spacing.large)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
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
                                    .font(.system(size: 17))
                            }
                            .foregroundColor(BemoTheme.Colors.primary)
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.signOut() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 14))
                            Text("Sign Out")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(.red.opacity(0.8))
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .disabled(viewModel.isLoading)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateContent = true
            }
            
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
        .alert("Oops!", isPresented: .constant(viewModel.errorMessage != nil)) {
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
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(BemoTheme.Colors.primary)
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: BemoTheme.Spacing.medium) {            
            VStack(spacing: BemoTheme.Spacing.xsmall) {
                Text("Let's Get Started!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(Color("AppPrimaryTextColor"))
                    .multilineTextAlignment(.center)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.1), value: animateContent)
                
                Text("Create a profile for your little learner")
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundColor(Color("AppPrimaryTextColor").opacity(0.7))
                    .multilineTextAlignment(.center)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.2), value: animateContent)
            }
        }
    }
    
    private var profileFormSection: some View {
        VStack(spacing: BemoTheme.Spacing.large) {
            // Avatar selection
            Button(action: { showAvatarPicker = true }) {
                HStack(spacing: BemoTheme.Spacing.medium) {
                    AvatarView(avatar: selectedAvatar, size: 72)
                        .overlay(
                            Circle()
                                .stroke(BemoTheme.Colors.primary.opacity(0.2), lineWidth: 2)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Avatar")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color("AppPrimaryTextColor").opacity(0.6))
                        
                        Text(selectedAvatar.displayName)
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(Color("AppPrimaryTextColor"))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color("AppPrimaryTextColor").opacity(0.4))
                }
                .padding(BemoTheme.Spacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.large)
                        .fill(Color.gray.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.large)
                                .stroke(Color.gray.opacity(0.08), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .opacity(animateContent ? 1 : 0)
            .offset(y: animateContent ? 0 : 20)
            .animation(.easeOut(duration: 0.5).delay(0.3), value: animateContent)
            
            // Name input
            VStack(alignment: .leading, spacing: BemoTheme.Spacing.xsmall) {
                Text("Name")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color("AppPrimaryTextColor").opacity(0.6))
                
                TextField("Your child's name", text: $childName)
                    .font(.system(size: 17, design: .rounded))
                    .padding(BemoTheme.Spacing.medium)
                    .background(
                        RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                            .fill(Color.gray.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                                    .stroke(Color.gray.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .focused($isNameFieldFocused)
                    .onSubmit {
                        isNameFieldFocused = false
                    }
            }
            .opacity(animateContent ? 1 : 0)
            .offset(y: animateContent ? 0 : 20)
            .animation(.easeOut(duration: 0.5).delay(0.4), value: animateContent)
            
            // Age selection
            VStack(alignment: .leading, spacing: BemoTheme.Spacing.medium) {
                HStack {
                    Text("Age")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color("AppPrimaryTextColor").opacity(0.6))
                    
                    Spacer()
                    
                    Text("\(childAge) years old")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(BemoTheme.Colors.primary)
                }
                
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
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
                        .frame(width: max(0, CGFloat(childAge - 3) / 9.0 * (UIScreen.main.bounds.width - 80)), height: 8)
                }
                .overlay(
                    Slider(value: Binding(
                        get: { Double(childAge) },
                        set: { childAge = Int($0) }
                    ), in: 3...12, step: 1)
                        .tint(.clear)
                )
                
                HStack {
                    Text("3")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(Color("AppPrimaryTextColor").opacity(0.5))
                    Spacer()
                    Text("12")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(Color("AppPrimaryTextColor").opacity(0.5))
                }
            }
            .padding(BemoTheme.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.large)
                    .fill(Color.gray.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.large)
                            .stroke(Color.gray.opacity(0.08), lineWidth: 1)
                    )
            )
            .opacity(animateContent ? 1 : 0)
            .offset(y: animateContent ? 0 : 20)
            .animation(.easeOut(duration: 0.5).delay(0.5), value: animateContent)
            
            // Gender selection
            VStack(alignment: .leading, spacing: BemoTheme.Spacing.xsmall) {
                Text("Gender")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color("AppPrimaryTextColor").opacity(0.6))
                
                HStack(spacing: BemoTheme.Spacing.xsmall) {
                    ForEach(genderOptions, id: \.self) { gender in
                        Button(action: { selectedGender = gender }) {
                            Text(gender)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(selectedGender == gender ? .white : Color("AppPrimaryTextColor").opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, BemoTheme.Spacing.small)
                                .background(
                                    RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                                        .fill(selectedGender == gender
                                            ? BemoTheme.Colors.primary
                                            : Color.gray.opacity(0.04))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                                                .stroke(
                                                    selectedGender == gender
                                                        ? Color.clear
                                                        : Color.gray.opacity(0.08),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedGender)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .opacity(animateContent ? 1 : 0)
            .offset(y: animateContent ? 0 : 20)
            .animation(.easeOut(duration: 0.5).delay(0.6), value: animateContent)
            
            // Info note
            HStack(spacing: BemoTheme.Spacing.small) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(BemoTheme.Colors.secondary)
                
                Text("Personalized learning paths adapt to your child's age and progress")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(Color("AppPrimaryTextColor").opacity(0.7))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(BemoTheme.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.medium)
                    .fill(Color(hex: "#E0F2FE"))  // Light blue background similar to screenshot
            )
            .opacity(animateContent ? 1 : 0)
            .offset(y: animateContent ? 0 : 20)
            .animation(.easeOut(duration: 0.5).delay(0.7), value: animateContent)
        }
    }
    
    private var actionButtonsSection: some View {
        Button(action: {
            createProfile()
        }) {
            HStack {
                Text("Create Profile")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                isCreateButtonEnabled ? BemoTheme.Colors.primary : Color.gray.opacity(0.3)
            )
            .cornerRadius(BemoTheme.CornerRadius.large)
            .shadow(
                color: isCreateButtonEnabled ? Color.black.opacity(0.1) : Color.clear,
                radius: 8,
                x: 0,
                y: 4
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isCreateButtonEnabled)
        }
        .disabled(!isCreateButtonEnabled)
        .scaleEffect(animateContent ? 1 : 0.9)
        .opacity(animateContent ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.8), value: animateContent)
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
            gender: genderForAPI,
            avatarSymbol: selectedAvatar.symbol,
            avatarColor: selectedAvatar.colorName
        )
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .transition(.opacity)
            
            VStack(spacing: BemoTheme.Spacing.large) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: BemoTheme.Colors.primary))
                    .scaleEffect(1.2)
                
                VStack(spacing: 4) {
                    Text("Creating Profile")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(Color("AppPrimaryTextColor"))
                    
                    Text("Just a moment...")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(Color("AppPrimaryTextColor").opacity(0.7))
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: BemoTheme.CornerRadius.xlarge)
                    .fill(Color("AppBackground"))
                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
            )
            .scaleEffect(isAnimating ? 1 : 0.9)
            .opacity(isAnimating ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isAnimating)
        }
        .onAppear {
            isAnimating = true
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
