import { MP, connect, disconnect, connected, on, send } from '../net/net.js';
import { game } from '../core/state.js';
import { levelName } from '../world/world.js';
import { startGame, backToLobby } from '../core/flow.js';
import { audioCtx } from '../systems/audio.js';

/* ============================================================
   Multiplayer UI — team lobby, up to 5 v 5

   Lobby (from the mode select): pick a callsign → join → pick a
   team (blue or red, max 5 per side) → once both teams have at
   least one pilot, anyone on a team can START MATCH. The server
   deals out match credentials and every rostered player reloads
   into ?level=<starter's level>&mp=1 (see net.js).

   Match boot (?mp=1): reconnect, rejoin by token, then a READY
   handshake so the fight starts for everyone at once.
============================================================ */
const modeScreen = document.getElementById('modeScreen');
const mpScreen = document.getElementById('mpScreen');
const matchScreen = document.getElementById('matchScreen');
const statusEl = document.getElementById('mpStatus');
const nameRow = document.getElementById('mpNameRow');
const nameInput = document.getElementById('mpNameInput');
const joinBtn = document.getElementById('mpJoinBtn');
const bannerEl = document.getElementById('mpBanner');
const teamsEl = document.getElementById('mpTeams');
const listEl = document.getElementById('mpList');
const startBtn = document.getElementById('mpStartBtn');
const matchInfo = document.getElementById('matchInfo');
const readyBtn = document.getElementById('readyBtn');

const TEAM_MAX = 5; // mirrors the server's cap; the server enforces it
const show = (el, on) => el.classList.toggle('mpHidden', !on);
// numeric levels travel as their short ?level=N form
const levelParam = (n) => n.match(/^level(\d+)$/)?.[1] ?? n;

function setStatus(text, color) {
  statusEl.textContent = text;
  statusEl.style.color = color || '';
}

/* ============================================================
   Match boot — this page load IS a match
============================================================ */
if (MP.active) {
  // the inline script in index.html already swapped the overlay to matchScreen
  document.body.classList.add(`team-${MP.myTeam}`); // recolors the base bars for the red side
  matchInfo.textContent = 'CONNECTING TO SERVER…';
  connect();

  const gone = new Set(); // players who left before the match began
  let matchDead = false;  // failed pre-start: ignore a late "go"
  let matchMsg = '';

  /* both rosters + a status line under them */
  function renderMatchInfo(sub) {
    if (sub !== null) matchMsg = sub;
    matchInfo.textContent = '';
    for (const team of ['blue', 'red']) {
      const row = document.createElement('div');
      row.className = `mrTeam ${team}`;
      const lbl = document.createElement('b');
      lbl.textContent = `${team.toUpperCase()} TEAM`;
      row.appendChild(lbl);
      for (const p of MP.roster.filter((r) => r.team === team)) {
        const s = document.createElement('span');
        s.className = 'mrName'
          + (gone.has(p.id) ? ' gone' : '')
          + (p.id === MP.playerId ? ' me' : '');
        s.textContent = p.id === MP.playerId ? `${p.name} (YOU)` : p.name;
        row.appendChild(s);
      }
      matchInfo.appendChild(row);
    }
    const sub2 = document.createElement('div');
    sub2.className = 'sub';
    sub2.textContent = matchMsg
      || `YOU FIGHT FOR THE ${MP.myTeam.toUpperCase()} TEAM — DESTROY THEIR BASE`;
    matchInfo.appendChild(sub2);
  }

  function matchFail(text) {
    matchDead = true;
    matchInfo.textContent = text;
    readyBtn.textContent = '◂ BACK TO LOBBY';
    readyBtn.onclick = backToLobby;
    show(readyBtn, true);
  }

  on('open', () => send({ type: 'rejoin', matchId: MP.matchId, token: MP.token }));
  on('rejoined', () => {
    if (matchDead) return;
    renderMatchInfo('');
    readyBtn.onclick = () => {
      audioCtx(); // unlock audio on the user gesture
      send({ type: 'ready' });
      show(readyBtn, false);
      renderMatchInfo('WAITING FOR THE OTHER PILOTS TO DEPLOY…');
    };
    show(readyBtn, true);
  });
  on('ready', (m) => {
    if (game.state !== 'menu' || matchDead) return;
    renderMatchInfo(`${m.count}/${m.total} PILOTS READY…`);
  });
  on('go', () => {
    if (game.state !== 'menu' || matchDead) return; // server re-sends after a mid-match rejoin
    matchScreen.classList.add('hidden');
    startGame();
  });
  on('error', (m) => matchFail(m.message));
  on('peerLeft', (m) => {
    if (game.state !== 'menu' || matchDead) return;
    gone.add(m.id);
    const enemies = MP.roster.filter((p) => p.team !== MP.myTeam);
    if (enemies.every((p) => gone.has(p.id))) matchFail('THE OTHER TEAM LEFT THE MATCH');
    else renderMatchInfo(null); // refresh the roster, keep the message
  });
  on('peerJoined', (m) => {
    if (game.state !== 'menu' || matchDead) return;
    gone.delete(m.id);
    renderMatchInfo(null);
  });
  on('close', () => {
    if (game.state === 'menu') matchFail('CONNECTION LOST — IS THE SERVER RUNNING?');
  });
}

