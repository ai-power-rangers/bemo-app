//
//  GIFImageView.swift
//  Bemo
//
//  SwiftUI view for displaying animated GIF images
//

// WHAT: Displays animated GIF images using UIKit's image animation capabilities
// ARCHITECTURE: UIViewRepresentable bridging UIKit's animated image support to SwiftUI
// USAGE: Provide GIF filename (without extension) from Resources folder

import SwiftUI
import UIKit

struct GIFImageView: UIViewRepresentable {
    let gifName: String
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        
        // Load GIF
        if let gifImage = loadGIF(named: gifName) {
            imageView.image = gifImage
            imageView.animationRepeatCount = 0  // 0 means infinite loop
            imageView.startAnimating()
            print("CharacterAnimationService: Started animating GIF '\(gifName)' with duration: \(gifImage.duration), repeat count: \(imageView.animationRepeatCount)")
        }
        
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        // No updates needed
    }
    
    private func loadGIF(named name: String) -> UIImage? {
        // Clean the name to remove extension if provided
        let cleanName = name.replacingOccurrences(of: ".gif", with: "")
        
        // Try to find the GIF file in the bundle
        // First try with subdirectory
        var url: URL?
        
        // Try with Animations subdirectory
        url = Bundle.main.url(forResource: cleanName, withExtension: "gif", subdirectory: "Animations")
        
        // If not found, try in Resources root
        if url == nil {
            url = Bundle.main.url(forResource: cleanName, withExtension: "gif")
        }
        
        // Try with full path
        if url == nil {
            url = Bundle.main.url(forResource: "Animations/\(cleanName)", withExtension: "gif")
        }
        
        // If we found the URL, load the GIF
        if let gifURL = url {
            if let image = loadGIFFromURL(gifURL) {
                print("CharacterAnimationService: Successfully loaded GIF '\(cleanName)' from '\(gifURL.path)'")
                return image
            }
        }
        
        // Fallback: try with Bundle.main.path as before
        let searchPaths = [
            (resource: cleanName, type: "gif"),
            (resource: "Animations/\(cleanName)", type: "gif"),
            (resource: name, type: nil), // Try with original name
        ]
        
        for path in searchPaths {
            if let bundlePath = Bundle.main.path(forResource: path.resource, ofType: path.type) {
                if let image = loadGIFFromPath(bundlePath) {
                    print("CharacterAnimationService: Successfully loaded GIF from '\(bundlePath)'")
                    return image
                }
            }
        }
        
        print("CharacterAnimationService: Could not find GIF named '\(name)' in any search path")
        print("CharacterAnimationService: Searched for: \(cleanName).gif")
        return nil
    }
    
    private func loadGIFFromURL(_ url: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        
        return loadGIFFromData(data)
    }
    
    private func loadGIFFromPath(_ path: String) -> UIImage? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        
        return loadGIFFromData(data)
    }
    
    private func loadGIFFromData(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        
        let count = CGImageSourceGetCount(source)
        var images: [UIImage] = []
        var duration: TimeInterval = 0
        
        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                let image = UIImage(cgImage: cgImage)
                images.append(image)
                
                // Get frame duration
                if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                   let gifDict = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any],
                   let frameDuration = gifDict[kCGImagePropertyGIFDelayTime as String] as? TimeInterval {
                    duration += frameDuration
                }
            }
        }
        
        if images.isEmpty {
            return nil
        }
        
        return UIImage.animatedImage(with: images, duration: duration)
    }
}
