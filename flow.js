import { renderer } from './scene.js';
import { game, stats } from './state.js';
import { audioCtx, boomSfx } from './audio.js';
import { updateHud, showMessage } from './hud.js';

/* ============================================================
   Game flow: start / end screens
============================================================ */
const overlay = document.getElementById('overlay');
const hud = document.getElementById('hud');

export function endGame(victory) {
  if (game.state === 'over') return;
  game.state = 'over';
  document.exitPointerLock();
  setTimeout(() => {
    overlay.classList.remove('hidden');
    overlay.querySelector('h1').textContent = victory ? 'VICTORY' : 'BASE LOST';
    overlay.querySelector('h1').style.color = victory ? '#7CFF6B' : '#ff5040';
    overlay.querySelector('h2').textContent = victory
      ? 'ENEMY BASE DESTROYED — DISTRICT SECURED'
      : 'YOUR BASE WAS DESTROYED';
    document.getElementById('briefing').innerHTML =
      `<b>MISSION REPORT</b><br>Kills: <b>${stats.kills}</b> · Waves survived: <b>${stats.wave}</b> · Turrets built: <b>${stats.turretsBuilt}</b><br>` +
      (victory ? 'Outstanding work, officer.' : 'The district has fallen. Redeploy and try again.');
    document.getElementById('startBtn').textContent = 'REDEPLOY';
  }, 1400);
  showMessage(victory ? 'ENEMY BASE DESTROYED' : 'YOUR BASE HAS FALLEN', victory ? '#7CFF6B' : '#ff5040');
  boomSfx(0.5, 1.2);
}

document.getElementById('startBtn').addEventListener('click', (e) => {
  if (game.state === 'over') { location.reload(); return; }
  e.currentTarget.blur();
  audioCtx();
  overlay.classList.add('hidden');
  hud.classList.add('active');
  game.state = 'playing';
  renderer.domElement.requestPointerLock();
  showMessage('DESTROY THE ENEMY BASE', '#ffd23c');
  updateHud();
});
