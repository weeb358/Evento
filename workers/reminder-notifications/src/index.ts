import { sendReminders, type FirebaseServiceAccount } from "./fcm";
import { SupabaseServiceClient } from "./supabase";

export interface Env {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  /** Full JSON contents of a Firebase service-account key, as one string. */
  FIREBASE_SERVICE_ACCOUNT: string;
}

function formatStartTime(iso: string): string {
  return new Date(iso).toLocaleString("en-US", {
    hour: "numeric",
    minute: "2-digit",
    timeZone: "Asia/Karachi",
  });
}

async function runReminderSweep(env: Env): Promise<void> {
  const supabase = new SupabaseServiceClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY);
  const firebaseAccount: FirebaseServiceAccount = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT);

  const pending = await supabase.getPendingReminders();
  if (pending.length === 0) {
    console.log("No pending reminders.");
    return;
  }

  const pushes = pending.map((reminder) => ({
    token: reminder.push_token,
    title: reminder.event_title,
    body: `Starting at ${formatStartTime(reminder.event_start_time)} today`,
  }));

  const results = await sendReminders(firebaseAccount, pushes);
  const failed = results.filter((r) => !r.ok);
  if (failed.length > 0) {
    console.error(`${failed.length}/${results.length} reminder pushes failed`, failed);
  }

  // Mark each event as reminded once all its pushes have been attempted —
  // a per-token delivery failure (e.g. one stale device) shouldn't cause a
  // resend storm to the rest of that event's attendees on the next sweep.
  const uniqueEventIds = [...new Set(pending.map((r) => r.event_id))];
  await Promise.all(uniqueEventIds.map((eventId) => supabase.markReminderSent(eventId)));

  console.log(`Sent ${results.length - failed.length}/${results.length} reminders for ${uniqueEventIds.length} event(s).`);
}

export default {
  async scheduled(_controller: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    ctx.waitUntil(runReminderSweep(env));
  },

  // Lets `curl` hit the Worker directly for a manual test in addition to
  // `wrangler dev --test-scheduled`'s /__scheduled endpoint.
  async fetch(_request: Request, env: Env): Promise<Response> {
    await runReminderSweep(env);
    return new Response("Reminder sweep complete.");
  },
};
