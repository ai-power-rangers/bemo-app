DependencyContainer manages injecting services into views. Services are kept by the container and injected via appcontainer when views are initialized/loaded

MVVM + S

Models 

ViewModels
    - Depend on Protocols instead of the implementations?

Views

Services

AppContainer
    - Manages views and DI
    - Decides which views to show based on state + logged in, first time, etc
DepedencyContainer
    - Manages all services
Game Delegate 
    - Let's games manage their own state and kicks back to AppContainer
    Setup: When the main GameViewModel creates the TangramGame instance, it passes itself as the delegate: tangramGame.makeGameView(delegate: self).
    Action within the Game: Inside the TangramGameView, the user taps a "Quit" button.
    Delegate Call: The TangramGameViewModel calls delegate.gameDidRequestQuit().
    App-Level Navigation: The main GameViewModel receives this call. It then tells the AppCoordinator to navigate away from the game screen and back to the lobby.


App
Core
Features
    Games
    Lobby
    Parent Dashboard
    Onboarding
Services
Shared
    Models
    Views
    Extensions
    Utils
Resources

@environrmentobject allows us to cleanly DI into child views b/c children can access all parent DI without explicit services initialized into the view

How do we handle events? 
    - Uses Apples combine framwork


How is AVFoundation
    - It auto drops late frames

Linter checking for drift from arhictecture
Cursor Rules + Apple Docs for frameworks we need 
CI/CD?

GameHostViewModel -> The clean architectural solution is to use a Configuration Object and have the GameHostViewModel act as the mediator.

the game doesn't talk to the CV service. Instead, it publishes its desired configuration, and the host listens and applies it.

