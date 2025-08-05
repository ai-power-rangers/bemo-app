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
    private var cancellables = Set<AnyCancellable>()
    
    init(
        authenticatedUser: AuthenticatedUser,
        profileService: ProfileService,
        apiService: APIService,
        onProfileSetupComplete: @escaping () -> Void
    ) {
        self.authenticatedUser = authenticatedUser
        self.profileService = profileService
        self.apiService = apiService
        self.onProfileSetupComplete = onProfileSetupComplete
    }
    
    func createChildProfile(name: String, age: Int, gender: String) {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Create profile via API
        apiService.createChildProfile(
            userId: authenticatedUser.id,
            name: name,
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
        case .networkError:
            errorMessage = "Network error. Please check your connection and try again."
        case .unauthorized:
            errorMessage = "Authentication expired. Please sign in again."
        case .serverError(let code):
            errorMessage = "Server error (\(code)). Please try again later."
        case .decodingError:
            errorMessage = "Data error. Please try again."
        case .invalidURL, .noData:
            errorMessage = "Service error. Please try again."
        }
        
        print("Profile creation failed: \(error)")
    }
}