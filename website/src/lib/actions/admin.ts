"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import type { ReportStatus } from "@/lib/types";

/**
 * All admin writes go through RLS policies or SECURITY DEFINER RPCs that
 * check `is_admin_or_moderator()` server-side (see
 * supabase/migrations/0004_admin_rls.sql) — this action just forwards the
 * signed-in user's own session, it holds no special privilege itself. A
 * non-admin calling these gets a Postgres permission error, not silent
 * success.
 */

export async function updateReportStatus(reportId: string, status: ReportStatus) {
  const supabase = await createClient();
  const { error } = await supabase.from("reports").update({ status }).eq("id", reportId);
  if (error) throw new Error(error.message);
  revalidatePath("/admin/reports");
}

export async function setHostVerification(hostId: string, status: "verified" | "unverified" | "pending") {
  const supabase = await createClient();
  const { error } = await supabase.rpc("set_host_verification_status", {
    target_host_id: hostId,
    new_status: status,
  });
  if (error) throw new Error(error.message);
  revalidatePath("/admin/verifications");
}

export async function setUserVerified(userId: string, verified: boolean) {
  const supabase = await createClient();
  const { error } = await supabase.rpc("set_user_verified", { target_user_id: userId, verified });
  if (error) throw new Error(error.message);
  revalidatePath("/admin/verifications");
}
