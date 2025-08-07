//
//  ProfileSetupViewModel.swift
//  Bemo
//
//  ViewModel for child profile setup after authentication
//

// WHAT: Manages child profile creation after successful authentication. Handles API calls and profile service integration.
// ARCHITECTURE: ViewModel in MVVM-S. Uses APIService for backend communication and ProfileService for local state management.
// USAGE: Created by AppCoordinator with authenticated user context. Handles profile creation and navigation completion.

import Foundation
import Combine
import Observation

@Observable
class ProfileSetupViewModel {
    var isLoading = false
    var errorMessage: String?
    
    private let authenticatedUser: AuthenticatedUser
    private let profileService: ProfileService
    private let apiService: APIService
    private let onProfileSetupComplete: () -> Void
    private let onBackRequested: (() -> Void)?
    private var cancellables = Set<AnyCancellable>()
    
    init(
        authenticatedUser: AuthenticatedUser,
        profileService: ProfileService,
        apiService: APIService,
        onProfileSetupComplete: @escaping () -> Void,
        onBackRequested: (() -> Void)? = nil
    ) {
        self.authenticatedUser = authenticatedUser
        self.profileService = profileService
        self.apiService = apiService
        self.onProfileSetupComplete = onProfileSetupComplete
        self.onBackRequested = onBackRequested
    }
    
    func createChildProfile(name: String, age: Int, gender: String) {
        guard !isLoading else { return }
        
        // Validate inputs before proceeding
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Child's name cannot be empty."
            return
        }
        
        guard trimmedName.count >= 2 else {
            errorMessage = "Child's name must be at least 2 characters long."
            return
        }
        
        guard trimmedName.count <= 50 else {
            errorMessage = "Child's name cannot be longer than 50 characters."
            return
        }
        
        guard age >= 3 && age <= 12 else {
            errorMessage = "Age must be between 3 and 12 years."
            return
        }
        
        // Check if a child with this name already exists
        let existingProfiles = profileService.childProfiles
        if existingProfiles.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            errorMessage = "A child with the name '\(trimmedName)' already exists. Please choose a different name."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        print("DEBUG: Profile creation started for user: \(authenticatedUser.id)")
        print("DEBUG: Child name: '\(trimmedName)', age: \(age), gender: '\(gender)')")
        
        // Create profile via API
        apiService.createChildProfile(
            userId: authenticatedUser.id,
            name: trimmedName,
            age: age,
            gender: gender
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    self?.handleProfileCreationError(error)
                }
            },
            receiveValue: { [weak self] profile in
                self?.handleProfileCreated(profile)
            }
        )
        .store(in: &cancellables)
    }
    
    func skipProfileSetup() {
        // For now, just complete without creating a profile
        // In a real app, this might create a temporary guest profile
        onProfileSetupComplete()
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    func goBack() {
        onBackRequested?()
    }
    
    var canGoBack: Bool {
        return onBackRequested != nil
    }
    
    private func handleProfileCreated(_ profile: UserProfile) {
        // Add to child profiles and set as active
        profileService.addChildProfile(profile)
        profileService.setActiveProfile(profile)
        
        isLoading = false
        
        // Navigate to main app
        onProfileSetupComplete()
        
        print("Child profile created successfully: \(profile.name)")
    }
    
    private func handleProfileCreationError(_ error: APIService.APIError) {
        isLoading = false
        
        switch error {
        case .networkError(let underlyingError):
            // Check if this is a Supabase-specific error
            let errorString = underlyingError.localizedDescription.lowercased()
            if errorString.contains("unique") || errorString.contains("constraint") {
                errorMessage = "A child with this name already exists. Please choose a different name."
            } else if errorString.contains("age") {
                errorMessage = "Invalid age. Age must be between 3 and 12."
            } else if errorString.contains("auth") || errorString.contains("unauthorized") {
                errorMessage = "Authentication required. Please sign out and sign in again."
            } else {
                errorMessage = "Network error. Please check your connection and try again."
            }
        case .unauthorized:
            errorMessage = "Authentication expired. Please sign out and sign in again."
        case .serverError(let code):
            if code == 409 {
                errorMessage = "A child with this name already exists. Please choose a different name."
            } else if code == 422 {
                errorMessage = "Invalid profile information. Please check your entries."
            } else {
                errorMessage = "Server error (\(code)). Please try again later."
            }
        case .decodingError:
            errorMessage = "Data format error. Please try again."
        case .invalidURL, .noData:
            errorMessage = "Service configuration error. Please try again."
        case .supabaseNotAvailable:
            errorMessage = "Database service is not properly configured. Please contact support or try again later."
        }
        
        print("Profile creation failed: \(error)")
    }
}