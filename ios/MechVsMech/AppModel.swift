import Foundation
import SwiftUI

/* ============================================================
   AppModel — the screen state machine (flow.js's overlay logic)
   plus engine lifecycle. A level switch or redeploy replaces the
   whole engine, the web version's location.reload() analog.
============================================================ */

struct GameMessage: Equatable {
    let id: UUID
    let text: String
    let colorHex: Int
}

/* last-resort level so the app still runs if levels.txt is missing/broken */
private let FALLBACK_LEVEL = """
wwwwwwwwww
wggSggRggw
wggggggggw
wggggggggw
wggggggggw
wggggggggw
wggPggBggw
wwwwwwwwww
"""

final class AppModel: ObservableObject {

    enum Screen {
        case mode, menu, levelSelect, playing, over
    }

    let levels: [LevelInfo]
    @Published var screen: Screen = .mode
    @Published var hud = HudSnapshot()
    @Published var message: GameMessage?
    @Published var buildHint: String?
    @Published var respawnVisible = false
    @Published var victory = false
    @Published private(set) var engine: GameEngine
    @Published var levelIndex: Int

    @Published var difficultyKey: DifficultyKey {
        didSet { UserDefaults.standard.set(difficultyKey.rawValue, forKey: "mechDifficulty") }
    }
    @Published var scheme: ControlScheme {
        didSet { UserDefaults.standard.set(scheme.rawValue, forKey: "mechControls") }
    }

    private let gyro = GyroController()
    private var messageClearTask: DispatchWorkItem?
    private var hintClearTask: DispatchWorkItem?

    var levelInfo: LevelInfo { levels.indices.contains(levelIndex) ? levels[levelIndex] : Self.fallbackInfo }
    var hasNextLevel: Bool { levelIndex + 1 < levels.count }

    private static let fallbackInfo = LevelInfo(
        index: 0, name: "fallback", text: FALLBACK_LEVEL,
        title: "TRAINING YARD", desc: "levels.txt could not be loaded")

    init() {
        let loaded = loadLevelBundle()
        levels = loaded
        levelIndex = 0
        difficultyKey = DifficultyKey(rawValue: UserDefaults.standard.string(forKey: "mechDifficulty") ?? "") ?? .medium
        scheme = ControlScheme(rawValue: UserDefaults.standard.string(forKey: "mechControls") ?? "") ?? .joystick
        engine = Self.makeEngine(info: loaded.first ?? Self.fallbackInfo, difficultyKey: .medium)
        engine.delegate = self
    }

    private static func makeEngine(info: LevelInfo, difficultyKey: DifficultyKey) -> GameEngine {
        if let e = try? GameEngine(levelInfo: info, difficultyKey: difficultyKey) { return e }
        // a broken level in the bundle: fall back to the built-in map
        return try! GameEngine(levelInfo: fallbackInfo, difficultyKey: difficultyKey)
    }

    private func rebuildEngine() {
        engine = Self.makeEngine(info: levelInfo, difficultyKey: difficultyKey)
        engine.delegate = self
        hud = HudSnapshot()
        respawnVisible = false
        message = nil
        buildHint = nil
    }

    // MARK: - Screen flow

    func showModeScreen() { screen = .mode }
    func showMenu() { screen = .menu }
    func showLevelSelect() { screen = .levelSelect }

    func deploy() {
        engine.requestStart(difficultyKey: difficultyKey)
        if scheme == .gyro { gyro.start(engine: engine) } else { gyro.stop() }
        screen = .playing
    }

    func selectLevel(_ index: Int) {
        guard levels.indices.contains(index) else { return }
        if index != levelIndex {
            levelIndex = index
            rebuildEngine()   // the menu orbit camera now previews this map
        }
        screen = .levelSelect
    }

    /* end screen: NEXT LEVEL advances through the bundle, REDEPLOY replays */
    func continueFromEndScreen() {
        gyro.stop()
        if victory && hasNextLevel { levelIndex += 1 }
        rebuildEngine()
        screen = .menu
    }
}

/* ============================================================
   EngineDelegate — called on the SceneKit render thread; every
   handler hops to the main thread before touching @Published
============================================================ */
extension AppModel: EngineDelegate {

    func engineHud(_ hud: HudSnapshot) {
        DispatchQueue.main.async { self.hud = hud }
    }

    func engineMessage(_ text: String, colorHex: Int) {
        DispatchQueue.main.async {
            let msg = GameMessage(id: UUID(), text: text, colorHex: colorHex)
            self.message = msg
            self.messageClearTask?.cancel()
            let task = DispatchWorkItem { if self.message == msg { self.message = nil } }
            self.messageClearTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6, execute: task)
        }
    }

    func engineBuildHint(_ text: String) {
        DispatchQueue.main.async {
            self.buildHint = text
            self.hintClearTask?.cancel()
            let task = DispatchWorkItem { self.buildHint = nil }
            self.hintClearTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: task)
        }
    }

    func engineRespawnVisible(_ visible: Bool) {
        DispatchQueue.main.async { self.respawnVisible = visible }
    }

    func engineGameOver(victory: Bool) {
        DispatchQueue.main.async {
            self.gyro.stop()
            // the web end screen appears 1.4s after the base explodes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                self.victory = victory
                self.screen = .over
            }
        }
    }
}
