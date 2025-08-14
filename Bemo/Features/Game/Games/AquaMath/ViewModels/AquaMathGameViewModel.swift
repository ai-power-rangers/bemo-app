//
//  AquaMathGameViewModel.swift
//  Bemo
//
//  ViewModel for AquaMath game orchestrating all game logic
//

// WHAT: Central ViewModel managing AquaMath game state, coordinating services and scenes
// ARCHITECTURE: @Observable ViewModel in MVVM-S pattern, single source of truth
// USAGE: Created by AquaMathGame, bridges UI events, services, and rendering scenes

import SwiftUI
import Observation
import SpriteKit

@Observable
class AquaMathGameViewModel {
    
    // MARK: - Game State
    
    private(set) var gameState: AquaMathGameState = AquaMathGameState()
    private(set) var equation: Equation = Equation(groups: [], mode: .add)
    private(set) var isGameActive: Bool = false
    private(set) var levelConfig: LevelConfig
    
    // MARK: - UI State
    
    var selectedMode: GameMode {
        get { gameState.mode }
        set { 
            gameState.mode = newValue
            updateEquation()
        }
    }
    
    var score: Int { gameState.score }
    var waterLevel: Double { gameState.waterLevel }
    var currentLevel: Int { gameState.currentLevel }
    var comboCount: Int { gameState.comboCount }
    var collectedFish: [Fish] { gameState.collectedFish }
    
    // MARK: - Dependencies
    
    private weak var delegate: GameDelegate?
    private var gameScene: GameScene?
    private var workspaceEngine: WorkspaceEngine
    var bubbleManager: BubbleManager  // Made accessible for GameScene
    private var scoringService: ScoringService
    private var waterSimulationService: WaterSimulationService
    var audioService: AudioHapticsService  // Made accessible for GameView
    
    // MARK: - Computed Properties
    
    var equationString: String {
        if equation.expression.isEmpty {
            return ""
        }
        if let result = equation.result {
            return "\(equation.expression) = \(result)"
        }
        return equation.expression
    }
    
    var targetValue: Int? {
        equation.result
    }
    
    var availableTiles: [TileKind] {
        switch gameState.mode {
        case .count:
            return (1...6).map { TileKind.dot($0) }
        case .add, .connect, .multiply:
            return (0...9).map { TileKind.numeral($0) }
        }
    }
    
    // MARK: - Initialization
    
    init(delegate: GameDelegate) {
        self.delegate = delegate
        self.levelConfig = LevelConfig.config(for: 1)
        self.workspaceEngine = WorkspaceEngine()
        self.scoringService = ScoringService()
        self.waterSimulationService = WaterSimulationService()
        self.audioService = AudioHapticsService()
        
        // Initialize bubbleManager after levelConfig is set
        let initialConfig = LevelConfig.config(for: 1)
        self.bubbleManager = BubbleManager(levelConfig: initialConfig)
        
        startLevel(1)
    }
    
    // MARK: - Scene Management
    
    func setGameScene(_ scene: GameScene) {
        self.gameScene = scene
        scene.setViewModel(self)
    }
    
    // MARK: - Game Flow
    
    func startLevel(_ level: Int) {
        gameState.currentLevel = level
        gameState.score = 0
        gameState.waterLevel = 0.0
        gameState.tileGroups = []
        gameState.activeBubbles = []
        gameState.comboCount = 0
        levelConfig = LevelConfig.config(for: level)
        bubbleManager.updateConfig(levelConfig)
        isGameActive = true
        
        // Notify scene to reset
        gameScene?.resetScene()
    }
    
    func pauseGame() {
        isGameActive = false
    }
    
    func resumeGame() {
        isGameActive = true
    }
    
    func reset() {
        startLevel(1)
    }
    
    // MARK: - Tile Tap Handling
    
