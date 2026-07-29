import Link from "next/link";
import type { Metadata } from "next";
import { createClient } from "@/lib/supabase/server";
import { upgradeToPremium } from "@/lib/actions/subscriptions";

export const metadata: Metadata = { title: "Premium" };

const BENEFITS = [
  ["🎛️", "Advanced filters", "Price range, distance radius, and time-window search"],
  ["📁", "Unlimited saved folders", "Organize saved events into your own collections"],
  ["⚡", "Early RSVP access", "Grab a spot before capacity-limited events open to everyone"],
  ["🚫", "Ad-free browsing", "A cleaner experience as ads roll out for free users"],
  ["👀", "See who's going", "View the full attendee list on events you've RSVP'd to"],
  ["📣", "Organizer tools", "Boosted placement, analytics, and recurring event templates"],
] as const;

export default async function PremiumPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  let isPremium = false;
  if (user) {
    const { data: profile } = await supabase.from("users").select("tier").eq("id", user.id).maybeSingle();
    isPremium = profile?.tier === "premium";
  }

  return (
    <div className="mx-auto max-w-2xl px-6 py-16">
      <h1 className="text-3xl font-semibold text-[var(--color-text-primary)]">
        {isPremium ? "You're Premium" : "Get more out of every event"}
      </h1>

      <ul className="mt-8 space-y-5">
        {BENEFITS.map(([icon, title, description]) => (
          <li key={title} className="flex gap-3">
            <span className="text-xl">{icon}</span>
            <div>
              <p className="font-medium text-[var(--color-text-primary)]">{title}</p>
              <p className="text-sm text-[var(--color-text-secondary)]">{description}</p>
            </div>
          </li>
        ))}
      </ul>

      <div className="mt-10">
        {!user && (
          <Link
            href="/auth/email-login"
            className="inline-block rounded-[var(--radius-input)] bg-[var(--color-brand)] px-5 py-2.5 font-medium text-white"
          >
            Sign in to upgrade
          </Link>
        )}
        {user && !isPremium && (
          <form action={upgradeToPremium}>
            <button
              type="submit"
              className="rounded-[var(--radius-input)] bg-[var(--color-brand)] px-5 py-2.5 font-medium text-white"
            >
              Upgrade — Rs 999/mo
            </button>
            <p className="mt-2 text-xs text-[var(--color-text-secondary)]">
              Payment is a placeholder for now — this activates a 30-day Premium period directly.
            </p>
          </form>
        )}
      </div>
    </div>
  );
}
