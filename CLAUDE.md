# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Bemo is an iOS app built with SwiftUI following the MVVM-S (Model-View-ViewModel-Service) architecture pattern. The app is designed as an educational game platform for children with a focus on computer vision integration and modularity.

## Build and Development Commands

### Building the Project
```bash
# Open the project in Xcode
open Bemo.xcodeproj

# Build from command line (requires Xcode Command Line Tools)
xcodebuild -project Bemo.xcodeproj -scheme Bemo -configuration Debug build

# Clean build
xcodebuild -project Bemo.xcodeproj -scheme Bemo -configuration Debug clean build
```

### Running Tests
```bash
# Run unit tests
xcodebuild test -project Bemo.xcodeproj -scheme Bemo -destination 'platform=iOS Simulator,name=iPhone 15'

# Run a specific test
xcodebuild test -project Bemo.xcodeproj -scheme Bemo -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:BemoTests/SpecificTestClass
```

### Code Quality
```bash
# Format Swift code (requires SwiftFormat)
swiftformat .

# Lint Swift code (requires SwiftLint)
swiftlint
```

## Architecture Overview

The app follows MVVM-S architecture with a plug-and-play game engine system:

### Application Flow

1. **App Entry**: `App/BemoApp.swift` creates the `AppCoordinator`
2. **Navigation**: `AppCoordinator` manages navigation between Lobby, Games, and Parent Dashboard
3. **First Screen**: `GameLobbyView` is shown by default where children select games

### Core Architecture Components

1. **Game Engine** (Features/Game/Engine/)
   - `Game` protocol: Contract for all games (must provide their own SwiftUI view)
   - `GameDelegate` protocol: Communication channel from games back to the host
   - `GameHostViewModel`: Manages game lifecycle, connects CVService to games
   - `GameHostView`: Container for the active game's view

2. **Service Layer** (Services/)
   - `CVService`: Computer vision with Combine publisher for recognized pieces
   - `ProfileService`: Manages active child's session
   - `APIService`: Backend communication
   - `GamificationService`: XP, levels, and achievements
   - All services injected via `DependencyContainer`

3. **Data Flow Pattern**
   ```
   CVService → RecognizedPiece → GameHostViewModel → Game.processRecognizedPieces() 
   → PlayerActionOutcome → UI Update + Delegate callbacks
   ```

### Key Implementation Details

- **Reactive Programming**: Services use Combine publishers for event streaming
- **Self-Contained Games**: Each game provides its own view via `makeGameView(delegate:)`
- **Dependency Injection**: ViewModels receive services through initializers
- **Navigation**: AppCoordinator publishes `rootView` for navigation changes

### Project Structure

```
Bemo/
├── App/
│   └── BemoApp.swift         # App entry point with @main
├── Core/
│   ├── AppCoordinator.swift  # Navigation management
│   └── DependencyContainer.swift
├── Features/
│   ├── Game/
│   │   ├── Engine/          # Game framework
│   │   └── Games/           # Individual games
│   │       └── Tangram/
│   ├── Lobby/               # Game selection
│   └── ParentDashboard/     # Parent controls
├── Services/                # Business logic layer
└── Shared/
    └── Models/              # Data models
```

## Swift Development Guidelines

Based on project's Cursor rules (`.cursor/rules/swift-ui.mdc`):

- Use MVVM architecture with SwiftUI
- Prefer structs over classes, protocol-oriented programming
- Use async/await for concurrency, Result type for errors
- @Published and @StateObject for state management
- SwiftUI first approach, UIKit only when necessary
- Handle all screen sizes with SafeArea and GeometryReader

  You are an expert iOS developer using Swift and SwiftUI. Follow these guidelines:


  # Code Structure

  - Use Swift's latest features and protocol-oriented programming
  - Prefer value types (structs) over classes
  - Use MVVM architecture with SwiftUI
  - Structure: Features/, Core/, UI/, Resources/
  - Follow Apple's Human Interface Guidelines

  
  # Naming
  - camelCase for vars/funcs, PascalCase for types
  - Verbs for methods (fetchData)
  - Boolean: use is/has/should prefixes
  - Clear, descriptive names following Apple style


  # Swift Best Practices

  - Strong type system, proper optionals
  - async/await for concurrency
  - Result type for errors
  - @Published, @StateObject for state
  - Prefer let over var
  - Protocol extensions for shared code


  # UI Development

  - SwiftUI first, UIKit when needed
  - SafeArea and GeometryReader for layout
  - Handle all screen sizes and orientations
  - Implement proper keyboard handling


  # Performance

  - Lazy load views and images
  - Optimize network requests
  - Background task handling
  - Proper state management
  - Memory management


  # Data & State

  - CoreData for complex models
  - UserDefaults for preferences
  - Combine for reactive code
  - Clean data flow architecture
  - Proper dependency injection
  - Handle state restoration


  # Essential Features

  - Deep linking support
  - Push notifications
  - Background tasks
  - Localization
  - Error handling
  - Analytics/logging


  # Development Process

  - Use SwiftUI previews
  - Documentation


  Follow Apple's documentation for detailed implementation guidance.