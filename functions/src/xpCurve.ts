/**
 * Nori — shared level-curve helper for any Cloud Function that mints or
 * burns XP. See ../docs/BACKEND.md, "XP curve": `xpForNextLevel = 100 *
 * currentLevel`, decided 2026-09-16. This is the ONLY place this formula
 * is implemented -- the client only ever displays the stored values (see
 * that section's closing note, "Don't reimplement it in Dart").
 *
 * Handles multi-level jumps in both directions: a capped 500 XP bucket-
 * list award can cross several levels for a new user (../docs/BACKEND.md,
 * "Level-up must handle multi-level jumps"), and reversing a completion
 * can just as easily cross back down. Mirrors the *intent* of
 * MockUserRepository.addXp's while-loops (lib/data/user_repository.dart)
 * but fixes the bug that made porting it verbatim wrong: the mock re-uses
 * one stale `xpForNextLevel` across every loop iteration instead of
 * recomputing it per level, which only happens to work for a single-level
 * change. This recomputes `xpForLevel(level)` every iteration.
 */

export interface LevelState {
  level: number;
  totalXp: number;
  xpIntoLevel: number;
}

export function xpForLevel(level: number): number {
  return 100 * level;
}

/**
 * Applies `xpDelta` (positive to award, negative to reverse) to `state`,
 * looping level-ups/level-downs until `xpIntoLevel` is back in
 * `[0, xpForLevel(level))`. Never drops `totalXp` below 0 or `level`
 * below 1.
 */
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
