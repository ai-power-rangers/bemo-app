//
//  APIService.swift
//  Bemo
//
//  Service for handling backend API communication
//

// WHAT: Handles all backend API communication. Manages user accounts, profiles, game progress, and analytics with Combine publishers.
// ARCHITECTURE: Service layer in MVVM-S. Stateless service providing async API methods. Returns publishers for reactive data flow.
// USAGE: Injected via DependencyContainer. Call methods for API operations. Subscribe to publishers for async results.

import Foundation
import Combine

class APIService {
    private let baseURL = "https://api.bemoapp.com/v1"
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    enum APIError: Error {
        case invalidURL
        case noData
        case decodingError
        case networkError(Error)
        case unauthorized
        case serverError(Int)
    }
    
    init() {
        // Initialize API service
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
    
    func createChildProfile(userId: String, name: String, age: Int) -> AnyPublisher<UserProfile, APIError> {
        // Stub implementation
        let profile = UserProfile(
            id: UUID().uuidString,
            userId: userId,
            name: name,
            age: age,
            totalXP: 0,
            achievements: [],
            preferences: UserPreferences()
        )
        return Just(profile)
            .setFailureType(to: APIError.self)
            .eraseToAnyPublisher()
    }
    
    func getChildProfiles(userId: String) -> AnyPublisher<[UserProfile], APIError> {
        // Stub implementation
        let profiles = [
            UserProfile(
                id: "1",
                userId: userId,
                name: "Emma",
                age: 6,
                totalXP: 450,
                achievements: [],
                preferences: UserPreferences()
            )
        ]
        return Just(profiles)
            .setFailureType(to: APIError.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Game Progress
    
    func saveGameProgress(profileId: String, gameId: String, progress: GameProgress) -> AnyPublisher<Void, APIError> {
        // Stub implementation
        return Just(())
            .setFailureType(to: APIError.self)
            .eraseToAnyPublisher()
    }
    
    func getGameProgress(profileId: String, gameId: String) -> AnyPublisher<GameProgress, APIError> {
        // Stub implementation
        let progress = GameProgress(
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
        body: Data? = nil
    ) -> AnyPublisher<T, APIError> {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.networkError(URLError(.badServerResponse))
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 401:
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

struct GameProgress: Codable {
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