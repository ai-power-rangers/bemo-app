//
//  CharacterAnimationOverlay.swift
//  Bemo
//
//  Global overlay view for displaying character animations
//

// WHAT: SwiftUI overlay that renders all active character animations from CharacterAnimationService
// ARCHITECTURE: View layer in MVVM-S, observes CharacterAnimationService for animation updates
// USAGE: Added to AppCoordinator's rootView ZStack. Automatically displays animations triggered by any ViewModel

import SwiftUI

struct CharacterAnimationOverlay: View {
    let animationService: CharacterAnimationService
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(animationService.activeAnimations) { animation in
                    CharacterAnimationView(
                        animation: animation,
                        containerSize: geometry.size,
                        onRemove: {
                            animationService.removeAnimation(animation)
                        }
                    )
                    .position(animation.position.point(in: geometry.size))
                    .zIndex(Double(animation.startTime.timeIntervalSince1970))
                }
            }
        }
        .allowsHitTesting(animationService.activeAnimations.contains { $0.interactive })
    }
}
