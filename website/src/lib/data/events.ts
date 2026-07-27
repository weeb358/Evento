import { createClient } from "@/lib/supabase/server";
import type { EventRow } from "@/lib/types";

export interface EventFilters {
  city?: string;
  category?: string;
  search?: string;
}

export async function getPublishedEvents(filters: EventFilters = {}): Promise<EventRow[]> {
  const supabase = await createClient();
  let query = supabase.from("events").select().eq("status", "published");

  if (filters.city) query = query.eq("city", filters.city);
  if (filters.category) query = query.eq("category", filters.category);
  if (filters.search) query = query.textSearch("search_vector", filters.search);

  const { data, error } = await query
    .order("is_featured", { ascending: false })
    .order("start_time", { ascending: true })
    .limit(60);

  if (error) throw new Error(error.message);
  return data ?? [];
}

export async function getEventById(id: string): Promise<EventRow | null> {
  const supabase = await createClient();
  const { data, error } = await supabase.from("events").select().eq("id", id).maybeSingle();
  if (error) throw new Error(error.message);
  return data;
}

export async function getEventRsvpCounts(eventId: string): Promise<{ going: number; interested: number }> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("get_event_rsvp_counts", { p_event_id: eventId });
  if (error || !data || data.length === 0) return { going: 0, interested: 0 };
  const row = data[0] as { going_count: number; interested_count: number };
  return { going: row.going_count, interested: row.interested_count };
}

export async function getOrganizer(organizerId: string) {
  const supabase = await createClient();
  const { data } = await supabase.from("users").select().eq("id", organizerId).maybeSingle();
  return data;
}
