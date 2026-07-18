import Foundation
import SceneKit
import UIKit

/* ============================================================
   Explosions / particles — ports particles.js
============================================================ */

final class Particle {
    let node: SCNNode          // fragment mesh or light holder
    let isLight: Bool
    var vel: SIMD3<Double>
    let spin: Double
    var life: Double

    init(node: SCNNode, isLight: Bool, vel: SIMD3<Double>, spin: Double, life: Double) {
        self.node = node
        self.isLight = isLight
        self.vel = vel
        self.spin = spin
        self.life = life
    }
}

/* shared fragment geometry, one per color (materials are shared too) */
private let fragColors = [0xffd23c, 0xff7a2a, 0xff3a1a, 0x555555]
private let fragGeos: [SCNGeometry] = fragColors.map { color in
    let g = SCNBox(width: 0.5, height: 0.5, length: 0.5, chamferRadius: 0)
    let m = SCNMaterial()
    m.lightingModel = .constant
    m.diffuse.contents = UIColor(rgb: color)
    g.materials = [m]
    return g
}

extension GameEngine {

    func spawnExplosion(_ x: Double, _ y: Double, _ z: Double, scale: Double) {
        let n = Int(10 * scale) + 6
        for _ in 0..<n {
            let node = SCNNode(geometry: fragGeos[Int(rand01() * Double(fragGeos.count))])
            node.position = SCNVector3(x, y, z)
            let s = Float(scale * (0.5 + rand01()))
            node.scale = SCNVector3(s, s, s)
            node.castsShadow = false
            scene.rootNode.addChildNode(node)
            particles.append(Particle(
                node: node, isLight: false,
                vel: SIMD3((rand01() - 0.5) * 18 * scale, rand01() * 16 * scale + 4, (rand01() - 0.5) * 18 * scale),
                spin: (rand01() - 0.5) * 10,
                life: 0.7 + rand01() * 0.5
            ))
        }
        let light = SCNLight()
        light.type = .omni
        light.color = UIColor(rgb: 0xffa040)
        light.intensity = CGFloat(2500 * scale)
        light.attenuationStartDistance = 0
        light.attenuationEndDistance = CGFloat(40 * scale)
        let holder = SCNNode()
        holder.light = light
        holder.position = SCNVector3(x, y + 2, z)
        scene.rootNode.addChildNode(holder)
        particles.append(Particle(node: holder, isLight: true, vel: .zero, spin: 0, life: 0.25))
    }

    func spawnSpark(_ x: Double, _ y: Double, _ z: Double) {
        let node = SCNNode(geometry: fragGeos[0])
        node.position = SCNVector3(x, y, z)
        node.scale = SCNVector3(0.5, 0.5, 0.5)
        node.castsShadow = false
        scene.rootNode.addChildNode(node)
        particles.append(Particle(
            node: node, isLight: false,
            vel: SIMD3((rand01() - 0.5) * 8, rand01() * 6, (rand01() - 0.5) * 8),
            spin: 8, life: 0.25
        ))
    }

    func updateParticles(dt: Double) {
        for i in stride(from: particles.count - 1, through: 0, by: -1) {
            let p = particles[i]
            p.life -= dt
            if p.isLight {
                p.node.light?.intensity *= CGFloat(max(0, p.life / 0.25))
                if p.life <= 0 {
                    p.node.removeFromParentNode()
                    particles.remove(at: i)
                }
                continue
            }
            p.vel.y -= 40 * dt
            var pos = SIMD3<Double>(Double(p.node.position.x), Double(p.node.position.y), Double(p.node.position.z))
            pos += p.vel * dt
            p.node.eulerAngles.x += Float(p.spin * dt)
            p.node.eulerAngles.y += Float(p.spin * dt * 0.7)
            let floorY = level.groundHeightAt(pos.x, pos.z) + 0.2
            if pos.y < floorY {
                pos.y = floorY
                p.vel.y *= -0.35
                p.vel.x *= 0.7
                p.vel.z *= 0.7
            }
            p.node.position = SCNVector3(pos.x, pos.y, pos.z)
            if p.life <= 0 {
                p.node.removeFromParentNode()
                particles.remove(at: i)
            }
        }
    }
}
