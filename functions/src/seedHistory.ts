// Demo-history seed script: fills an account's past days with believable
// habitLogs, replacing HabitHistoryStore.seedHistory's in-memory mock data
// (docs/BACKEND.md, "Seed script"). Uses the Admin SDK because firestore.rules
// stop any client from writing claimed/awardedXp/awardedCoins.
//
// Not deployed as a function — run it locally (see "Seed script" in
// docs/BACKEND.md for credentials):
//   npm run build && node lib/seedHistory.js --uid <uid> [--days 30] [--off-days 0.12] [--apply]
// Without --apply it only prints the plan. Day keys use this machine's time
// zone, the same way the app uses the device's; override with TZ=… if needed.
//
// Seeds the account's existing habits only (create them in the app first),
// skips today, vacation days, archived days and any day that already has a
// log, leaves ~12% of days fully empty (--off-days) so the streak breaks
// like a real user's would, and pays XP/coins/level/pet stage/the sunglasses gift exactly like
// claimHabit would, in the same transactions as the logs.

import { initializeApp } from "firebase-admin/app";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { applyXpDelta } from "./xpCurve";
import { asNumber, levelFields, readLevelState, syncPetStage } from "./habitTransaction";
import {
  DEFAULT_OFF_DAY_RATE, SeedHabit, SeedLog, localMidnight, pastDays, planSeed,
} from "./seedPlan";

const PROJECT_ID = "nori-pet";
const FIRST_COMPLETION_GIFT = "sunglasses";
// Firestore allows 500 writes per transaction; leave room for user/pet/inventory.
const LOGS_PER_TRANSACTION = 400;

interface Args {
  uid: string;
  days: number;
  offDayRate: number;
  apply: boolean;
}

function parseArgs(argv: string[]): Args {
  const value = (flag: string) => {
    const i = argv.indexOf(flag);
    return i >= 0 ? argv[i + 1] : undefined;
  };
  const uid = value("--uid");
  if (!uid || uid.includes("/")) {
    throw new Error("Usage: node lib/seedHistory.js --uid <uid> [--days 30] [--off-days 0.12] [--apply]");
  }
  const days = Number(value("--days") ?? 30);
  if (!Number.isInteger(days) || days < 1 || days > 365) {
    throw new Error("--days must be an integer between 1 and 365.");
  }
  const offDayRate = Number(value("--off-days") ?? DEFAULT_OFF_DAY_RATE);
  if (!(offDayRate >= 0 && offDayRate < 1)) {
    throw new Error("--off-days must be a fraction between 0 and 1, like 0.12.");
  }
  return { uid, days, offDayRate, apply: argv.includes("--apply") };
}

