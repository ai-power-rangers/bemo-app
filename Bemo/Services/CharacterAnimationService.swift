//
//  CharacterAnimationService.swift
//  Bemo
//
//  Service for displaying character animations globally across the app
//

// WHAT: Manages a global overlay for showing character animations (GIF, MP4, static images) on top of any screen
// ARCHITECTURE: Service layer in MVVM-S. Injected via DependencyContainer and accessible to all ViewModels
// USAGE: Call showCharacter() from any ViewModel to display animations. Service manages queue, positioning, and lifecycle

import Foundation
import SwiftUI
import Observation

@Observable
class CharacterAnimationService {
    // MARK: - Types
    
    enum CharacterType {
        case waving           // waving-unscreen.gif
        case cheering         // cheering-confetti-unscreen.gif
        case custom(String)   // Custom image/gif/video path
        
        var resourceName: String {
            switch self {
            case .waving:
                return "waving-unscreen"
            case .cheering:
                return "cheering-confetti-unscreen"
            case .custom(let name):
                return name
            }
        }
        
        var animationType: AnimationType {
            switch self {
            case .waving, .cheering:
                return .gif
            case .custom(let name):
                if name.hasSuffix(".gif") {
                    return .gif
                } else if name.hasSuffix(".mp4") || name.hasSuffix(".mov") {
                    return .video
                } else {
                    return .staticImage
                }
            }
        }
    }
    
    enum AnimationPosition {
        case center
        case topLeft
        case topCenter
        case topRight
        case bottomLeft
        case bottomCenter
        case bottomRight
        case custom(x: CGFloat, y: CGFloat) // Normalized coordinates (0-1)
        
        func point(in size: CGSize) -> CGPoint {
            switch self {
            case .center:
                return CGPoint(x: size.width / 2, y: size.height / 2)
            case .topLeft:
                return CGPoint(x: size.width * 0.2, y: size.height * 0.2)
            case .topCenter:
                return CGPoint(x: size.width / 2, y: size.height * 0.2)
            case .topRight:
                return CGPoint(x: size.width * 0.8, y: size.height * 0.2)
            case .bottomLeft:
                return CGPoint(x: size.width * 0.2, y: size.height * 0.8)
            case .bottomCenter:
                return CGPoint(x: size.width / 2, y: size.height * 0.8)
            case .bottomRight:
                return CGPoint(x: size.width * 0.8, y: size.height * 0.8)
            case .custom(let x, let y):
                return CGPoint(x: size.width * x, y: size.height * y)
            }
        }
    }
    
    enum AnimationType {
        case gif
        case video
        case staticImage
    }
    
    struct CharacterAnimation: Identifiable {
        let id = UUID()
        let character: CharacterType
        let position: AnimationPosition
        let size: CGSize
        let duration: TimeInterval
        let animationType: AnimationType
        let startTime: Date
        let fadeInDuration: TimeInterval
        let fadeOutDuration: TimeInterval
        let scale: CGFloat
        let rotation: Double
        let interactive: Bool
        let onTap: (() -> Void)?
        let loop: Bool  // Whether to loop the animation indefinitely
        
        var isExpired: Bool {
            // If looping, never expire
            if loop { return false }
            return Date().timeIntervalSince(startTime) > duration
        }
    }
    
    // MARK: - Properties
    
    var activeAnimations: [CharacterAnimation] = []
    private var animationTimer: Timer?
    
    // Configuration
    var maxConcurrentAnimations = 1  // Only allow one animation at a time
    var defaultDuration: TimeInterval = 3.0
    var defaultFadeInDuration: TimeInterval = 0.3
    var defaultFadeOutDuration: TimeInterval = 0.3
    
    // MARK: - Initialization
    
    init() {
        startCleanupTimer()
    }
    
    deinit {
        animationTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Show a character animation on screen
    func showCharacter(
        _ character: CharacterType,
        at position: AnimationPosition = .center,
        size: CGSize = CGSize(width: 200, height: 200),
        duration: TimeInterval? = nil,
        fadeIn: TimeInterval? = nil,
        fadeOut: TimeInterval? = nil,
        scale: CGFloat = 1.0,
        rotation: Double = 0,
        interactive: Bool = false,
        onTap: (() -> Void)? = nil,
        loop: Bool = false
    ) {
        // If there's already an animation, ignore this call
        if !activeAnimations.isEmpty {
            return
        }
        
        // Determine animation type based on resource
        let animationType = character.animationType
        
        let animation = CharacterAnimation(
            character: character,
            position: position,
            size: size,
            duration: duration ?? defaultDuration,
            animationType: animationType,
            startTime: Date(),
            fadeInDuration: fadeIn ?? defaultFadeInDuration,
            fadeOutDuration: fadeOut ?? defaultFadeOutDuration,
            scale: scale,
            rotation: rotation,
            interactive: interactive,
            onTap: onTap,
            loop: loop
        )
        
        activeAnimations.append(animation)
    }
    
    /// Show celebration with cheering character
    func showCelebration(at position: AnimationPosition = .center) {
        showCharacter(
            .cheering,
            at: position,
            size: CGSize(width: 300, height: 300),
            duration: 4.0,
            scale: 1.2
        )
    }
    
    /// Show waving character as greeting
    func showWelcome(at position: AnimationPosition = .bottomRight) {
        showCharacter(
            .waving,
            at: position,
            size: CGSize(width: 150, height: 150),
            duration: 3.0
        )
    }
    
    /// Clear all active animations
    func clearAllAnimations() {
        activeAnimations.removeAll()
    }
    
    /// Remove a specific animation
    func removeAnimation(_ animation: CharacterAnimation) {
        activeAnimations.removeAll { $0.id == animation.id }
    }
    
    // MARK: - Private Methods
    
    private func startCleanupTimer() {
        // Clean up expired animations every 0.5 seconds
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.cleanupExpiredAnimations()
        }
    }
    
    private func cleanupExpiredAnimations() {
        let now = Date()
        activeAnimations.removeAll { animation in
            // Don't remove looping animations
            if animation.loop {
                return false
            }
            let elapsed = now.timeIntervalSince(animation.startTime)
            return elapsed > (animation.duration + animation.fadeOutDuration)
        }
    }
}
