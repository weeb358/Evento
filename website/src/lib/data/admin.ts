import { createClient } from "@/lib/supabase/server";
import type { ReportRow } from "@/lib/types";
import type { HostProfileRow } from "@/lib/types";

export async function getOpenReports(): Promise<ReportRow[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("reports")
    .select()
    .in("status", ["open", "reviewing"])
    .order("created_at", { ascending: true });
  if (error) throw new Error(error.message);
  return data ?? [];
}

export async function getPendingHostVerifications(): Promise<HostProfileRow[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("host_profiles")
    .select()
    .eq("verification_status", "pending")
    .order("created_at", { ascending: true });
  if (error) throw new Error(error.message);
  return data ?? [];
}