/* ============================================================
   Lobby — reached from the mode select's MULTIPLAYER button
============================================================ */
let myId = null;
let myName = '';
let myTeam = null;
let joined = false;
let autoJoin = false;    // returning from a match: rejoin with the saved name
let manualClose = false; // BACK pressed: the socket close is expected
let lastPlayers = [];

nameInput.value = localStorage.getItem('mechMpName') || '';

function showMpScreen(open) {
  mpScreen.classList.toggle('hidden', !open);
  modeScreen.classList.toggle('hidden', open);
  if (open) {
    manualClose = false;
    setStatus('CONNECTING TO SERVER…');
    connect();
    if (connected()) onOpen();
  } else {
    manualClose = connected();
    disconnect();
    resetLobbyUi();
  }
}

function resetLobbyUi() {
  joined = false;
  myId = null;
  myTeam = null;
  show(nameRow, false);
  show(teamsEl, false);
  show(listEl, false);
  show(startBtn, false);
  clearBanner();
}

function doJoin() {
  const name = nameInput.value.trim();
  if (!name) { nameInput.focus(); return; }
  send({ type: 'join', name, level: levelParam(levelName) });
}

function clearBanner() {
  bannerEl.textContent = '';
  show(bannerEl, false);
}

let infoTimer = null;
function infoBanner(text) {
  bannerEl.textContent = text;
  show(bannerEl, true);
  clearTimeout(infoTimer);
  infoTimer = setTimeout(clearBanner, 3000);
}

function renderList(players) {
  lastPlayers = players;
  if (!joined) return;
  const me = players.find((p) => p.id === myId);
  myTeam = me ? me.team : null;

  for (const team of ['blue', 'red']) {
    const col = document.getElementById(team === 'blue' ? 'mpTeamBlue' : 'mpTeamRed');
    const list = col.querySelector('.tList');
    const btn = col.querySelector('button');
    const members = players.filter((p) => p.team === team);
    col.querySelector('.tHead').textContent = `${team.toUpperCase()} TEAM ${members.length}/${TEAM_MAX}`;
    list.textContent = '';
    for (const p of members) {
      const row = document.createElement('div');
      row.className = 'tSlot' + (p.id === myId ? ' me' : '');
      row.textContent = p.id === myId ? `${p.name} (YOU)` : p.name;
      list.appendChild(row);
    }
    for (let i = members.length; i < TEAM_MAX; i++) {
      const row = document.createElement('div');
      row.className = 'tSlot empty';
      row.textContent = 'OPEN SLOT';
      list.appendChild(row);
    }
    if (myTeam === team) {
      btn.textContent = 'LEAVE TEAM';
      btn.disabled = false;
    } else {
      btn.textContent = `JOIN ${team.toUpperCase()}`;
      btn.disabled = members.length >= TEAM_MAX;
    }
  }

  // pilots in the lobby who haven't picked a side yet
  const unassigned = players.filter((p) => !p.team);
  listEl.textContent = '';
  if (unassigned.length) {
    const row = document.createElement('div');
    row.className = 'mpRow';
    const n = document.createElement('span');
    n.className = 'name';
    n.textContent = 'IN LOBBY';
    const st = document.createElement('span');
    st.className = 'st';
    st.textContent = unassigned.map((p) => p.name).join(' · ');
    row.append(n, st);
    listEl.appendChild(row);
  }
  show(listEl, !!unassigned.length);

  const blue = players.filter((p) => p.team === 'blue').length;
  const red = players.filter((p) => p.team === 'red').length;
  startBtn.disabled = !myTeam || !blue || !red;
  if (!myTeam) setStatus('PICK A TEAM — BLUE OR RED');
  else if (!blue || !red) setStatus('WAITING FOR PILOTS ON THE OTHER TEAM…');
  else setStatus(`READY — STARTING PLAYS YOUR LEVEL (${levelName.toUpperCase()}) FOR EVERYONE`);
}

