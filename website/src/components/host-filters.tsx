"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { CITIES } from "@/lib/types";

export function HostFilters() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const city = searchParams.get("city") ?? "";

  return (
    <select
      className="rounded-[var(--radius-input)] border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-3 py-2 text-sm"
      value={city}
      onChange={(e) => {
        const params = new URLSearchParams(searchParams.toString());
        if (e.target.value) params.set("city", e.target.value);
        else params.delete("city");
        router.push(`/hosting?${params.toString()}`);
      }}
    >
      <option value="">All cities</option>
      {CITIES.map((c) => (
        <option key={c} value={c}>
          {c}
        </option>
      ))}
    </select>
  );
}
