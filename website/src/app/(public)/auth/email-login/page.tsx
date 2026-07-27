"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function EmailLoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showSignUpPrompt, setShowSignUpPrompt] = useState(false);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    const supabase = createClient();
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    setLoading(false);

    if (error) {
      // Supabase returns the same error for "no account" and "wrong
      // password" (so this form can't be used to enumerate emails) — we
      // can't distinguish the two, so the prompt covers both.
      setShowSignUpPrompt(true);
      return;
    }
    router.push("/");
    router.refresh();
  }

  return (
    <div className="mx-auto flex max-w-sm flex-col px-6 py-24">
      <h1 className="text-2xl font-semibold text-[var(--color-text-primary)]">Sign in with email</h1>
      <form onSubmit={handleSubmit} className="mt-8 flex flex-col gap-4">
        <input
          type="email"
          required
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="rounded-[var(--radius-input)] border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-3 py-2 outline-none"
        />
        <input
          type="password"
          required
          placeholder="Password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="rounded-[var(--radius-input)] border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-3 py-2 outline-none"
        />
        <Link href="/auth/forgot-password" className="self-end text-sm text-[var(--color-brand)]">
          Forgot password?
        </Link>
        <button
          type="submit"
          disabled={loading}
          className="rounded-[var(--radius-input)] bg-[var(--color-brand)] px-4 py-2 font-medium text-white disabled:opacity-60"
        >
          {loading ? "Signing in..." : "Sign in"}
        </button>
      </form>
      <div className="mt-6 flex flex-col gap-2 text-center text-sm">
        <Link href="/auth/email-signup" className="text-[var(--color-brand)]">
          Don&apos;t have an account? Sign up
        </Link>
        <Link href="/auth/phone" className="text-[var(--color-text-secondary)]">
          Use phone number instead
        </Link>
      </div>

      {showSignUpPrompt && (
        <div
          role="dialog"
          className="fixed inset-0 flex items-center justify-center bg-black/40 px-6"
          onClick={() => setShowSignUpPrompt(false)}
        >
          <div
            className="w-full max-w-sm rounded-[var(--radius-card)] bg-[var(--color-bg-surface-raised)] p-6"
            onClick={(e) => e.stopPropagation()}
          >
            <h2 className="font-semibold text-[var(--color-text-primary)]">Couldn&apos;t sign you in</h2>
            <p className="mt-2 text-sm text-[var(--color-text-secondary)]">
              That email/password combination isn&apos;t recognized. If you don&apos;t have an account
              yet, sign up first.
            </p>
            <div className="mt-4 flex justify-end gap-2">
              <button
                onClick={() => setShowSignUpPrompt(false)}
                className="rounded-[var(--radius-input)] border border-[var(--color-border)] px-3 py-1.5 text-sm"
              >
                Try again
              </button>
              <Link
                href="/auth/email-signup"
                className="rounded-[var(--radius-input)] bg-[var(--color-brand)] px-3 py-1.5 text-sm font-medium text-white"
              >
                Sign up
              </Link>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
