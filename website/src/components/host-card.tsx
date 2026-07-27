import Link from "next/link";
import type { HostProfileRow } from "@/lib/types";

export function HostCard({
  host,
  hostName,
}: {
  host: HostProfileRow;
  hostName: string;
}) {
  return (
    <Link
      href={`/hosting/${host.id}`}
      className="block rounded-[var(--radius-card)] border border-[var(--color-border)] bg-[var(--color-bg-surface-raised)] p-4 transition hover:border-[var(--color-brand)]"
    >
      <div className="flex items-center gap-2">
        <h3 className="font-semibold text-[var(--color-text-primary)]">{hostName}</h3>
        {host.verification_status === "verified" && <span title="Verified host">✅</span>}
      </div>
      {host.headline && <p className="mt-1 text-sm text-[var(--color-text-secondary)]">{host.headline}</p>}
      <p className="mt-1 text-sm text-[var(--color-text-secondary)]">{host.city}</p>
    </Link>
  );
}
