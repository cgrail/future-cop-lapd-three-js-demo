# iOS native port — plan & status

Native Swift/SceneKit port of the web game (single player only) living in `ios/`.
This file exists so a later session can pick up exactly where work stopped —
update the checklist as files land.

## Scope decisions (made once, don't re-litigate)

- **SceneKit + SwiftUI**, iPhone only, **landscape only**, deployment target iOS 17.
  SceneKit maps 1:1 onto the three.js scene graph (same right-handed y-up axes,
  `eulerAngles.y = yaw` matches `group.rotation.y = yaw`, forward = `(sin yaw, 0, cos yaw)`).
- **Single player only.** Multiplayer (lobby/relay/remote.js/net.js) is out of scope.
  All `MP.active` branches resolve to the SP path.
- Xcode project is hand-written with the Xcode 16 `objectVersion 77` format using a
  `PBXFileSystemSynchronizedRootGroup` — every file under `ios/MechVsMech/` is auto-added
  to the target, so new Swift files need **no pbxproj edits**. Info.plist is generated
  (`GENERATE_INFOPLIST_FILE = YES` + `INFOPLIST_KEY_*`).
- Authoritative entity positions are `x/y/z: Double` on the `Entity` class; the SCNNode
  is synced after each update (JS mutates `group.position` directly — same math, Float
  conversion only at the node boundary).
- Restart / level switch = throw away the whole `GameEngine` and build a new one
  (the web version's `location.reload()` analog). No reset logic inside the engine.
- Controls mirror `game/systems/mobile.js`: joystick scheme (left half floating stick =
  move/strafe, right half drag = turn, hold = fire) and gyro scheme (CoreMotion; compass
  yaw is **1:1 by design — never add gain**; lean forward/back moves, side tilt strafes,
  any touch fires). Rocket / build-turret are on-screen buttons. No minimap (web hides
  it on phones too).
- Audio: tiny synth ported to precomputed `AVAudioPCMBuffer`s (beep sweep, biquad-filtered
  laser/boom) played through a pool of `AVAudioPlayerNode`s; music = `AVAudioPlayer`
  looping the bundled mp3 (CC0), ducked on game over.
- `levels.txt` and `rocky-musicloop.mp3` are **copies** of the web assets — re-copy when
  the web versions change (`cp levels/levels.txt ios/MechVsMech/Resources/`).

## File map (JS → Swift) and status

| Status | Swift file | Ports |
|---|---|---|
| [x] | `MechVsMech.xcodeproj/project.pbxproj` | — hand-written, synchronized root group |
| [x] | `Resources/levels.txt`, `Resources/rocky-musicloop.mp3` | copies of web assets |
| [x] | `Engine/State.swift` | core/state.js (difficulty tables, game/touch/stats, costs) |
| [x] | `Engine/Levels.swift` | world.js level parsing + bundle split, cells grid |
| [x] | `Engine/Terrain.swift` | world.js queries (groundHeightAt, collideTerrain) + world meshes (ground texture via CoreGraphics, greedy boxes, ramp wedge geometry) |
| [x] | `Engine/Entities.swift` | entities.js (Entity class, mech/turret/base models, health bars, factories) |
| [x] | `Engine/Helpers.swift` | core/helpers.js (localToWorld, aimYOf, losBlocked, nearestEnemyOf, collideCircle, updateVertical, separateMechs, spawnPointFor) |
| [x] | `Engine/Particles.swift` | particles.js |
| [x] | `Engine/Projectiles.swift` | projectiles.js (spawn/update, damage/kill, splash, salvage payouts) |
| [x] | `Engine/Player.swift` | player.js (spawn, aim assist, gun/rocket, update, respawn) |
| [x] | `Engine/AI.swift` | ai.js (turret AI, mech AI incl. detour/strafe/aggro, waves) |
| [x] | `Engine/Build.swift` | build.js (placement validity + placing) |
| [x] | `Engine/Audio.swift` | audio.js synth + music |
| [x] | `Engine/GameEngine.swift` | main.js loop + camera, scene.js (lights/fog), flow.js (start/end/applyDifficulty) |
| [x] | `TouchControls.swift` | mobile.js (multitouch joystick/look + CoreMotion gyro) |
| [x] | `GameView.swift` | SCNView wrapper (UIViewRepresentable) + render delegate |
| [x] | `UI/HUDView.swift` | hud.js (hp column, salvage, base bars, message, hint, respawn, buttons) |
| [x] | `UI/Menus.swift` | flow.js screens (mode → menu → level select → end screen) |
| [x] | `AppModel.swift` | screen state machine, engine lifecycle, persisted difficulty/scheme |
| [x] | `MechVsMechApp.swift` + `ContentView.swift` | @main, layering game view + overlays |
| [x] | `ios/README.md` | how to open/build/sync assets, what's not ported |

## Gameplay constants that must match the web version

TILE 8 · LOW −4 · WALL_H 10 · STEP 0.75 · tiers l/g/h = −4/0/+4 · player hp 300,
speed 16 (no boost on touch), gun cool 0.11 dmg 9 speed 130, rocket cool 0.55 dmg 60
speed 60 splash r9, salvage start 150, costs 20/100, trickle 3/s × salvageMult,
kill +40×mult, turret kill +80×mult, self-repair 9/s after 5 s, respawn after 4 s,
waves start t=5, camera behind 21 / up 26 / lookahead 17 / ease 1−e^(−8dt),
fog 90–280 playing & 300–900 menu, bg 0x0b0d16, difficulty tables in State.swift
copied verbatim from core/state.js.

## Verification

- `swiftc -parse` every .swift (CLT only syntax check — **no Xcode on this machine**,
  cannot compile against the iOS SDK here).
- `plutil -lint` the pbxproj.
- User must build/run in Xcode on device; gyro sign conventions (lean/strafe direction,
  landscape left vs right) need an on-device sanity check — flagged in README.

## Remaining / follow-ups

- All files written and syntax-checked; level parser + terrain queries unit-run against all 56 levels (all pass). NOT yet compiled for iOS (no Xcode on this machine) — first Xcode build may surface small type errors; gyro signs need on-device verification (see README).
