// Cloud Functions entry point: Firebase deploys the functions exported here.
// Keep one functions/ entry point so separate deploys cannot delete each other’s functions.

import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";

// Runs before any handler does: the function files only call
// getFirestore() inside their handlers, never at import time.
admin.initializeApp();

// Caps v2 instances to limit costs from retries or repeated calls.
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
