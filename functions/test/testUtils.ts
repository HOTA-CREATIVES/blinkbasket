import { CallableRequest } from "firebase-functions/v2/https";

export const PROJECT_ID = "demo-hypermart";

/** Wipes all Firestore documents in the emulator between tests. */
export async function clearFirestore(): Promise<void> {
  const res = await fetch(
    `http://localhost:8090/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" }
  );
  if (!res.ok) {
    throw new Error(`Failed to clear Firestore emulator: ${res.status} ${await res.text()}`);
  }
}

/** Wipes all Auth emulator accounts (Firestore wipes don't touch Auth). */
export async function clearAuth(): Promise<void> {
  const res = await fetch(`http://localhost:9099/emulator/v1/projects/${PROJECT_ID}/accounts`, {
    method: "DELETE",
  });
  if (!res.ok) {
    throw new Error(`Failed to clear Auth emulator: ${res.status} ${await res.text()}`);
  }
}

/** Builds a minimal CallableRequest for exercising an onCall function's .run(). */
export function callableRequest<T>(
  data: T,
  uid: string | null,
  tokenOverrides: Record<string, unknown> = {}
): CallableRequest<T> {
  return {
    data,
    auth: uid
      ? ({ uid, token: { uid, ...tokenOverrides } } as CallableRequest<T>["auth"])
      : undefined,
  } as CallableRequest<T>;
}
