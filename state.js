/* ============================================================
   Shared mutable game state
============================================================ */
export const game = {
  state: 'menu',          // menu | playing | over
  elapsed: 0,
  buildMode: false,
  mouseDown: false,
  pointerLocked: false,
};

export const stats = {
  salvage: 150, ammo: 6552, rockets: 30,
  turretsBuilt: 0, kills: 0, wave: 0,
};
