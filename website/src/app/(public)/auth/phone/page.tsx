"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function PhoneEntryPage() {
  const router = useRouter();
  const [phone, setPhone] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const digits = phone.trim();
    if (!/^\d{9,10}$/.test(digits)) {
      setError("Enter a valid Pakistani mobile number");
      return;
    }

    setLoading(true);
    setError(null);
    const e164 = `+92${digits}`;
    const supabase = createClient();
    const { error: otpError } = await supabase.auth.signInWithOtp({ phone: e164 });
    setLoading(false);

    if (otpError) {
      setError(otpError.message);
      return;
    }
    router.push(`/auth/otp?phone=${encodeURIComponent(e164)}`);
  }

  return (
    <div className="mx-auto flex max-w-sm flex-col px-6 py-24">
      <h1 className="text-2xl font-semibold text-[var(--color-text-primary)]">Sign in</h1>
      <p className="mt-2 text-[var(--color-text-secondary)]">
        Enter your phone number to sign in or create an account.
      </p>
      <form onSubmit={handleSubmit} className="mt-8 flex flex-col gap-4">
        <label className="flex flex-col gap-1 text-sm">
          Phone number
          <div className="flex items-center rounded-[var(--radius-input)] border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-3">
            <span className="text-[var(--color-text-secondary)]">+92</span>
            <input
              className="w-full bg-transparent px-2 py-2 outline-none"
              inputMode="numeric"
              placeholder="3001234567"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
            />
          </div>
        </label>
        {error && <p className="text-sm text-[var(--color-danger)]">{error}</p>}
        <button
          type="submit"
          disabled={loading}
          className="rounded-[var(--radius-input)] bg-[var(--color-brand)] px-4 py-2 font-medium text-white disabled:opacity-60"
        >
          {loading ? "Sending..." : "Send code"}
        </button>
      </form>
      <Link href="/auth/email-login" className="mt-6 block text-center text-sm text-[var(--color-brand)]">
        Use email instead
      </Link>
    </div>
  );
}
