import { createClient } from "@/lib/supabase/server";
import type { HostPhotoRow, HostProfileRow } from "@/lib/types";

export async function getActiveHosts(city?: string): Promise<HostProfileRow[]> {
  const supabase = await createClient();
  let query = supabase.from("host_profiles").select().eq("is_active", true);
  if (city) query = query.eq("city", city);

  const { data, error } = await query.order("created_at", { ascending: false }).limit(60);
  if (error) throw new Error(error.message);
  return data ?? [];
}

export async function getHostById(id: string): Promise<HostProfileRow | null> {
  const supabase = await createClient();
  const { data, error } = await supabase.from("host_profiles").select().eq("id", id).maybeSingle();
  if (error) throw new Error(error.message);
  return data;
}

export async function getHostPhotos(hostId: string): Promise<HostPhotoRow[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("host_photos")
    .select()
    .eq("host_id", hostId)
    .order("sort_order");
  if (error) throw new Error(error.message);
  return data ?? [];
}

export async function getHostUser(hostId: string) {
  const supabase = await createClient();
  const { data } = await supabase.from("users").select().eq("id", hostId).maybeSingle();
  return data;
}
