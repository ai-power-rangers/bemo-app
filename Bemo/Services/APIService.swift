//
//  APIService.swift
//  Bemo
//
//  Service for handling backend API communication
//

// WHAT: Handles all backend API communication. Manages user accounts, profiles, game progress, and analytics .
// ARCHITECTURE: Service layer in MVVM-S. Stateless service providing async API methods. 
// USAGE: Injected via DependencyContainer. Call methods for API operations. 

import Foundation
import Combine

class APIService {
    private let baseURL = "https://api.bemoapp.com/v1"
    private let session = URLSession.shared
    private weak var authenticationService: AuthenticationService?
    private weak var supabaseService: SupabaseService?
    private var cancellables = Set<AnyCancellable>()
    
    enum APIError: Error {
        case invalidURL
        case noData
        case decodingError
        case networkError(Error)
        case unauthorized
        case serverError(Int)
        case supabaseNotAvailable
    }
    
    init(authenticationService: AuthenticationService? = nil) {
        self.authenticationService = authenticationService
    }
    
    func setSupabaseService(_ supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
    }
    
    // MARK: - User Management
    
    func createUser(name: String, email: String) -> AnyPublisher<User, APIError> {
        // Stub implementation
        let user = User(id: UUID().uuidString, name: name, email: email, createdAt: Date())
        return Just(user)
            .setFailureType(to: APIError.self)
            .eraseToAnyPublisher()
    }
    
    func getUser(id: String) -> AnyPublisher<User, APIError> {
        // Stub implementation
        let user = User(id: id, name: "Test User", email: "test@example.com", createdAt: Date())
        return Just(user)
            .setFailureType(to: APIError.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Profile Management
    
    func createChildProfile(userId: String, name: String, age: Int, gender: String, avatarSymbol: String? = nil, avatarColor: String? = nil) -> AnyPublisher<UserProfile, APIError> {
        guard let supabaseService = supabaseService else {
            return Fail(error: APIError.supabaseNotAvailable)
                .eraseToAnyPublisher()
        }
        
        // Verify Supabase is connected before attempting profile creation
        guard supabaseService.isConnected else {
            print("DEBUG: APIService - Supabase not connected, cannot create profile")
            print("DEBUG: This is likely due to Supabase configuration issues (audience mismatch)")
            return Fail(error: APIError.supabaseNotAvailable)
                .eraseToAnyPublisher()
        }
        
        print("DEBUG: APIService - Creating profile for user: \(userId), name: '\(name)', age: \(age)")
        
        // Use Supabase to get the actual Supabase user ID and create the profile
        return Future { promise in
            Task {
                do {
                    // Get the Supabase user ID instead of using Apple ID
                    let supabaseUserId = try await supabaseService.getCurrentUserID()
                    
                    // Use provided avatar or generate random one
                    let defaultAvatar = Avatar.random()
                    
                    // Create profile object with Supabase user ID
                    let profile = UserProfile(
                        id: UUID().uuidString,
                        userId: supabaseUserId,  // Use Supabase UUID, not Apple ID
                        name: name,
                        age: age,
                        gender: gender,
                        avatarSymbol: avatarSymbol ?? defaultAvatar.symbol,
                        avatarColor: avatarColor ?? defaultAvatar.colorName,
                        totalXP: 0,
                        preferences: UserPreferences()
                    )
                    
                    // Persist to Supabase
                    try await supabaseService.syncChildProfile(profile)
                    promise(.success(profile))
                } catch {
                    promise(.failure(.networkError(error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func getChildProfiles(userId: String) -> AnyPublisher<[UserProfile], APIError> {
        // Stub implementation
        let defaultAvatar = Avatar.random()
        let profiles = [
            UserProfile(
                id: "1",
                userId: userId,
                name: "Emma",
                age: 6,
                gender: "Female",
                avatarSymbol: defaultAvatar.symbol,
                avatarColor: defaultAvatar.colorName,
                totalXP: 450,
                preferences: UserPreferences()
            )
        ]
        return Just(profiles)
            .setFailureType(to: APIError.self)
            .eraseToAnyPublisher()
    }
    
    func deleteChildProfile(profileId: String) -> AnyPublisher<Void, APIError> {
        // Stub implementation
        return Just(())
            .setFailureType(to: APIError.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Game Progress
    
    func saveGameProgress(profileId: String, gameId: String, progress: APIGameProgress) -> AnyPublisher<Void, APIError> {
        // Stub implementation
        return Just(())
            .setFailureType(to: APIError.self)
            .eraseToAnyPublisher()
    }
    
    func getGameProgress(profileId: String, gameId: String) -> AnyPublisher<APIGameProgress, APIError> {
        // Stub implementation
        let progress = APIGameProgress(
            gameId: gameId,
            profileId: profileId,
            currentLevel: 1,
            totalScore: 0,
            playTime: 0,
            lastPlayed: Date()
        )
        return Just(progress)
            .setFailureType(to: APIError.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Analytics
    
    func logEvent(_ event: AnalyticsEvent) -> AnyPublisher<Void, APIError> {
        // Stub implementation
        print("Analytics event: \(event.name)")
        return Just(())
            .setFailureType(to: APIError.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    private func makeRequest<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        requiresAuth: Bool = true
    ) -> AnyPublisher<T, APIError> {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication header if required and available
        if requiresAuth, let accessToken = authenticationService?.currentUser?.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { [weak self] data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.networkError(URLError(.badServerResponse))
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 401:
                    // Handle unauthorized by triggering sign-out
                    DispatchQueue.main.async {
                        self?.authenticationService?.signOut()
                    }
                    throw APIError.unauthorized
                default:
                    throw APIError.serverError(httpResponse.statusCode)
                }
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                if error is APIError {
                    return error as! APIError
                } else if error is DecodingError {
                    return APIError.decodingError
                } else {
                    return APIError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Data Models

struct User: Codable {
    let id: String
    let name: String
    let email: String
    let createdAt: Date
}

struct APIGameProgress: Codable {
    let gameId: String
    let profileId: String
    let currentLevel: Int
    let totalScore: Int
    let playTime: TimeInterval
    let lastPlayed: Date
}

struct AnalyticsEvent {
    let name: String
    let parameters: [String: Any]
    let timestamp: Date
}
