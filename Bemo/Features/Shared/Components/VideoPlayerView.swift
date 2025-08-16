//
//  VideoPlayerView.swift
//  Bemo
//
//  SwiftUI view for displaying video animations
//

// WHAT: Displays looping video animations (MP4, MOV) without controls
// ARCHITECTURE: Wraps AVPlayer in SwiftUI for seamless video playback
// USAGE: Provide video filename from Resources folder, plays automatically in loop

import SwiftUI
import AVKit
import AVFoundation

struct VideoPlayerView: UIViewControllerRepresentable {
    let videoName: String
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        
        if let url = findVideoURL(named: videoName) {
            let player = AVPlayer(url: url)
            controller.player = player
            
            // Set up looping
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { _ in
                player.seek(to: .zero)
                player.play()
            }
            
            // Start playing
            player.play()
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // No updates needed
    }
    
    private func findVideoURL(named name: String) -> URL? {
        // Try common video extensions
        let extensions = ["mp4", "mov", "m4v"]
        
        for ext in extensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        
        // Try without extension (in case it's already included)
        if let url = Bundle.main.url(forResource: name, withExtension: nil) {
            return url
        }
        
        print("CharacterAnimationService: Could not find video named '\(name)'")
        return nil
    }
}
