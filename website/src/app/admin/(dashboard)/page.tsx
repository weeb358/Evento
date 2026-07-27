import Link from "next/link";
import { getOpenReports, getPendingHostVerifications } from "@/lib/data/admin";

export default async function AdminDashboard() {
  const [reports, verifications] = await Promise.all([getOpenReports(), getPendingHostVerifications()]);

  return (
    <div>
      <h1 className="text-2xl font-semibold text-[var(--color-text-primary)]">Moderation</h1>
      <div className="mt-6 grid grid-cols-2 gap-4">
        <Link
          href="/admin/reports"
          className="rounded-[var(--radius-card)] border border-[var(--color-border)] bg-[var(--color-bg-surface-raised)] p-6"
        >
          <p className="text-3xl font-semibold text-[var(--color-text-primary)]">{reports.length}</p>
          <p className="mt-1 text-sm text-[var(--color-text-secondary)]">Open reports</p>
        </Link>
        <Link
          href="/admin/verifications"
          className="rounded-[var(--radius-card)] border border-[var(--color-border)] bg-[var(--color-bg-surface-raised)] p-6"
        >
          <p className="text-3xl font-semibold text-[var(--color-text-primary)]">{verifications.length}</p>
          <p className="mt-1 text-sm text-[var(--color-text-secondary)]">Pending host verifications</p>
        </Link>
      </div>
    </div>
  );
}
