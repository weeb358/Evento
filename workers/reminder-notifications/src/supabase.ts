export interface PendingReminder {
  event_id: string;
  event_title: string;
  event_start_time: string;
  user_id: string;
  push_token: string;
}

/**
 * Calls the `get_pending_reminders`/`mark_reminder_sent` RPCs from
 * supabase/migrations/0007_reminder_tracking.sql using the service role
 * key, which bypasses RLS — required here since this job reads across every
 * user's RSVPs and device tokens, not just its own.
 */
export class SupabaseServiceClient {
  constructor(
    private readonly url: string,
    private readonly serviceRoleKey: string,
  ) {}

  private async rpc<T>(functionName: string, params: Record<string, unknown> = {}): Promise<T> {
    const response = await fetch(`${this.url}/rest/v1/rpc/${functionName}`, {
      method: "POST",
      headers: {
        apikey: this.serviceRoleKey,
        Authorization: `Bearer ${this.serviceRoleKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(params),
    });

    if (!response.ok) {
      throw new Error(`Supabase RPC ${functionName} failed: ${response.status} ${await response.text()}`);
    }
    return response.json() as Promise<T>;
  }

  getPendingReminders(): Promise<PendingReminder[]> {
    return this.rpc<PendingReminder[]>("get_pending_reminders");
  }

  markReminderSent(eventId: string): Promise<void> {
    return this.rpc<void>("mark_reminder_sent", { target_event_id: eventId });
  }
}
