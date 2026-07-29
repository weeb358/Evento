"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { GoogleSignInButton } from "@/components/google-sign-in-button";

function isValidUsername(value: string) {
  return /^[a-z0-9_]{3,20}$/.test(value);
}

export default function EmailSignUpPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [username, setUsername] = useState("");
  // Only trusted when checkedUsername matches the current (normalized)
  // username — avoids a stale "available" result flashing while the user
  // keeps typing, without needing a synchronous setState(null) reset
  // directly in the effect body (which react-hooks/set-state-in-effect
  // flags as a cascading-render risk).
  const [checkedUsername, setCheckedUsername] = useState<string | null>(null);
  const [usernameAvailable, setUsernameAvailable] = useState<boolean | null>(null);
  const [checkingUsername, setCheckingUsername] = useState(false);
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [wantsToOrganize, setWantsToOrganize] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const normalizedUsername = username.trim().toLowerCase();
  const displayUsernameAvailable = checkedUsername === normalizedUsername ? usernameAvailable : null;

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    if (!isValidUsername(normalizedUsername)) return;

    debounceRef.current = setTimeout(async () => {
      setCheckingUsername(true);
      const supabase = createClient();
      const { data } = await supabase
        .from("users")
        .select("id")
        .eq("username", normalizedUsername)
        .maybeSingle();
      setCheckingUsername(false);
      setCheckedUsername(normalizedUsername);
      setUsernameAvailable(data === null);
    }, 400);

    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [normalizedUsername]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    if (!isValidUsername(normalizedUsername)) {
      setError("Username must be 3-20 characters: lowercase letters, numbers, underscore");
      return;
    }
    if (displayUsernameAvailable === false) {
      setError("That username is taken");
      return;
    }
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
    const { error: signUpError } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: wantsToOrganize ? { requested_role: "event_planner" } : undefined,
      },
    });
    setLoading(false);

    if (signUpError) {
      setError(signUpError.message);
      return;
    }

    // Username/name are set after the code is verified (a session is
    // required — see /auth/email-verify), same as the app's flow.
    router.push(
      `/auth/email-verify?email=${encodeURIComponent(email)}&username=${encodeURIComponent(normalizedUsername)}`,
    );
  }

  return (
    <div className="mx-auto flex max-w-sm flex-col px-6 py-24">
      <h1 className="text-2xl font-semibold text-[var(--color-text-primary)]">Create your account</h1>
      <div className="mt-8">
        <GoogleSignInButton />
      </div>
      <div className="my-6 flex items-center gap-3">
        <div className="h-px flex-1 bg-[var(--color-border)]" />
        <span className="text-xs text-[var(--color-text-secondary)]">or</span>
        <div className="h-px flex-1 bg-[var(--color-border)]" />
      </div>
      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <input
          type="email"
          required
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="rounded-[var(--radius-input)] border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-3 py-2 outline-none"
        />
        <div>
          <input
            required
            placeholder="Username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            className="w-full rounded-[var(--radius-input)] border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-3 py-2 outline-none"
          />
          <p className="mt-1 text-xs text-[var(--color-text-secondary)]">
            {checkingUsername
              ? "Checking..."
              : displayUsernameAvailable === true
                ? "✓ Available"
                : displayUsernameAvailable === false
                  ? "Taken"
                  : "Lowercase letters, numbers, underscore — 3 to 20 characters"}
          </p>
        </div>
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
