import Foundation

/* ============================================================
   Turret building — placed directly in front of the player.
   Ports systems/build.js.
============================================================ */
extension GameEngine {

    private func buildPosValid(_ p: SIMD3<Double>) -> Bool {
        if abs(p.x) > level.arenaHW - 4 || abs(p.z) > level.arenaHD - 4 { return false }
        // needs flat footing on the player's own level (no walls, ramps or cliffs)
        let h = level.groundHeightAt(p.x, p.z)
        if abs(h - player.y) > 0.5 { return false }
        for (ox, oz) in [(2.5, 0.0), (-2.5, 0.0), (0.0, 2.5), (0.0, -2.5)] {
            if abs(level.groundHeightAt(p.x + ox, p.z + oz) - h) > 0.1 { return false }
        }
        for e in entities {
            if !e.alive || e === player { continue }
            if distXZ(p.x, p.z, e.x, e.z) < e.hitRadius + 4 { return false }
        }
        return true
    }

    @discardableResult
    func placeTurretDirect() -> Bool {
        if !player.alive { return false }
        let p = localToWorld(player, 0, 0, 9)
        if stats.salvage < Costs.turret {
            audio.beep(f: 140, f2: 90, dur: 0.15, type: .square, vol: 0.1)
            delegate?.engineBuildHint("NOT ENOUGH SALVAGE — NEED 🛢️ \(Int(Costs.turret))")
            return false
        }
        if !buildPosValid(p) {
            audio.beep(f: 140, f2: 90, dur: 0.15, type: .square, vol: 0.1)
            delegate?.engineBuildHint("INVALID POSITION — NEEDS FLAT OPEN GROUND")
            return false
        }
        stats.salvage -= Costs.turret
        stats.turretsBuilt += 1
        makeTurretEntity(team: player.team, x: p.x, z: p.z)
        spawnSpark(p.x, level.groundHeightAt(p.x, p.z) + 2, p.z)
        audio.beep(f: 500, f2: 1100, dur: 0.15, type: .sine, vol: 0.12)
        return true
    }
}
