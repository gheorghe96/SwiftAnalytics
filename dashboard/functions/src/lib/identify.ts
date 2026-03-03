import { Firestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { IdentifyOps } from "../types";

/**
 * Apply identify operations to a user document.
 * Implements all 10 operations from SAConstants.IdentifyOp.
 */
export async function applyIdentifyOperations(
  db: Firestore,
  userRef: FirebaseFirestore.DocumentReference,
  userProperties: Record<string, unknown>
): Promise<void> {
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    const existing: Record<string, unknown> = snap.exists
      ? (snap.data()?.properties ?? {})
      : {};

    let updated = { ...existing };

    // $clearAll — supersedes everything
    if (userProperties[IdentifyOps.CLEAR_ALL]) {
      updated = {};
    }

    // $set — unconditional overwrite
    const setOps = userProperties[IdentifyOps.SET] as
      | Record<string, unknown>
      | undefined;
    if (setOps) {
      for (const [key, value] of Object.entries(setOps)) {
        updated[key] = value;
      }
    }

    // $setOnce — only write if property doesn't exist
    const setOnceOps = userProperties[IdentifyOps.SET_ONCE] as
      | Record<string, unknown>
      | undefined;
    if (setOnceOps) {
      for (const [key, value] of Object.entries(setOnceOps)) {
        if (!(key in updated)) {
          updated[key] = value;
        }
      }
    }

    // $add — increment numeric
    const addOps = userProperties[IdentifyOps.ADD] as
      | Record<string, unknown>
      | undefined;
    if (addOps) {
      for (const [key, value] of Object.entries(addOps)) {
        const current = (updated[key] as number) || 0;
        updated[key] = current + (value as number);
      }
    }

    // $append — add to end of array (duplicates allowed)
    const appendOps = userProperties[IdentifyOps.APPEND] as
      | Record<string, unknown>
      | undefined;
    if (appendOps) {
      for (const [key, value] of Object.entries(appendOps)) {
        const arr = Array.isArray(updated[key]) ? [...(updated[key] as unknown[])] : [];
        arr.push(value);
        updated[key] = arr;
      }
    }

    // $prepend — add to start of array
    const prependOps = userProperties[IdentifyOps.PREPEND] as
      | Record<string, unknown>
      | undefined;
    if (prependOps) {
      for (const [key, value] of Object.entries(prependOps)) {
        const arr = Array.isArray(updated[key]) ? [...(updated[key] as unknown[])] : [];
        arr.unshift(value);
        updated[key] = arr;
      }
    }

    // $postInsert — add to end (no duplicates)
    const postInsertOps = userProperties[IdentifyOps.POST_INSERT] as
      | Record<string, unknown>
      | undefined;
    if (postInsertOps) {
      for (const [key, value] of Object.entries(postInsertOps)) {
        const arr = Array.isArray(updated[key]) ? [...(updated[key] as unknown[])] : [];
        if (!arr.includes(value)) {
          arr.push(value);
        }
        updated[key] = arr;
      }
    }

    // $preInsert — add to start (no duplicates)
    const preInsertOps = userProperties[IdentifyOps.PRE_INSERT] as
      | Record<string, unknown>
      | undefined;
    if (preInsertOps) {
      for (const [key, value] of Object.entries(preInsertOps)) {
        const arr = Array.isArray(updated[key]) ? [...(updated[key] as unknown[])] : [];
        if (!arr.includes(value)) {
          arr.unshift(value);
        }
        updated[key] = arr;
      }
    }

    // $remove — remove from array
    const removeOps = userProperties[IdentifyOps.REMOVE] as
      | Record<string, unknown>
      | undefined;
    if (removeOps) {
      for (const [key, value] of Object.entries(removeOps)) {
        if (Array.isArray(updated[key])) {
          const arr = updated[key] as unknown[];
          const idx = arr.indexOf(value);
          if (idx !== -1) {
            arr.splice(idx, 1);
          }
          updated[key] = arr;
        }
      }
    }

    // $unset — delete property
    const unsetOps = userProperties[IdentifyOps.UNSET] as
      | Record<string, unknown>
      | undefined;
    if (unsetOps) {
      for (const key of Object.keys(unsetOps)) {
        delete updated[key];
      }
    }

    // Write back
    const now = Timestamp.now();
    if (snap.exists) {
      tx.update(userRef, {
        properties: updated,
        last_seen: now,
      });
    } else {
      tx.set(userRef, {
        properties: updated,
        first_seen: now,
        last_seen: now,
        total_events: 0,
        total_sessions: 0,
        total_revenue: 0,
        device_ids: [],
        user_id: null,
      });
    }
  });
}
