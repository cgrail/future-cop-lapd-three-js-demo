# MECH VS MECH — native iPhone port

A native Swift/SceneKit port of the web game one directory up. Single player only
(campaign vs. the AI waves) — multiplayer stays on the web version.

## Building

Requires Xcode 16 or newer (the project uses the synchronized-folder format).

1. `open ios/MechVsMech.xcodeproj`
2. Signing & Capabilities → pick your team (bundle id `de.grails.mechvsmech`).
3. Run on an iPhone or the simulator. Landscape only.

There are no dependencies — SceneKit, SwiftUI, AVFoundation, CoreMotion only.
Adding a Swift file anywhere under `MechVsMech/` automatically joins the target
(synchronized root group) — no project-file edits needed.

## Controls (same two schemes as the web mobile build)

- **Joystick** — left half of the screen: floating joystick (up/down moves,
  left/right strafes). Right half: drag to turn, hold to fire machine guns.
- **Gyro** — physically turn around to rotate the mech (compass is 1:1 by
  design), lean the phone forward/back to move, tilt sideways to strafe, touch
  anywhere to fire. Calibrated to your pose at the moment you tap DEPLOY.
- 🚀 / 🛰️ buttons fire rockets (🛢️ 20) and build a turret in front of you (🛢️ 100).

## Project layout

| | mirrors (web) |
|---|---|
| `MechVsMech/Engine/Levels.swift` + `Terrain.swift` | `game/world/world.js` |
| `MechVsMech/Engine/State.swift` | `game/core/state.js` (difficulty tables verbatim) |
| `MechVsMech/Engine/Helpers.swift` | `game/core/helpers.js` |
| `MechVsMech/Engine/Entities.swift`, `Player.swift`, `Projectiles.swift`, `Particles.swift` | `game/entities/*` |
| `MechVsMech/Engine/AI.swift`, `Build.swift`, `Audio.swift` | `game/systems/ai.js`, `build.js`, `audio.js` |
| `MechVsMech/Engine/GameEngine.swift` | `game/main.js` + `world/scene.js` + `core/flow.js` |
| `MechVsMech/TouchControls.swift` | `game/systems/mobile.js` |
| `MechVsMech/UI/*`, `AppModel.swift` | `game/ui/hud.js` + the overlay screens |

One `GameEngine` == one loaded level. Restart / level switch throws the engine
away and builds a new one — the native analog of the web version's
`location.reload()`; there is deliberately no reset logic.

`MechVsMech/Resources/levels.txt` and `rocky-musicloop.mp3` are **copies** of
`../levels/levels.txt` and `../assets/rocky-musicloop.mp3`. After editing levels
in the web repo, re-sync:

```bash
cp levels/levels.txt ios/MechVsMech/Resources/levels.txt
```

## Manual test list (this machine has no Xcode — code is syntax-checked and the
level parser is unit-run against all 56 bundle levels, but the app itself has
not been compiled)

- Build in Xcode; fix any small type errors the syntax check couldn't catch.
- Menu: map orbits behind the overlay; level select previews the chosen map.
- Deploy on level 1, joystick scheme: move/strafe/turn/fire, build a turret,
  fire a rocket, survive a wave, destroy the red base → VICTORY → NEXT LEVEL.
- Ramps walkable, ledges block walking up but allow dropping down, cliff rims
  block shots until you reach the edge (all driven by the terrain grid).
- **Gyro scheme on a real device**: verify turn direction is 1:1 and correct,
  lean forward = move forward, right-edge-down = strafe right. The sign
  conventions live in `TouchControls.swift` (`GyroController`) and are the one
  part of the port that could not be validated off-device — flip the sign on
  `dLean` / `dTilt` / `dYaw` there if a direction is inverted.

## Known deviations from the web version

- Multiplayer, desktop keyboard/mouse controls, and the minimap are omitted
  (the web build hides the minimap on phones anyway).
- The level-switch fly-in/out animation is an instant switch.
- Hemisphere light approximated with an ambient light; light intensities are
  eyeballed equivalents, not physically matched.
- Sound effects are pre-rendered to buffers with the same synth parameters
  (sweep, bandpass laser, filtered-noise boom) instead of live WebAudio nodes.
- Turret base and antenna use untapered cylinders (SCNCylinder has one radius).
- Tapping 🚀 without salvage shows a hint text (web only beeps there).