function toDate(value: unknown): Date | null {
  return value instanceof Timestamp ? value.toDate() : null;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  initializeApp({ projectId: PROJECT_ID });
  const db = getFirestore();
  const userRef = db.collection("users").doc(args.uid);

  const [userSnap, habitsSnap] = await Promise.all([
    userRef.get(),
    userRef.collection("habits").get(),
  ]);
  const userData = userSnap.data();
  if (!userData) throw new Error(`No user doc for ${args.uid} — is the account provisioned?`);
  if (habitsSnap.empty) throw new Error("This account has no habits. Create some in the app first.");

  const habits: SeedHabit[] = habitsSnap.docs.map((doc) => ({
    id: doc.id,
    data: doc.data(),
    startDate: toDate(doc.get("startDate")),
    endDate: toDate(doc.get("endDate")),
  }));

  const days = pastDays(new Date(), args.days);
  const existingSnap = await userRef
    .collection("habitLogs")
    .where("date", ">=", Timestamp.fromDate(days[0]))
    .get();
  const existingLogKeys = new Set(existingSnap.docs.map((doc) => doc.id));

  // vacationRanges: [{start, end}] Timestamps, end null while still frozen
  // (FirestoreVacationLog). Treated as inclusive on both ends to stay clear.
  const vacations = (Array.isArray(userData.vacationRanges) ? userData.vacationRanges : [])
    .map((range: { start?: unknown; end?: unknown }) => ({
      start: toDate(range?.start),
      end: toDate(range?.end),
    }))
    .filter((range: { start: Date | null }) => range.start !== null);
  const isVacationDay = (day: Date) =>
    vacations.some((range: { start: Date | null; end: Date | null }) =>
      day >= localMidnight(range.start!) && (range.end === null || day <= localMidnight(range.end)));

  const plan = planSeed(habits, days, existingLogKeys, isVacationDay, args.offDayRate);
  const claimedCount = plan.logs.filter((log) => log.claimed).length;
  const projected = applyXpDelta(readLevelState(userData), plan.totalXp);

  console.log(`Account ${args.uid}: ${habits.length} habits, ${args.days} days back.`);
  console.log(`Plan: ${plan.logs.length} logs (${claimedCount} claimed), ` +
    `+${plan.totalXp} XP, +${plan.totalCoins} coins.`);
  console.log(`Level ${readLevelState(userData).level} → ${projected.level}; ` +
    `${plan.earliestDayByHabit.size} habits get createdAt moved back.`);
  if (!args.apply) {
    console.log("Dry run — nothing written. Re-run with --apply to write it.");
    return;
  }
  if (plan.logs.length === 0) return;

  // Backdate createdAt first: without it the app hides every seeded day.
  const backdate = db.batch();
  for (const habit of habits) {
    const earliest = plan.earliestDayByHabit.get(habit.id);
    const created = toDate(habit.data.createdAt);
    if (earliest && (!created || earliest < created)) {
      backdate.update(userRef.collection("habits").doc(habit.id), {
        createdAt: Timestamp.fromDate(earliest),
      });
    }
  }
  await backdate.commit();

  // Logs and the rewards they paid land together, chunk by chunk, so a
  // failure part-way never leaves a claimed log that wasn't paid (or the
  // reverse). Re-running skips whatever already landed.
  for (let i = 0; i < plan.logs.length; i += LOGS_PER_TRANSACTION) {
    await writeChunk(args.uid, plan.logs.slice(i, i + LOGS_PER_TRANSACTION));
  }
  const after = (await userRef.get()).data() ?? {};
  console.log(`Done. Now level ${after.level}, ${after.totalXp} XP, ${after.coins} coins.`);
}

async function writeChunk(uid: string, logs: SeedLog[]) {
  const db = getFirestore();
  const userRef = db.collection("users").doc(uid);
  const petRef = userRef.collection("pet").doc("main");
  const inventoryRef = userRef.collection("inventory").doc("main");

  await db.runTransaction(async (tx) => {
    const [userSnap, petSnap, inventorySnap] = await Promise.all([
      tx.get(userRef),
      tx.get(petRef),
      tx.get(inventoryRef),
    ]);
    const userData = userSnap.data();
    if (!userData) throw new Error("User doc disappeared mid-seed.");

    let xp = 0;
    let coins = 0;
    let anyPaid = false;
    for (const log of logs) {
      tx.set(userRef.collection("habitLogs").doc(`${log.dayKey}_${log.habitId}`), {
        habitId: log.habitId,
        dayKey: log.dayKey,
        date: Timestamp.fromDate(log.date),
        value: log.value,
        claimed: log.claimed,
        awardedXp: log.awardedXp,
        awardedCoins: log.awardedCoins,
      });
      xp += log.awardedXp;
      coins += log.awardedCoins;
      if (log.claimed && log.awardedXp > 0) anyPaid = true;
    }

    const levelState = applyXpDelta(readLevelState(userData), xp);
    const userUpdate: Record<string, unknown> = {
      ...levelFields(levelState),
      coins: asNumber(userData.coins, 0) + coins,
    };
    // Same one-time gift claimHabit gives on a first paid completion.
    const inventoryData = inventorySnap.data();
    if (userData.firstHabitCompletedAt == null && anyPaid && inventoryData) {
      userUpdate.firstHabitCompletedAt = FieldValue.serverTimestamp();
      const inventoryUpdate: Record<string, unknown> = {
        ownedAccessoryIds: FieldValue.arrayUnion(FIRST_COMPLETION_GIFT),
      };
      if (inventoryData.equippedAccessoryId == null) {
        inventoryUpdate.equippedAccessoryId = FIRST_COMPLETION_GIFT;
      }
      tx.update(inventoryRef, inventoryUpdate);
    }
    tx.update(userRef, userUpdate);
    syncPetStage(tx, petRef, petSnap.data(), levelState.level);
  });
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exit(1);
  });
}
