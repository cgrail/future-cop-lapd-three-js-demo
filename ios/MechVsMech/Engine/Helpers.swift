import Foundation
import simd

/* ============================================================
   Math / collision helpers — ports core/helpers.js
============================================================ */

func distXZ(_ ax: Double, _ az: Double, _ bx: Double, _ bz: Double) -> Double {
    let dx = ax - bx, dz = az - bz
    return (dx * dx + dz * dz).squareRoot()
}

func distXZ(_ a: Entity, _ b: Entity) -> Double { distXZ(a.x, a.z, b.x, b.z) }

/* where guns auto-point on a target (torso height above its ground) */
func aimY(_ e: Entity) -> Double {
    e.y + min(3.5, e.hitHeight * 0.55)
}

/* muzzle offsets in an entity's local frame (forward = +z at yaw 0) */
func localToWorld(_ e: Entity, _ ox: Double, _ oy: Double, _ oz: Double) -> SIMD3<Double> {
    let s = sin(e.yaw), c = cos(e.yaw)
    return SIMD3(
        e.x + ox * c + oz * s,
        e.y + oy,
        e.z - ox * s + oz * c
    )
}

extension GameEngine {

    /* 3D line of sight: blocked where the ray dips into terrain or walls.
       A cliff rim naturally blocks shots down a level until the shooter
       steps up to the edge. */
    func losBlocked(_ ax: Double, _ ay: Double, _ az: Double,
                    _ bx: Double, _ by: Double, _ bz: Double) -> Bool {
        let dx = bx - ax, dy = by - ay, dz = bz - az
        let steps = Int(ceil((dx * dx + dz * dz).squareRoot() / 2))
        guard steps > 1 else { return false }
        for i in 1..<steps {
            let t = Double(i) / Double(steps)
            if ay + dy * t < level.groundHeightAt(ax + dx * t, az + dz * t) + 0.25 {
                return true
            }
        }
        return false
    }

    func nearestEnemyOf(team: Team, x: Double, z: Double, range: Double, excludeBase: Bool = false) -> Entity? {
        var best: Entity? = nil
        var bestD = range
        for e in entities {
            if !e.alive || e.team == team { continue }
            if excludeBase && e.kind == .base { continue }
            let d = distXZ(x, z, e.x, e.z)
            if d < bestD {
                bestD = d
                best = e
            }
        }
        return best
    }

    /* circle vs terrain tiles + solid entities + arena clamp; y = walker's height */
    func collideCircle(x: inout Double, z: inout Double, r: Double, y: Double) {
        level.collideTerrain(x: &x, z: &z, r: r, y: y)
        // solid entities (bases, turrets) as circles
        for e in entities {
            if !e.alive || e.kind == .mech || e.kind == .player { continue }
            if abs(e.y - y) > 6 { continue } // different level
            let rr = r + e.hitRadius * 0.85
            let dx = x - e.x, dz = z - e.z
            let d = (dx * dx + dz * dz).squareRoot()
            if d < rr && d > 1e-4 {
                x += dx / d * (rr - d)
                z += dz / d * (rr - d)
            }
        }
        x = max(-level.arenaHW + r, min(level.arenaHW - r, x))
        z = max(-level.arenaHD + r, min(level.arenaHD - r, z))
    }

    /* keep e.y glued to the ground, or fall once it walks off an edge.
       Returns true while on the ground. */
    func updateVertical(_ e: Entity, dt: Double) -> Bool {
        let gh = level.groundHeightAt(e.x, e.z)
        if gh >= e.y - 0.9 { // ground contact, incl. walking up/down ramps
            e.y = gh
            e.vy = 0
            return true
        }
        e.vy -= 50 * dt
        e.y = max(gh, e.y + e.vy * dt)
        if e.y == gh {
            e.vy = 0
            return true
        }
        return false
    }

    /* light mech-vs-mech separation */
    func separateMechs() {
        let mechs = entities.filter { $0.alive && ($0.kind == .mech || $0.kind == .player) }
        guard mechs.count > 1 else { return }
        for i in 0..<(mechs.count - 1) {
            for j in (i + 1)..<mechs.count {
                let a = mechs[i], b = mechs[j]
                if abs(a.y - b.y) > 4 { continue } // different level
                let dx = b.x - a.x, dz = b.z - a.z
                let d = (dx * dx + dz * dz).squareRoot()
                let minD = 4.4
                if d < minD && d > 1e-4 {
                    let push = (minD - d) / 2
                    a.x -= dx / d * push
                    a.z -= dz / d * push
                    b.x += dx / d * push
                    b.z += dz / d * push
                    // sync the already-positioned nodes, preserving the walk bob in y
                    a.node.position.x = Float(a.x)
                    a.node.position.z = Float(a.z)
                    b.node.position.x = Float(b.x)
                    b.node.position.z = Float(b.z)
                }
            }
        }
    }

    /* single player: the player is always blue, deploying on the P marker
       facing the red base (the team/roster fan-out of helpers.js is
       multiplayer-only and not ported) */
    func spawnPoint() -> (pos: P2, yaw: Double) {
        let pos = level.playerSpawn
        let face = level.redBase
        return (pos, atan2(face.x - pos.x, face.z - pos.z))
    }
}
