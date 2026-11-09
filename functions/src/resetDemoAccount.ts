import { Timestamp, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { habitLogId, userDocRefs } from "./docRefs";
import { DayArgs, localDayKeyOf, parseDayArgs, requireAuth } from "./requestArgs";
import { asNumber, levelFields, readLevelState, rewardPaid, syncPetStage } from "./habitTransaction";
import { bucketReward } from "./bucketRewards";
import { petCareMessage } from "./notifications";
import { EVOLUTION_LEVEL } from "./rewards";
import { evolutionBaseline, topUpCareItems, topUpCoins } from "./demoBaseline";
import { DEMO_HISTORY_DAYS, dateFromKey, planDemoHistory } from "./demoHistory";
import { SeedHabit } from "./seedPlan";

// The one account the dev-only reset button works on (Settings -> Developer).
// See ../docs/technical/BACKEND.md, "Demo account reset".
export const DEMO_ACCOUNT_EMAIL = "demo@test.com";
// Hunger is left empty on purpose so the low-vital warning has something to show.
const DEMO_PET_VITALS = { hunger: 0, hygiene: 60, happiness: 60 };

// Checked against the verified ID token's `email` claim, which a client can't
// set -- the Settings button only hides itself, this is the actual gate.
export function isDemoAccount(token: { email?: unknown } | undefined): boolean {
  return typeof token?.email === "string" && token.email.toLowerCase() === DEMO_ACCOUNT_EMAIL;
}

// Reverses all bucket-list payouts and resets completion and progress notification flags, and
// puts the level at the evolution baseline (see evolutionBaseline) so the evolution can be
// tested again even when habit XP alone got past the threshold. Then tops the demo account back
// up to its test baseline (every care item x3, 500 coins minimum; see demoBaseline.ts). Leaves
// accessories, and achievements alone; safe to re-run. When the app sends today's day, that
// day's habit logs are deleted too: a log remembers that it already paid, so without this,
// undoing and redoing a habit the same day pays nothing the second time. With the day it also
// fills in the last DEMO_HISTORY_DAYS days of habit history, turns vacation mode off, sets the
// pet's vitals to 60 (hunger 0, for the low-vital warning) and leaves a single pet-care reminder,
// so the account is ready to demo. The seeded logs record what they paid but add no XP or coins: the
// level baseline above is the account's progress.
export const resetDemoAccount = onCall<{ dayKey?: unknown; dayStartMillis?: unknown }>(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  if (!isDemoAccount(request.auth?.token)) {
    throw new HttpsError("permission-denied", "This is only available on the demo account.");
  }
  const day = request.data?.dayKey === undefined ? undefined : parseDayArgs(request.data);
  return resetDemoAccountFor(uid, day);
});

