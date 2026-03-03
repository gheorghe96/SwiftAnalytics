import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { randomBytes } from "crypto";

/**
 * Creates a new app for the authenticated user.
 * Generates a unique API token, creates a project doc, and updates the user's app list.
 */
export const createApp = onCall(
  { memory: "256MiB", maxInstances: 10 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in");
    }

    const uid = request.auth.uid;
    const email = request.auth.token.email || "";
    const { name } = request.data as { name?: string };

    if (!name || typeof name !== "string" || name.trim().length < 1 || name.trim().length > 100) {
      throw new HttpsError("invalid-argument", "App name required (1-100 chars)");
    }

    const appName = name.trim();
    const token = `sa_${randomBytes(16).toString("hex")}`;
    const db = getFirestore();
    const now = Timestamp.now();

    // Create the project doc
    await db.collection("projects").doc(token).set({
      name: appName,
      owner_uid: uid,
      created_at: now,
      settings: {
        retention_days: 90,
        rate_limit_per_minute: 1000,
      },
    });

    // Add to user's app list (create user doc if doesn't exist)
    await db.collection("users").doc(uid).set(
      {
        email,
        updated_at: now,
        apps: FieldValue.arrayUnion({
          api_key: token,
          name: appName,
          created_at: now,
        }),
      },
      { merge: true }
    );

    return { api_key: token, name: appName };
  }
);

/**
 * Claims an existing unowned project for the authenticated user.
 * Used to migrate legacy projects that existed before auth was added.
 */
export const claimProject = onCall(
  { memory: "256MiB", maxInstances: 10 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in");
    }

    const uid = request.auth.uid;
    const email = request.auth.token.email || "";
    const { api_key } = request.data as { api_key?: string };

    if (!api_key || typeof api_key !== "string") {
      throw new HttpsError("invalid-argument", "API key required");
    }

    const db = getFirestore();
    const projectSnap = await db.collection("projects").doc(api_key).get();

    if (!projectSnap.exists) {
      throw new HttpsError("not-found", "Project not found");
    }

    const data = projectSnap.data();
    if (data?.owner_uid) {
      // Already owned — silently skip
      return { claimed: false, reason: "already_owned" };
    }

    const now = Timestamp.now();
    const appName = data?.name || api_key;

    // Set ownership
    await db.collection("projects").doc(api_key).update({ owner_uid: uid });

    // Add to user's app list
    await db.collection("users").doc(uid).set(
      {
        email,
        updated_at: now,
        apps: FieldValue.arrayUnion({
          api_key,
          name: appName,
          created_at: now,
        }),
      },
      { merge: true }
    );

    return { claimed: true, api_key, name: appName };
  }
);

/**
 * Deletes an app owned by the authenticated user.
 * Removes the project doc and updates the user's app list.
 */
export const deleteApp = onCall(
  { memory: "256MiB", maxInstances: 10 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in");
    }

    const uid = request.auth.uid;
    const { api_key } = request.data as { api_key?: string };

    if (!api_key || typeof api_key !== "string") {
      throw new HttpsError("invalid-argument", "API key required");
    }

    const db = getFirestore();

    // Verify ownership
    const projectSnap = await db.collection("projects").doc(api_key).get();
    if (!projectSnap.exists) {
      throw new HttpsError("not-found", "App not found");
    }
    if (projectSnap.data()?.owner_uid !== uid) {
      throw new HttpsError("permission-denied", "You do not own this app");
    }

    // Delete project doc
    await db.collection("projects").doc(api_key).delete();

    // Remove from user's app list
    const userSnap = await db.collection("users").doc(uid).get();
    if (userSnap.exists) {
      const apps: Array<Record<string, unknown>> = userSnap.data()?.apps || [];
      const updatedApps = apps.filter((a) => a.api_key !== api_key);
      await db.collection("users").doc(uid).update({ apps: updatedApps });
    }

    return { success: true };
  }
);
