import * as THREE from 'three';
import { entities, blueBase, redBase, makeEnemyMech } from './entities.js';
import { game, stats } from './state.js';
import { distXZ, losBlocked, localToWorld, nearestEnemyOf, collideCircle } from './helpers.js';
import { spawnProjectile } from './projectiles.js';
import { beep } from './audio.js';
import { player } from './player.js';
import { showMessage } from './hud.js';

/* ============================================================
   AI: turrets + enemy mechs + waves
============================================================ */
const _v = new THREE.Vector3();

export function updateTurret(e, dt) {
  e.cool -= dt;
  e.retarget -= dt;
  if (e.retarget <= 0) {
    e.retarget = 0.4;
    const t = nearestEnemyOf(e.team, e.group.position, e.range, { exclude: ['base'] });
    e.target = (t && !losBlocked(e.group.position.x, e.group.position.z, t.group.position.x, t.group.position.z, 3)) ? t : null;
  }
  if (!e.target || !e.target.alive) { e.target = null; return; }

  const tp = e.target.group.position;
  const desired = Math.atan2(tp.x - e.group.position.x, tp.z - e.group.position.z);
  let diff = desired - e.yaw;
  diff = Math.atan2(Math.sin(diff), Math.cos(diff));
  const turn = 4 * dt;
  e.yaw += Math.max(-turn, Math.min(turn, diff));
  e.head.rotation.y = e.yaw;

  if (Math.abs(diff) < 0.15 && e.cool <= 0) {
    e.cool = e.fireInterval;
    const muzzle = localToWorld(e, 0, 3.0, 2.2);
    const dir = _v.set(tp.x, Math.min(3.5, e.target.hitHeight * 0.55), tp.z).sub(muzzle).normalize().clone();
    spawnProjectile({ pos: muzzle, dir, speed: 100, damage: e.damage, team: e.team, life: 1 });
    if (e.team === 'blue') beep(340, 120, 0.05, 'square', 0.03);
    else beep(240, 80, 0.05, 'square', 0.03);
  }
}

export function updateEnemyMech(e, dt) {
  e.cool -= dt;
  e.retarget -= dt;
  if (e.retarget <= 0) {
    e.retarget = 0.5;
    // priority: player nearby > blue turret nearby > blue base
    let t = null;
    if (player.alive && distXZ(e.group.position, player.group.position) < 52) t = player;
    if (!t) {
      let bd = 42;
      for (const o of entities) {
        if (!o.alive || o.team !== 'blue' || o.kind !== 'turret') continue;
        const d = distXZ(e.group.position, o.group.position);
        if (d < bd) { bd = d; t = o; }
      }
    }
    if (!t) t = blueBase.alive ? blueBase : (player.alive ? player : null);
    e.target = t;
  }
  if (!e.target || !e.target.alive) return;

  const tp = e.target.group.position;
  const d = distXZ(e.group.position, tp);
  const attackRange = e.target.kind === 'base' ? 32 : e.range;
  const clear = !losBlocked(e.group.position.x, e.group.position.z, tp.x, tp.z, 3);

  // face target / travel direction
  const desired = Math.atan2(tp.x - e.group.position.x, tp.z - e.group.position.z);
  let diff = desired - e.yaw;
  diff = Math.atan2(Math.sin(diff), Math.cos(diff));
  const turn = 3.2 * dt;
  e.yaw += Math.max(-turn, Math.min(turn, diff));
  e.group.rotation.y = e.yaw;

  const shouldMove = d > attackRange * 0.85 || !clear;
  if (shouldMove) {
    e.group.position.x += Math.sin(e.yaw) * e.speed * dt;
    e.group.position.z += Math.cos(e.yaw) * e.speed * dt;
    collideCircle(e.group.position, 2.2);
    e.walkPhase += dt * 7;
    const sw = Math.sin(e.walkPhase) * 0.55;
    e.model.legL.rotation.x = sw;
    e.model.legR.rotation.x = -sw;
    e.group.position.y = Math.abs(Math.sin(e.walkPhase)) * 0.25;
  } else {
    e.group.position.y = 0;
  }

  if (d < attackRange && clear && Math.abs(diff) < 0.25 && e.cool <= 0) {
    e.cool = e.fireInterval * (0.8 + Math.random() * 0.5);
    const muzzle = localToWorld(e, (Math.random() < 0.5 ? -2.2 : 2.2), 4.5, 2.7);
    const spread = (Math.random() - 0.5) * 0.06;
    const dir = _v.set(tp.x - muzzle.x, 0, tp.z - muzzle.z).normalize().clone();
    dir.applyAxisAngle(new THREE.Vector3(0, 1, 0), spread);
    dir.y = (Math.min(3.5, e.target.hitHeight * 0.5) - muzzle.y) / Math.max(d, 1);
    dir.normalize();
    spawnProjectile({ pos: muzzle, dir, speed: 70, damage: e.damage, team: 'red', life: 1.4 });
    beep(200, 70, 0.05, 'square', 0.025);
  }
}

/* waves */
let nextWaveAt = 5;
export function updateWaves() {
  if (game.elapsed < nextWaveAt || !redBase.alive) return;
  nextWaveAt = game.elapsed + 22;
  const alive = entities.filter(e => e.kind === 'mech' && e.team === 'red').length;
  if (alive >= 12) return;
  stats.wave++;
  const n = Math.min(2 + Math.floor(stats.wave / 2), 6);
  for (let i = 0; i < n; i++) {
    const x = (i - (n - 1) / 2) * 7;
    makeEnemyMech(x + (Math.random() - 0.5) * 3, -96 + Math.random() * 4);
  }
  showMessage(`WAVE ${stats.wave} INCOMING`, '#ff9a5a');
  beep(90, 55, 0.6, 'sawtooth', 0.12);
}
