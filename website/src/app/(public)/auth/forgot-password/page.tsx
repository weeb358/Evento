"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    const supabase = createClient();
    const { error: resetError } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/auth/reset-password`,
    });
    setLoading(false);

    if (resetError) {
      setError(resetError.message);
      return;
    }
    setSent(true);
  }

  if (sent) {
    return (
      <div className="mx-auto flex max-w-sm flex-col px-6 py-24 text-center">
        <h1 className="text-2xl font-semibold text-[var(--color-text-primary)]">Check your email</h1>
        <p className="mt-2 text-[var(--color-text-secondary)]">
          We sent a password reset link to {email}. Open it to set a new password.
        </p>
      </div>
    );
  }

  return (
    <div className="mx-auto flex max-w-sm flex-col px-6 py-24">
      <h1 className="text-2xl font-semibold text-[var(--color-text-primary)]">Reset your password</h1>
      <p className="mt-2 text-[var(--color-text-secondary)]">
        Enter your email and we&apos;ll send you a link to reset it.
      </p>
      <form onSubmit={handleSubmit} className="mt-8 flex flex-col gap-4">
        <input
          type="email"
          required
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="rounded-[var(--radius-input)] border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-3 py-2 outline-none"
        />
        {error && <p className="text-sm text-[var(--color-danger)]">{error}</p>}
        <button
          type="submit"
          disabled={loading}
          className="rounded-[var(--radius-input)] bg-[var(--color-brand)] px-4 py-2 font-medium text-white disabled:opacity-60"
        >
          {loading ? "Sending..." : "Send reset link"}
        </button>
      </form>
    </div>
  );
}
