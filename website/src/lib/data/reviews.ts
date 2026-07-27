import { createClient } from "@/lib/supabase/server";
import type { ReviewRow, ReviewSubjectType } from "@/lib/types";

export async function getReviewsFor(subjectType: ReviewSubjectType, subjectId: string): Promise<ReviewRow[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("reviews")
    .select()
    .eq("subject_type", subjectType)
    .eq("subject_id", subjectId)
    .order("created_at", { ascending: false });
  if (error) throw new Error(error.message);
  return data ?? [];
}

export function averageRating(reviews: ReviewRow[]): number {
  if (reviews.length === 0) return 0;
  return reviews.reduce((sum, r) => sum + r.rating, 0) / reviews.length;
}
