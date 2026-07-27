import { createClient } from "@/lib/supabase/server";
import type { UserProfile } from "@/lib/types";

export async function getUsersByIds(ids: string[]): Promise<Map<string, UserProfile>> {
  if (ids.length === 0) return new Map();
  const supabase = await createClient();
  const { data, error } = await supabase.from("users").select().in("id", ids);
  if (error) throw new Error(error.message);
  return new Map((data ?? []).map((user) => [user.id, user as UserProfile]));
}
