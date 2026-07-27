"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function EmailSignUpPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [name, setName] = useState("");
  const [city, setCity] = useState("");
  const [wantsToOrganize, setWantsToOrganize] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [confirmationSent, setConfirmationSent] = useState(false);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    if (password.length < 6) {
      setError("Password must be at least 6 characters");
      return;
    }
    if (password !== confirmPassword) {
      setError("Passwords don't match");
      return;
    }

    setLoading(true);
    const supabase = createClient();
    const { data, error: signUpError } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: wantsToOrganize ? { requested_role: "event_planner" } : undefined,
      },
    });

    if (signUpError) {
      setLoading(false);
      setError(signUpError.message);
      return;
    }

    // The users row is auto-created by a DB trigger; fill in name/city once
    // there's a session (there isn't one yet if "Confirm email" is on).
    if (data.session) {
      await supabase.from("users").update({ name, city }).eq("id", data.user!.id);
      setLoading(false);
      router.push("/");
      router.refresh();
      return;
    }

    setLoading(false);
    setConfirmationSent(true);
  }

  if (confirmationSent) {
    return (
      <div className="mx-auto flex max-w-sm flex-col px-6 py-24 text-center">
        <h1 className="text-2xl font-semibold text-[var(--color-text-primary)]">Check your email</h1>
        <p className="mt-2 text-[var(--color-text-secondary)]">
          We sent a confirmation link to {email}. Once confirmed, sign in.
        </p>
        <Link
          href="/auth/email-login"
          className="mt-6 rounded-[var(--radius-input)] bg-[var(--color-brand)] px-4 py-2 font-medium text-white"
        >
          Go to sign in
        </Link>
      </div>
    );
  }

  return (
    <div className="mx-auto flex max-w-sm flex-col px-6 py-24">
      <h1 className="text-2xl font-semibold text-[var(--color-text-primary)]">Create your account</h1>
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
          required
          placeholder="Full name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          className="rounded-[var(--radius-input)] border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-3 py-2 outline-none"
        />
        <input
          required
          placeholder="City"
          value={city}
          onChange={(e) => setCity(e.target.value)}
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
        <input
          type="password"
          required
          placeholder="Confirm password"
          value={confirmPassword}
          onChange={(e) => setConfirmPassword(e.target.value)}
          className="rounded-[var(--radius-input)] border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-3 py-2 outline-none"
        />
        <label className="flex items-start gap-2 text-sm text-[var(--color-text-secondary)]">
          <input
            type="checkbox"
            checked={wantsToOrganize}
            onChange={(e) => setWantsToOrganize(e.target.checked)}
            className="mt-1"
          />
          I want to organize events (creates your account as an Event Planner)
        </label>
        {error && <p className="text-sm text-[var(--color-danger)]">{error}</p>}
        <button
          type="submit"
          disabled={loading}
          className="rounded-[var(--radius-input)] bg-[var(--color-brand)] px-4 py-2 font-medium text-white disabled:opacity-60"
        >
          {loading ? "Creating account..." : "Create account"}
        </button>
      </form>
      <Link href="/auth/email-login" className="mt-6 text-center text-sm text-[var(--color-brand)]">
        Already have an account? Sign in
      </Link>
    </div>
  );
}
