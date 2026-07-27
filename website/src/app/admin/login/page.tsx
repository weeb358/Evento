"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function AdminLoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);

    const supabase = createClient();
    const { data, error: signInError } = await supabase.auth.signInWithPassword({ email, password });

    if (signInError || !data.user) {
      setLoading(false);
      setError("Invalid admin credentials.");
      return;
    }

    const { data: profile } = await supabase.from("users").select("role").eq("id", data.user.id).single();

    if (profile?.role !== "admin") {
      await supabase.auth.signOut();
      setLoading(false);
      setError("This account doesn't have admin access.");
      return;
    }

    setLoading(false);
    router.push("/admin");
    router.refresh();
  }

  return (
    <div className="flex min-h-full flex-1 items-center justify-center bg-[var(--color-bg-surface)] px-6">
      <div className="w-full max-w-sm rounded-[var(--radius-card)] border border-[var(--color-border)] bg-[var(--color-bg-surface-raised)] p-8">
        <h1 className="text-xl font-semibold text-[var(--color-text-primary)]">Admin sign in</h1>
        <p className="mt-1 text-sm text-[var(--color-text-secondary)]">
          Restricted to admin accounts. See docs/ARCHITECTURE.md to grant access.
        </p>
        <form onSubmit={handleSubmit} className="mt-6 flex flex-col gap-4">
          <input
            type="email"
            required
            placeholder="Admin email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="rounded-[var(--radius-input)] border border-[var(--color-border)] bg-[var(--color-bg-base)] px-3 py-2 outline-none"
          />
          <input
            type="password"
            required
            placeholder="Password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="rounded-[var(--radius-input)] border border-[var(--color-border)] bg-[var(--color-bg-base)] px-3 py-2 outline-none"
          />
          {error && <p className="text-sm text-[var(--color-danger)]">{error}</p>}
          <button
            type="submit"
            disabled={loading}
            className="rounded-[var(--radius-input)] bg-[var(--color-brand)] px-4 py-2 font-medium text-white disabled:opacity-60"
          >
            {loading ? "Signing in..." : "Sign in"}
          </button>
        </form>
      </div>
    </div>
  );
}
