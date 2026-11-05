/**
 * Nori — Cloud Functions.
 *
 * See ../docs/BACKEND.md for the full plan this implements: the schema,
 * the Cloud-Functions-vs-direct-write rule of thumb, and the concrete
 * function list. Each function lives in its own file and is re-exported
 * below; Firebase only deploys what this file exports. Jimena's:
 * onUserCreate, purchaseCareItem/purchaseAccessory (shop.ts), and
 * complete/uncomplete/deleteBucketListItem (bucketList.ts). Valeria's:
 * claimHabit, unclaimHabit, deleteHabit (see docs/BACKEND.md "Division of
 * labor"). Everything deploys from this one entry point — a second
 * functions/ folder would make each side's `firebase deploy` delete the
 * other's.
 */

import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";

// Runs before any handler does: the function files only call
// getFirestore() inside their handlers, never at import time.
admin.initializeApp();

// Caps how many instances any one v2 function can scale to, so a retry
// loop or someone hammering a callable can't run up the bill. Far above
// what two testers need; raise it if real traffic ever gets near.
// Must run before the exports below define their functions.
setGlobalOptions({ maxInstances: 10 });

export { onUserCreate } from "./onUserCreate";
export { purchaseCareItem, purchaseAccessory } from "./shop";
export {
  completeBucketListItem,
  uncompleteBucketListItem,
  deleteBucketListItem,
} from "./bucketList";
export { claimHabit } from "./claimHabit";
export { unclaimHabit } from "./unclaimHabit";
export { deleteHabit } from "./deleteHabit";
export { deleteAccount } from "./deleteAccount";
export { resetDemoAccount } from "./resetDemoAccount";
export { petCareCheck } from "./petCareCheck";
