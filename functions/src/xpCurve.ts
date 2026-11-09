// Shared XP curve for awarding and reversing XP, including multi-level changes.
// Recomputes the threshold per level; the client displays stored values only.

export interface LevelState {
  level: number;
  totalXp: number;
  xpIntoLevel: number;
}

export function xpForLevel(level: number): number {
  return 100 * level;
}

// Applies XP changes until xpIntoLevel is within [0, xpForLevel(level)).
// Clamps totalXp to at least 0 and level to at least 1.
export function applyXpDelta(state: LevelState, xpDelta: number): LevelState {
  let level = state.level;
  let xpIntoLevel = state.xpIntoLevel + xpDelta;
  const totalXp = Math.max(0, state.totalXp + xpDelta);

  let xpForNextLevel = xpForLevel(level);
  while (xpIntoLevel >= xpForNextLevel) {
    xpIntoLevel -= xpForNextLevel;
    level += 1;
    xpForNextLevel = xpForLevel(level);
  }
  while (xpIntoLevel < 0 && level > 1) {
    level -= 1;
    xpForNextLevel = xpForLevel(level);
    xpIntoLevel += xpForNextLevel;
  }
  if (xpIntoLevel < 0) xpIntoLevel = 0;

  return { level, totalXp, xpIntoLevel };
}
