# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Bemo is an iOS app built with SwiftUI following the MVVM-S (Model-View-ViewModel-Service) architecture pattern. The app is designed as an educational game platform for children with a focus on computer vision integration and modularity.


# Bemo iOS App Architecture Guide

This project follows **MVVM-S** (Model-View-ViewModel-Service) architecture with a modular game engine system.

## 🏗️ Architecture Overview

### Core Pattern: MVVM-S
- **Models**: Simple Swift structs (RecognizedPiece, PlayerActionOutcome)
- **Views**: SwiftUI views for UI presentation
- **ViewModels**: `@ObservableObject` classes handling presentation logic
- **Services**: Business logic, networking, CV processing (injected via DependencyContainer)

### Key Components
- **AppCoordinator**: Central navigation controller managing app flow
- **DependencyContainer**: Service locator providing all services via dependency injection
- **Game Engine**: Protocol-based modular system for adding games without engine modification

## 📁 Project Structure

```
Bemo/
├── App/BemoApp.swift              # App entry point with @main
├── Core/
│   ├── AppCoordinator.swift       # Navigation management + DI
│   └── DependencyContainer.swift  # Service creation & injection
├── Features/
│   ├── Game/Engine/               # Game framework protocols
│   ├── Game/Games/*/              # Individual game implementations
│   ├── Lobby/                     # Game selection
│   └── ParentDashboard/           # Parent controls
├── Services/                      # Business logic layer
└── Shared/Models/                 # Data models
```

## 🎮 Game Engine Architecture

### Adding a New Game

1. **Implement Game Protocol**:
```swift
class MyGame: Game {
    let id = "my_game"
    let title = "My Game"
    let description = "Game description"
    let recommendedAge = 5...10
    let thumbnailImageName = "my_game_thumb"
    
    func makeGameView(delegate: GameDelegate) -> AnyView {
        AnyView(MyGameView(viewModel: MyGameViewModel(delegate: delegate)))
    }
    
    func processRecognizedPieces(_ pieces: [RecognizedPiece]) -> PlayerActionOutcome {
        // Process CV input and return outcome
    }
    
    func reset() { /* Reset game state */ }
    func saveState() -> Data? { /* Serialize state */ }
    func loadState(from data: Data) { /* Restore state */ }
}
```

2. **Create Game View & ViewModel**:
```swift
struct MyGameView: View {
    @StateObject private var viewModel: MyGameViewModel
    
    var body: some View {
        // Game UI implementation
    }
}

class MyGameViewModel: ObservableObject {
    private weak var delegate: GameDelegate?
    @Published var gameState: GameState = .ready
    
    init(delegate: GameDelegate) {
        self.delegate = delegate
    }
    
    func onLevelComplete() {
        delegate?.gameDidCompleteLevel(xpAwarded: 100)
    }
    
    func onQuitRequested() {
        delegate?.gameDidRequestQuit()
    }
}
```

## 🔄 Data Flow Pattern

**CV Input Flow**:
```
CVService → RecognizedPiece[] → GameHostViewModel → Game.processRecognizedPieces() 
→ PlayerActionOutcome → UI Update + Delegate callbacks
```

**Navigation Flow**:
```
AppCoordinator → DependencyContainer → ViewModel(services) → View
```

## 🛠️ Service Implementation Pattern

### Creating a New Service

```swift
class MyService {
    private let apiClient: APIClient
    @Published var data: [DataModel] = []
    
    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }
    
    func fetchData() async throws {
        let response = try await apiClient.fetch()
        await MainActor.run {
            self.data = response
        }
    }
}
```

### Service Registration in DependencyContainer:

```swift
class DependencyContainer {
    let myService: MyService
    
    init() {
        self.myService = MyService()
        // ... other services
    }
}
```

## 📱 ViewModel Implementation Pattern

### Standard ViewModel Structure:

```swift
class MyViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var state: ViewState = .loading
    @Published var items: [Item] = []
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let service: MyService
    private let onAction: (Action) -> Void
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(service: MyService, onAction: @escaping (Action) -> Void) {
        self.service = service
        self.onAction = onAction
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        service.$data
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                self?.items = data
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    func loadData() {
        state = .loading
        Task {
            do {
                try await service.fetchData()
                await MainActor.run {
                    state = .loaded
                }
            } catch {
                await MainActor.run {
                    state = .error
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
```

## 🧭 Navigation Pattern

### AppCoordinator Navigation:

```swift
// In AppCoordinator
@Published private var currentState: AppState = .lobby

enum AppState {
    case lobby
    case game(Game)
    case parentDashboard
    case newFeature(FeatureData)  // Adding new states
}

// Navigation callbacks in ViewModels
let onFeatureRequested: (FeatureData) -> Void

// In View creation
MyFeatureView(viewModel: MyFeatureViewModel(
    service: dependencyContainer.myService,
    onComplete: { [weak self] in
        self?.currentState = .lobby
    }
))
```

## 📋 Common Implementation Patterns

### 1. Adding a New Feature Module

```swift
// 1. Create ViewModel with dependencies
class NewFeatureViewModel: ObservableObject {
    private let requiredService: RequiredService
    private let onComplete: () -> Void
    
    init(requiredService: RequiredService, onComplete: @escaping () -> Void) {
        self.requiredService = requiredService
        self.onComplete = onComplete
    }
}

// 2. Create SwiftUI View
struct NewFeatureView: View {
    @StateObject private var viewModel: NewFeatureViewModel
    
    var body: some View {
        // Implementation
    }
}

// 3. Add to AppCoordinator navigation
case .newFeature:
    NewFeatureView(viewModel: NewFeatureViewModel(
        requiredService: dependencyContainer.requiredService,
        onComplete: { [weak self] in
            self?.currentState = .lobby
        }
    ))
```

### 3. Reactive State Management

```swift
// Service publishes data
@Published var gameData: [GameData] = []

// ViewModel subscribes and transforms
service.$gameData
    .map { data in data.filter { $0.isActive } }
    .assign(to: &$filteredGames)
```

## 🚫 Anti-Patterns to Avoid

- **DON'T** bypass AppCoordinator for navigation
- **DON'T** create services directly in ViewModels (use DI)
- **DON'T** make games depend on external services (use delegate pattern)
- **DON'T** put business logic in Views (belongs in ViewModels/Services)
- **DON'T** break the unidirectional data flow

## 📝 File Header Template

```swift
//
//  FileName.swift
//  Bemo
//
//  Brief description of the file's purpose
//

// WHAT: What this file does and its main responsibility
// ARCHITECTURE: Where it fits in MVVM-S (ViewModel/Service/etc.)
// USAGE: How to use this file, key methods, initialization requirements
```
Follow these patterns for consistency and maintainability across the Bemo codebase.

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