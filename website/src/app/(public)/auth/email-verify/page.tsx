"use client";

import { Suspense, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

function VerifyForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const email = searchParams.get("email") ?? "";
  const username = searchParams.get("username") ?? "";
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [resendMessage, setResendMessage] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);

    const supabase = createClient();
    const { data, error: verifyError } = await supabase.auth.verifyOtp({
      email,
      token: code.trim(),
      type: "signup",
    });

    if (verifyError || !data.user) {
      setLoading(false);
      setError(verifyError?.message ?? "Verification failed");
      return;
    }

    // Now that a session exists, claim the username chosen at signup.
    if (username) {
      await supabase.from("users").update({ username }).eq("id", data.user.id);
    }

    setLoading(false);
    router.push("/");
    router.refresh();
  }

  async function handleResend() {
    const supabase = createClient();
    const { error: resendError } = await supabase.auth.resend({ type: "signup", email });
    setResendMessage(resendError ? "Couldn't resend right now." : "Sent a new code.");
  }

  return (
    <div className="mx-auto flex max-w-sm flex-col px-6 py-24">
      <h1 className="text-2xl font-semibold text-[var(--color-text-primary)]">Check your email</h1>
      <p className="mt-2 text-[var(--color-text-secondary)]">
        Enter the 6-digit code we sent to {email}.
      </p>
      <form onSubmit={handleSubmit} className="mt-8 flex flex-col gap-4">
        <input
          required
          maxLength={6}
          placeholder="123456"
          value={code}
          onChange={(e) => setCode(e.target.value)}
          className="rounded-[var(--radius-input)] border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-3 py-2 text-center text-lg tracking-[0.3em] outline-none"
        />
        {error && <p className="text-sm text-[var(--color-danger)]">{error}</p>}
        <button
          type="submit"
          disabled={loading}
          className="rounded-[var(--radius-input)] bg-[var(--color-brand)] px-4 py-2 font-medium text-white disabled:opacity-60"
        >
          {loading ? "Verifying..." : "Verify"}
        </button>
      </form>
      <button onClick={handleResend} className="mt-4 text-center text-sm text-[var(--color-brand)]">
        Resend code
      </button>
      {resendMessage && (
        <p className="mt-2 text-center text-xs text-[var(--color-text-secondary)]">{resendMessage}</p>
      )}
    </div>
  );
}

export default function EmailVerifyPage() {
  return (
    <Suspense>
      <VerifyForm />
    </Suspense>
  );
}