    func tapTile(_ tileKind: TileKind) {
        guard isGameActive else { return }
        
        // Create new tile and add to workspace
        let newTile = Tile(kind: tileKind)
        
        // Add tile to first group or create new group
        if gameState.tileGroups.isEmpty {
            let newGroup = TileGroup(tiles: [newTile])
            gameState.tileGroups = [newGroup]
        } else {
            // Add to the first group (simple linear addition)
            gameState.tileGroups[0].tiles.append(newTile)
        }
        
        updateEquation()
        
        // Update scene to show tile in workspace
        gameScene?.addTileToWorkspace(newTile)
        audioService.playTileDrop()
        
        // Check if we should evaluate
        let tileCount = gameState.tileGroups.first?.tiles.count ?? 0
        let shouldEvaluate = (gameState.mode == .connect && tileCount >= 1) || 
                           (gameState.mode != .connect && tileCount >= 2)
        
        if shouldEvaluate {
            // Check for matches immediately
            checkBubbleMatches()
        }
    }
    
    // MARK: - Workspace Management
    
    func removeTileGroup(_ groupId: UUID) {
        gameState.tileGroups.removeAll { $0.id == groupId }
        updateEquation()
        checkBubbleMatches()
    }
    
    func clearWorkspace() {
        gameState.tileGroups = []
        updateEquation()
        gameScene?.clearWorkspace()
        gameScene?.highlightBubbles(matching: nil)
    }
    
    private func updateEquation() {
        equation = Equation(groups: gameState.tileGroups, mode: gameState.mode)
        gameState.lastEquationResult = equation.result
    }
    
    // MARK: - Bubble Management
    
    func spawnBubble() {
        guard isGameActive else { return }
        
        let bubble = bubbleManager.spawnBubble()
        gameState.activeBubbles.append(bubble)
        gameScene?.spawnBubble(bubble)
    }
    
