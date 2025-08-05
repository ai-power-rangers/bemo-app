//
//  AuthenticationService.swift
//  Bemo
//
//  Service for managing authentication state and Apple Sign-In flow
//

// WHAT: Manages authentication state with Apple Sign-In integration. Handles secure token storage in Keychain and provides authentication status.
// ARCHITECTURE: Core service in MVVM-S. Publishes authentication state changes. Used by AppCoordinator for navigation decisions.
// USAGE: Injected via DependencyContainer. Call signInWithApple() to authenticate. Subscribe to isAuthenticated for state changes.

import Foundation
import Combine
import AuthenticationServices
import Security
import UIKit
import Observation

@Observable
class AuthenticationService: NSObject {
    private(set) var isAuthenticated = false
    private(set) var currentUser: AuthenticatedUser?
    private(set) var authenticationError: AuthenticationError?
    
    private let keychainService = "com.bemo.auth"
    private let accessTokenKey = "access_token"
    private let refreshTokenKey = "refresh_token"
    private let userIdKey = "user_id"
    
    enum AuthenticationError: Error, LocalizedError {
        case cancelled
        case failed
        case invalidCredential
        case notHandled
        case unknown
        case tokenExpired
        case networkError
        
        var errorDescription: String? {
            switch self {
            case .cancelled:
                return "Sign in was cancelled"
            case .failed:
                return "Sign in failed"
            case .invalidCredential:
                return "Invalid credentials"
            case .notHandled:
                return "Sign in not handled"
            case .unknown:
                return "Unknown error occurred"
            case .tokenExpired:
                return "Session expired"
            case .networkError:
                return "Network error"
            }
        }
    }
    
    override init() {
        super.init()
        checkAuthenticationState()
    }
    
    // MARK: - Authentication Methods
    
    func signInWithApple() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    func signOut() {
        // Clear tokens from Keychain
        deleteToken(key: accessTokenKey)
        deleteToken(key: refreshTokenKey)
        deleteToken(key: userIdKey)
        
        // Update state
        isAuthenticated = false
        currentUser = nil
        authenticationError = nil
        
        print("User signed out successfully")
    }
    
    func refreshTokenIfNeeded() async {
        guard let refreshToken = getToken(key: refreshTokenKey) else {
            await MainActor.run {
                self.signOut()
            }
            return
        }
        
        // In a real implementation, this would call your backend to refresh the access token
        // For now, we'll simulate a successful refresh
        do {
            // Simulate API call delay
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            // In real implementation:
            // let newTokens = try await apiService.refreshToken(refreshToken)
            // storeTokens(accessToken: newTokens.accessToken, refreshToken: newTokens.refreshToken)
            
            print("Token refreshed successfully")
        } catch {
            await MainActor.run {
                self.authenticationError = .tokenExpired
                self.signOut()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func checkAuthenticationState() {
        // Check if we have stored tokens
        guard let accessToken = getToken(key: accessTokenKey),
              let userId = getToken(key: userIdKey) else {
            isAuthenticated = false
            return
        }
        
        // Create user from stored data
        // In a real app, you might want to validate the token with your backend
        currentUser = AuthenticatedUser(
            id: userId,
            appleUserIdentifier: userId, // This would be stored separately in a real app
            email: nil, // Email might not be available after first sign-in
            fullName: nil,
            accessToken: accessToken
        )
        
        isAuthenticated = true
        print("User authentication restored from Keychain")
    }
    
    func handleSuccessfulAuthentication(user: AuthenticatedUser) {
        // Store tokens securely
        storeToken(value: user.accessToken, key: accessTokenKey)
        storeToken(value: user.id, key: userIdKey)
        
        // In a real app, you would also store the refresh token received from your backend
        // storeToken(value: refreshToken, key: refreshTokenKey)
        
        // Update state
        currentUser = user
        isAuthenticated = true
        authenticationError = nil
        
        print("Authentication successful for user: \(user.id)")
    }
    
    // MARK: - Keychain Methods
    
    private func storeToken(value: String, key: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Failed to store token in Keychain: \(status)")
        }
    }
    
    private func getToken(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            if let data = dataTypeRef as? Data {
                return String(data: data, encoding: .utf8)
            }
        }
        
        return nil
    }
    
    private func deleteToken(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthenticationService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userIdentifier = appleIDCredential.user
            let email = appleIDCredential.email
            let fullName = appleIDCredential.fullName
            
            // In a real app, you would send the authorization code to your backend
            // to exchange for access and refresh tokens
            let authorizationCode = appleIDCredential.authorizationCode
            let identityToken = appleIDCredential.identityToken
            
            // For now, we'll create a mock access token
            let accessToken = "mock_access_token_\(userIdentifier)"
            
            let user = AuthenticatedUser(
                id: userIdentifier,
                appleUserIdentifier: userIdentifier,
                email: email,
                fullName: fullName,
                accessToken: accessToken
            )
            
            handleSuccessfulAuthentication(user: user)
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authorizationError = error as? ASAuthorizationError {
            switch authorizationError.code {
            case .canceled:
                authenticationError = .cancelled
            case .failed:
                authenticationError = .failed
            case .invalidResponse:
                authenticationError = .invalidCredential
            case .notHandled:
                authenticationError = .notHandled
            case .unknown:
                authenticationError = .unknown
            @unknown default:
                authenticationError = .unknown
            }
        } else {
            authenticationError = .unknown
        }
        
        print("Authentication error: \(error.localizedDescription)")
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthenticationService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Return the key window
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return windowScene.windows.first { $0.isKeyWindow } ?? UIWindow()
        }
        return UIWindow()
    }
}

// MARK: - Data Models

struct AuthenticatedUser: Codable {
    let id: String
    let appleUserIdentifier: String
    let email: String?
    let fullName: PersonNameComponents?
    let accessToken: String
    
    // Custom encoding/decoding for PersonNameComponents
    enum CodingKeys: String, CodingKey {
        case id, appleUserIdentifier, email, accessToken
        case fullNameData
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(appleUserIdentifier, forKey: .appleUserIdentifier)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encode(accessToken, forKey: .accessToken)
        
        if let fullName = fullName {
            let fullNameData = try NSKeyedArchiver.archivedData(withRootObject: fullName, requiringSecureCoding: false)
            try container.encode(fullNameData, forKey: .fullNameData)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        appleUserIdentifier = try container.decode(String.self, forKey: .appleUserIdentifier)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        
        if let fullNameData = try container.decodeIfPresent(Data.self, forKey: .fullNameData) {
            fullName = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(fullNameData) as? PersonNameComponents
        } else {
            fullName = nil
        }
    }
    
    init(id: String, appleUserIdentifier: String, email: String?, fullName: PersonNameComponents?, accessToken: String) {
        self.id = id
        self.appleUserIdentifier = appleUserIdentifier
        self.email = email
        self.fullName = fullName
        self.accessToken = accessToken
    }
}