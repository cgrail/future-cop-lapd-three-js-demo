import * as THREE from 'three';
import { renderer, scene, camera } from './scene.js';
import { createWorld } from './world.js';
import { entities } from './entities.js';
import { game, stats, difficulty } from './state.js';
import { player, updatePlayer } from './player.js';
import { separateMechs } from './helpers.js';
import { updateProjectiles } from './projectiles.js';
import { updateParticles } from './particles.js';
import { updateGhost } from './build.js';
import { updateTurret, updateEnemyMech, updateWaves } from './ai.js';
import { updateHud, drawMinimap } from './hud.js';
import './input.js';
import './flow.js';

createWorld(scene);

/* ============================================================
   Camera
============================================================ */
const camTarget = new THREE.Vector3();
function updateCamera(dt) {
  const p = player.group.position;
  const yaw = player.yaw;
  const behind = 21, up = 26;
  const cx = p.x - Math.sin(yaw) * behind;
  const cz = p.z - Math.cos(yaw) * behind;
  const k = 1 - Math.exp(-8 * dt);
  camera.position.x += (cx - camera.position.x) * k;
  camera.position.y += (up - camera.position.y) * k;
  camera.position.z += (cz - camera.position.z) * k;
  camTarget.set(p.x + Math.sin(yaw) * 10, 2, p.z + Math.cos(yaw) * 10);
  camera.lookAt(camTarget);
}

/* ============================================================
   Main loop
============================================================ */
const clock = new THREE.Clock();
let salvageTrickle = 0;

function animate() {
  requestAnimationFrame(animate);
  const dt = Math.min(clock.getDelta(), 0.05);

  if (game.state === 'playing') {
    game.elapsed += dt;

    updatePlayer(dt);
    updateWaves();
    for (const e of entities) {
      if (!e.alive) continue;
      if (e.kind === 'turret') updateTurret(e, dt);
      else if (e.kind === 'mech') updateEnemyMech(e, dt);
    }
    separateMechs();
    updateProjectiles(dt);
    updateGhost();

    // passive salvage income
    salvageTrickle += dt;
    if (salvageTrickle >= 1) {
      salvageTrickle -= 1;
      stats.salvage += 3 * difficulty().salvageMult;
      updateHud();
    }
  }

  updateParticles(dt);
  if (game.state !== 'menu') {
    updateCamera(dt);
    drawMinimap();
  } else {
    // idle menu camera orbit
    const t = performance.now() * 0.0002;
    camera.position.set(Math.sin(t) * 100, 55, Math.cos(t) * 100);
    camera.lookAt(0, 0, 0);
  }

  renderer.render(scene, camera);
}
animate();
