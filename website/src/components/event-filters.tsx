"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { EVENT_CATEGORIES, CITIES } from "@/lib/types";

export function EventFilters() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const city = searchParams.get("city") ?? "";
  const category = searchParams.get("category") ?? "";

  function updateParam(key: string, value: string) {
    const params = new URLSearchParams(searchParams.toString());
    if (value) params.set(key, value);
    else params.delete(key);
    router.push(`/events?${params.toString()}`);
  }

  return (
    <div className="flex flex-wrap gap-4">
      <select
        className="rounded-[var(--radius-input)] border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-3 py-2 text-sm"
        value={city}
        onChange={(e) => updateParam("city", e.target.value)}
      >
        <option value="">All cities</option>
        {CITIES.map((c) => (
          <option key={c} value={c}>
            {c}
          </option>
        ))}
      </select>
      <select
        className="rounded-[var(--radius-input)] border border-[var(--color-border)] bg-[var(--color-bg-surface)] px-3 py-2 text-sm"
        value={category}
        onChange={(e) => updateParam("category", e.target.value)}
      >
        <option value="">All categories</option>
        {EVENT_CATEGORIES.map((c) => (
          <option key={c} value={c}>
            {c}
          </option>
        ))}
      </select>
    </div>
  );
}
