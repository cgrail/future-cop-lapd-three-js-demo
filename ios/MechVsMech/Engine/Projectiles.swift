import Foundation
import SceneKit
import UIKit
import simd

/* ============================================================
   Projectiles & damage — ports projectiles.js (single player:
   every projectile is simulated locally, no cosmetic replicas)
============================================================ */

final class Projectile {
    let node: SCNNode
    var pos: SIMD3<Double>
    let vel: SIMD3<Double>
    let team: Team
    let damage: Double
    let rocket: Bool
    weak var src: Entity?
    var life: Double

    init(node: SCNNode, pos: SIMD3<Double>, vel: SIMD3<Double>, team: Team,
         damage: Double, rocket: Bool, src: Entity?, life: Double) {
        self.node = node
        self.pos = pos
        self.vel = vel
        self.team = team
        self.damage = damage
        self.rocket = rocket
        self.src = src
        self.life = life
    }
}

private func basicGeometry(_ make: () -> SCNGeometry, color: Int) -> SCNGeometry {
    let g = make()
    let m = SCNMaterial()
    m.lightingModel = .constant
    m.diffuse.contents = UIColor(rgb: color)
    g.materials = [m]
    return g
}

private let tracerGeoBlue = basicGeometry({ SCNBox(width: 0.18, height: 0.18, length: 1.6, chamferRadius: 0) }, color: 0xffe27a)
private let tracerGeoRed = basicGeometry({ SCNBox(width: 0.18, height: 0.18, length: 1.6, chamferRadius: 0) }, color: 0xff5a3a)
private let rocketGeo = basicGeometry({
    let c = SCNCylinder(radius: 0.28, height: 1.4)
    c.radialSegmentCount = 6
    return c
}, color: 0xff8a2a)

/* orient a node's +z axis along `dir` (three.js Object3D.lookAt analog) */
private func orient(_ node: SCNNode, along dir: SIMD3<Double>) {
    let d = simd_normalize(SIMD3<Float>(Float(dir.x), Float(dir.y), Float(dir.z)))
    let front = SIMD3<Float>(0, 0, 1)
    if simd_dot(d, front) < -0.9999 {
        node.simdOrientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
    } else {
        node.simdOrientation = simd_quatf(from: front, to: d)
    }
}

extension GameEngine {

    func spawnProjectile(pos: SIMD3<Double>, dir: SIMD3<Double>, speed: Double, damage: Double,
                         team: Team, rocket: Bool = false, life: Double = 3, src: Entity?) {
        let node: SCNNode
        if rocket {
            let mesh = SCNNode(geometry: rocketGeo)
            mesh.eulerAngles.x = .pi / 2      // cylinder axis y → z
            node = SCNNode()
            node.addChildNode(mesh)
        } else {
            node = SCNNode(geometry: team == .blue ? tracerGeoBlue : tracerGeoRed)
        }
        node.castsShadow = false
        node.position = SCNVector3(pos.x, pos.y, pos.z)
        orient(node, along: dir)
        scene.rootNode.addChildNode(node)
        projectiles.append(Projectile(
            node: node, pos: pos, vel: dir * speed, team: team,
            damage: damage, rocket: rocket, src: src, life: life
        ))
    }

    func damageEntity(_ e: Entity, _ dmg: Double, src: Entity?) {
        if !e.alive || phase == .over { return }
        e.hp -= dmg
        // mechs retaliate against whoever shot them, even from outside sight range
        if e.kind == .mech, let s = src, s.alive, s.team != e.team {
            e.aggro = s
            e.aggroT = 4
        }
        e.bar?.set(e.hp / e.maxHp)
        if e === player {
            player.lastDamaged = elapsed
        }
        if e.hp <= 0 { killEntity(e) }
    }

    func killEntity(_ e: Entity) {
        e.alive = false
        let scale: Double = e.kind == .base ? 3 : e.kind == .turret ? 1.2 : 1.6
        spawnExplosion(e.x, e.hitHeight / 2, e.z, scale: scale)
        audio.boom(vol: e.kind == .base ? 0.5 : 0.3, dur: e.kind == .base ? 0.8 : 0.4)

        if e.team == .red {
            let mult = difficulty.salvageMult
            if e.kind == .mech {
                stats.kills += 1
                stats.salvage += 40 * mult
            } else if e.kind == .turret {
                stats.salvage += 80 * mult
            }
        }

        if e.kind == .base {
            endGame(victory: e.team == .red)
            e.node.removeFromParentNode()
            return
        }

        if e === player {
            e.node.removeFromParentNode()
            player.respawnAt = elapsed + 4
            delegate?.engineRespawnVisible(true)
            return
        }

        e.node.removeFromParentNode()
        if let i = entities.firstIndex(where: { $0 === e }) {
            entities.remove(at: i)
        }
    }

    func splashDamage(pos: SIMD3<Double>, team: Team, radius: Double, maxDmg: Double, src: Entity?) {
        for e in entities {
            if !e.alive || e.team == team { continue }
            let dy = max(0, abs(pos.y - (e.y + e.hitHeight * 0.5)) - e.hitHeight * 0.5)
            let d = distXZ(pos.x, pos.z, e.x, e.z) - e.hitRadius + dy
            if d < radius {
                damageEntity(e, maxDmg * (1 - max(0, d) / radius), src: src)
            }
        }
    }

    func updateProjectiles(dt: Double) {
        for i in stride(from: projectiles.count - 1, through: 0, by: -1) {
            let p = projectiles[i]
            p.pos += p.vel * dt
            p.node.position = SCNVector3(p.pos.x, p.pos.y, p.pos.z)
            p.life -= dt
            var dead = p.life <= 0
            var boom = false

            // terrain: ground, walls and cliff sides all stop shots
            if !dead && p.pos.y < level.groundHeightAt(p.pos.x, p.pos.z) + 0.15 {
                dead = true
                boom = true
            }

            if !dead {
                for e in entities {
                    if !e.alive || e.team == p.team { continue }
                    if p.pos.y > e.y + e.hitHeight + 1 || p.pos.y < e.y - 1 { continue }
                    let dx = p.pos.x - e.x, dz = p.pos.z - e.z
                    let r = e.hitRadius + (p.rocket ? 0.6 : 0.25)
                    if dx * dx + dz * dz < r * r {
                        if p.rocket { boom = true }
                        else { damageEntity(e, p.damage, src: p.src) }
                        dead = true
                        spawnSpark(p.pos.x, p.pos.y, p.pos.z)
                        break
                    }
                }
            }

            if dead {
                if p.rocket && boom {
                    splashDamage(pos: p.pos, team: p.team, radius: 9, maxDmg: p.damage, src: p.src)
                    spawnExplosion(p.pos.x, max(1, p.pos.y), p.pos.z, scale: 0.9)
                    audio.boom(vol: 0.22, dur: 0.3)
                }
                p.node.removeFromParentNode()
                projectiles.remove(at: i)
            }
        }
    }
}