    private func checkBubbleMatches() {
        guard let targetValue = equation.result else {
            gameScene?.highlightBubbles(matching: nil)
            return
        }
        
        // Highlight matching bubbles
        gameScene?.highlightBubbles(matching: targetValue)
        
        // Check if there are matching bubbles
        let hasMatches = gameState.activeBubbles.contains { $0.value == targetValue }
        
        if hasMatches {
            // Pop matching bubbles after a brief visual delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.popMatchingBubbles(value: targetValue)
            }
        } else {
            // No matches, clear workspace after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.clearWorkspace()
            }
        }
    }
    
    private func popMatchingBubbles(value: Int) {
        let matchingBubbles = gameState.activeBubbles.filter { $0.value == value }
        guard !matchingBubbles.isEmpty else { return }
        
        // Calculate score
        let scoreResult = scoringService.calculateScore(
            poppedBubbles: matchingBubbles.count,
            bubbleValue: value,
            mode: gameState.mode,
            comboCount: gameState.comboCount
        )
        
        gameState.score += scoreResult.points
        gameState.comboCount = scoreResult.newComboCount
        
        // Update water level
        let waterIncrease = waterSimulationService.calculateWaterIncrease(
            bubblesPopped: matchingBubbles.count,
            withCombo: scoreResult.isCombo
        )
        
        gameState.waterLevel = min(1.0, gameState.waterLevel + waterIncrease)
        
        // Remove bubbles from state
        gameState.activeBubbles.removeAll { bubble in
            matchingBubbles.contains { $0.id == bubble.id }
        }
        
        // Notify scene to pop bubbles
        gameScene?.popBubbles(matchingBubbles)
        gameScene?.animateWater(to: CGFloat(gameState.waterLevel))
        
        if scoreResult.isCombo {
            gameScene?.showComboText("\(scoreResult.newComboCount)X COMBO!")
            audioService.playComboSound(level: scoreResult.newComboCount)
        } else {
            audioService.playBubblePop()
        }
        
        // Clear workspace after successful pop
        clearWorkspace()
        
        // Check for level completion
        if gameState.waterLevel >= 1.0 {
            completeLevel()
        }
        
        // Check for fish unlocks
        checkFishUnlocks()
    }
    
    // Callback from scene when bubbles are popped
    func aquariumDidPopBubbles(value: Int, count: Int) {
        // This is called by the old AquariumScene - we'll migrate to new pattern
        popMatchingBubbles(value: value)
    }
    
    // MARK: - Level Completion
    
    private func completeLevel() {
        isGameActive = false
        
        let xpAwarded = scoringService.calculateXP(
            score: gameState.score,
            level: gameState.currentLevel
        )
        
        audioService.playLevelComplete()
        gameScene?.showLevelComplete()
        
        delegate?.gameDidCompleteLevel(xpAwarded: xpAwarded)
    }
    
    private func checkFishUnlocks() {
        for threshold in levelConfig.fishThresholds {
            if gameState.score >= threshold {
                let fishCount = levelConfig.fishThresholds.firstIndex(of: threshold)! + 1
                if gameState.collectedFish.count < fishCount {
                    let newFish = Fish(
                        name: "Fish \(fishCount)",
                        imageName: "fish\(fishCount)",
                        requiredScore: threshold
                    )
                    gameState.collectedFish.append(newFish)
                    gameScene?.showFishUnlocked(newFish)
                    audioService.playFishUnlock()
                }
            }
        }
    }
    
    // MARK: - Power-ups
    
    func activatePowerUp(_ bubble: BubbleModel) {
        switch bubble.type {
        case .lightning:
            activateLightning()
        case .bomb:
            activateBomb(at: bubble.position)
        case .sponge:
            activateSponge()
        case .crate:
            openCrate()
        case .normal:
            break
        }
    }
    
    private func activateLightning() {
        // Pop random bubbles
        let targetCount = min(5, gameState.activeBubbles.count)
        let targets = gameState.activeBubbles.shuffled().prefix(targetCount)
        
        for bubble in targets {
            gameState.activeBubbles.removeAll { $0.id == bubble.id }
        }
        
        gameScene?.triggerLightningEffect(on: Array(targets))
        audioService.playLightning()
    }
    
    private func activateBomb(at position: CGPoint) {
        // Pop bubbles in radius
        let radius: CGFloat = 150
        let targets = gameState.activeBubbles.filter { bubble in
            let dx = bubble.position.x - position.x
            let dy = bubble.position.y - position.y
            return sqrt(dx*dx + dy*dy) <= radius
        }
        
        for bubble in targets {
            gameState.activeBubbles.removeAll { $0.id == bubble.id }
        }
        
        gameScene?.triggerExplosion(at: position, affecting: targets)
        audioService.playExplosion()
    }
    
    private func activateSponge() {
        // Lower water level
        let reduction = waterSimulationService.spongeWaterReduction()
        gameState.waterLevel = max(0, gameState.waterLevel - reduction)
        gameScene?.animateWater(to: CGFloat(gameState.waterLevel))
        audioService.playSpongeSound()
    }
    
    private func openCrate() {
        // Award bonus points
        let bonus = scoringService.crateBonus(level: gameState.currentLevel)
        gameState.score += bonus
        gameScene?.showBonusPoints(bonus)
        audioService.playCrateOpen()
    }
    
    // MARK: - Delegate Actions
    
    func requestQuit() {
        delegate?.gameDidRequestQuit()
    }
    
    func requestHint() {
        delegate?.gameDidRequestHint()
        // Show hint overlay
        gameScene?.showHint(for: gameState.activeBubbles.first?.value)
    }
    
    // MARK: - State Persistence
    
    func saveState() -> Data? {
        return try? JSONEncoder().encode(gameState)
    }
    
    func loadState(from data: Data) {
        if let state = try? JSONDecoder().decode(AquaMathGameState.self, from: data) {
            self.gameState = state
            self.levelConfig = LevelConfig.config(for: state.currentLevel)
            self.bubbleManager.updateConfig(levelConfig)
            updateEquation()
            isGameActive = true
        }
    }
}