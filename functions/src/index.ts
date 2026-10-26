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

// Runs before any handler does: the function files only call
// getFirestore() inside their handlers, never at import time.
admin.initializeApp();

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
export { petCareCheck } from "./petCareCheck";
