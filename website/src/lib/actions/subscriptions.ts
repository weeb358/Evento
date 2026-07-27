"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

/**
 * Payment is stubbed — mirrors the Flutter app's
 * SubscriptionRepository.activateStubbed. See docs/ARCHITECTURE.md.
 */
export async function upgradeToPremium() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Sign in first");

  const currentPeriodEnd = new Date();
  currentPeriodEnd.setDate(currentPeriodEnd.getDate() + 30);

  const { error } = await supabase.from("subscriptions").insert({
    user_id: user.id,
    status: "active",
    current_period_end: currentPeriodEnd.toISOString(),
    payment_reference: `stub-web-${Date.now()}`,
  });
  if (error) throw new Error(error.message);

  revalidatePath("/premium");
}
