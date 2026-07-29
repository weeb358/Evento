"use client";

import { createClient } from "@/lib/supabase/client";

/**
 * Web OAuth redirect flow — simpler than the app's native ID-token flow
 * (google_sign_in package + signInWithIdToken), since the browser can just
 * redirect to Google's consent screen and back. Needs the same Google
 * provider enabled in Supabase Auth; see docs/ARCHITECTURE.md.
 */
export function GoogleSignInButton() {
  async function handleClick() {
    const supabase = createClient();
    await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: `${window.location.origin}/` },
    });
  }

  return (
    <button
      onClick={handleClick}
      className="flex w-full items-center justify-center gap-2 rounded-[var(--radius-input)] border border-[var(--color-border)] px-4 py-2 font-medium text-[var(--color-text-primary)]"
    >
      <span className="font-extrabold">G</span>
      Continue with Google
    </button>
  );
}
