import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { SiteSignOutButton } from "@/components/site-sign-out-button";

export async function SiteHeader() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return (
    <header className="border-b border-[var(--color-border)] bg-[var(--color-bg-base)]">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-6">
        <Link href="/" className="flex items-center gap-2 font-semibold text-lg">
          <span aria-hidden className="inline-block h-2.5 w-2.5 rounded-full bg-[var(--color-brand)]" />
          Events Platform
        </Link>
        <nav className="flex items-center gap-6 text-sm text-[var(--color-text-secondary)]">
          <Link href="/events" className="hover:text-[var(--color-text-primary)]">
            Events
          </Link>
          <Link href="/hosting" className="hover:text-[var(--color-text-primary)]">
            Hosting
          </Link>
          <Link href="/premium" className="hover:text-[var(--color-text-primary)]">
            Premium
          </Link>
          {user ? (
            <SiteSignOutButton />
          ) : (
            <Link
              href="/auth/email-login"
              className="rounded-[var(--radius-input)] bg-[var(--color-brand)] px-3 py-1.5 font-medium text-white"
            >
              Sign in
            </Link>
          )}
        </nav>
      </div>
    </header>
  );
}