// Split from the callable so it can be run against a real account from a script.
export async function resetDemoAccountFor(uid: string, day?: DayArgs) {
  const db = getFirestore();
  const { user, pet, bucketList, inventory, habits, habitLogs } = userDocRefs(db, uid);
  const notifications = user.collection("notifications");
  const notificationStateRef = user.collection("notificationState").doc("main");

  return db.runTransaction(async (tx) => {
    const [userSnap, petSnap, inventorySnap, itemsSnap, notificationsSnap, logsSnap, habitsSnap, windowSnap] = await Promise.all([
      tx.get(user),
      tx.get(pet),
      tx.get(inventory),
      tx.get(bucketList),
      tx.get(notifications.where("kind", "in", ["levelUp", "petEvolved", "petCare"])),
      day ? tx.get(habitLogs.where("dayKey", "==", day.dayKey)) : undefined,
      day ? tx.get(habits) : undefined,
      day ? tx.get(habitLogs.where("dayKey", ">=", dayKeyBefore(day.dayKey, DEMO_HISTORY_DAYS))) : undefined,
    ]);
    const userData = userSnap.data();
    if (!userData) throw new HttpsError("not-found", "No user doc for this account.");

    let coins = 0;
    let largestGoalXp = 0;
    for (const item of itemsSnap.docs) {
      const data = item.data();
      largestGoalXp = Math.max(largestGoalXp, bucketReward(data).xp);
      if (!rewardPaid(data) && data.isCompleted !== true) continue;
      coins += asNumber(data.awardedCoins, 0);
      tx.update(item.ref, {
        isCompleted: false, completedAt: null, awardedXp: 0, awardedCoins: 0, paidAt: null,
      });
    }

    const petData = petSnap.data();
    const levelState = evolutionBaseline(EVOLUTION_LEVEL, largestGoalXp);
    const newCoins = topUpCoins(Math.max(0, asNumber(userData.coins, 0) - coins));
    tx.update(user, { ...levelFields(levelState), coins: newCoins });

    const inventoryData = inventorySnap.data();
    if (inventoryData) {
      tx.update(inventory, { careItemCounts: topUpCareItems(inventoryData.careItemCounts) });
    }

    syncPetStage(tx, pet, petData, levelState.level);
    // Older pet docs still say 7 (informational only; EVOLUTION_LEVEL is what counts).
    if (petData && petData.evolutionLevelThreshold !== EVOLUTION_LEVEL) {
      tx.update(pet, { evolutionLevelThreshold: EVOLUTION_LEVEL });
    }

    tx.set(notificationStateRef, { level: levelState.level, petEvolved: false }, { merge: true });
    for (const notification of notificationsSnap.docs) tx.delete(notification.ref);
    for (const log of logsSnap?.docs ?? []) tx.delete(log.ref);

    if (day && habitsSnap && windowSnap) {
      const seedHabits: SeedHabit[] = habitsSnap.docs.map((doc) => ({
        id: doc.id,
        data: doc.data(),
        startDate: dateOrNull(doc.get("startDate"), day),
        endDate: dateOrNull(doc.get("endDate"), day),
      }));
      const existing = new Set(windowSnap.docs.map((doc) => doc.id));
      const history = planDemoHistory(seedHabits, day, existing);
      // The app hides every day before a habit's createdAt, so move it back to its first seeded day.
      for (const habit of habitsSnap.docs) {
        const earliest = history.earliestDayByHabit.get(habit.id);
        const created = habit.get("createdAt");
        if (earliest && (!(created instanceof Timestamp) || earliest.getTime() < created.toMillis())) {
          tx.update(habit.ref, { createdAt: Timestamp.fromDate(earliest) });
        }
      }
      for (const log of history.logs) {
        tx.set(habitLogs.doc(habitLogId(log.dayKey, log.habitId)), {
          habitId: log.habitId,
          dayKey: log.dayKey,
          date: Timestamp.fromDate(log.date),
          value: log.value,
          claimed: log.claimed,
          awardedXp: log.awardedXp,
          awardedCoins: log.awardedCoins,
        });
      }

      // Vacation off, ending any open freeze now (FirestoreVacationLog: end is null while frozen).
      tx.update(user, {
        vacationModeEnabled: false,
        vacationRanges: (Array.isArray(userData.vacationRanges) ? userData.vacationRanges : []).map(
          (range: { start?: unknown; end?: unknown }) => (range?.end == null ? { ...range, end: Timestamp.now() } : range),
        ),
      });
      const now = Timestamp.now();
      tx.update(pet, { ...DEMO_PET_VITALS, lastDecayAt: now });
      // The old pile of reminders is gone (deleted above); leave exactly one, for the empty vital.
      const reminder = petCareMessage({ ...petData, ...DEMO_PET_VITALS, lastDecayAt: now }, now.toMillis());
      if (reminder) {
        tx.set(notifications.doc(), { kind: "petCare", message: reminder, isRead: false, createdAt: now });
        tx.set(notificationStateRef, { petCareAt: now }, { merge: true });
      }
    }

    return {
      xpDelta: levelState.totalXp - readLevelState(userData).totalXp,
      coinsDelta: newCoins - asNumber(userData.coins, 0),
      level: levelState.level,
    };
  });
}

// A Firestore date-only field as the Date seedPlan wants (local fields = the caller's calendar day).
function dateOrNull(value: unknown, day: DayArgs): Date | null {
  return value instanceof Timestamp ? dateFromKey(localDayKeyOf(value.toMillis(), day)) : null;
}

// The dayKey [days] before [dayKey], by calendar arithmetic (no time zone involved).
export function dayKeyBefore(dayKey: string, days: number): string {
  const [y, m, d] = dayKey.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d - days)).toISOString().slice(0, 10);
}