function onOpen() {
  if (MP.active) return;
  setStatus('CONNECTED — ENTER A CALLSIGN TO JOIN THE LOBBY');
  show(nameRow, true);
  if (autoJoin && nameInput.value.trim()) {
    autoJoin = false;
    doJoin();
  }
}

if (!MP.active) {
  // ?mp=1 without match credentials (bookmark, reopened tab): back to mode select
  if (new URLSearchParams(location.search).get('mp') === '1') {
    const url = new URL(location.href);
    url.searchParams.delete('mp');
    history.replaceState(null, '', url);
    matchScreen.classList.add('hidden');
    modeScreen.classList.remove('hidden');
  }

  document.getElementById('mpBtn').addEventListener('click', () => showMpScreen(true));
  document.getElementById('mpBack').addEventListener('click', () => showMpScreen(false));
  joinBtn.addEventListener('click', doJoin);
  nameInput.addEventListener('keydown', (e) => {
    e.stopPropagation(); // keep game key handling out of the text field
    if (e.key === 'Enter') doJoin();
  });
  for (const btn of teamsEl.querySelectorAll('button')) {
    btn.addEventListener('click', () => {
      // clicking my own team's button steps back off the roster
      send({ type: 'team', team: btn.dataset.team === myTeam ? null : btn.dataset.team });
    });
  }
  startBtn.addEventListener('click', () => send({ type: 'startMatch' }));

  on('open', onOpen);
  on('close', () => {
    if (manualClose) { manualClose = false; return; }
    resetLobbyUi();
    setStatus('CANNOT REACH THE SERVER — CHECK YOUR CONNECTION AND REOPEN THIS SCREEN', '#ff8a7a');
  });
  on('error', (m) => { if (joined) infoBanner(m.message); else setStatus(m.message, '#ff8a7a'); });

  on('joined', (m) => {
    myId = m.id;
    myName = m.name;
    joined = true;
    localStorage.setItem('mechMpName', m.name);
    setStatus('PICK A TEAM — BLUE OR RED');
    show(nameRow, false);
    show(teamsEl, true);
    show(startBtn, true);
    renderList(lastPlayers);
  });
  on('lobby', (m) => renderList(m.players));

  on('matchStart', (m) => {
    sessionStorage.setItem('mechMpMatch', JSON.stringify({
      matchId: m.matchId, token: m.token, playerId: m.playerId,
      team: m.team, name: myName, roster: m.roster,
    }));
    const url = new URL(location.href);
    url.searchParams.set('level', m.level);
    url.searchParams.set('mp', '1');
    location.href = url.href;
  });

  // coming back from a match: straight into the lobby with the same name
  if (sessionStorage.getItem('mechMpReturn')) {
    sessionStorage.removeItem('mechMpReturn');
    autoJoin = true;
    showMpScreen(true);
  }
}
