import type { Metadata } from "next";
import { getPendingHostVerifications } from "@/lib/data/admin";
import { getUsersByIds } from "@/lib/data/users";
import { setHostVerification } from "@/lib/actions/admin";

export const metadata: Metadata = { title: "Host verifications · Admin" };

export default async function AdminVerificationsPage() {
  const hosts = await getPendingHostVerifications();
  const users = await getUsersByIds(hosts.map((h) => h.id));

  return (
    <div>
      <h1 className="text-2xl font-semibold text-[var(--color-text-primary)]">Host verifications</h1>
      {hosts.length === 0 ? (
        <p className="mt-4 text-[var(--color-text-secondary)]">No pending verification requests.</p>
      ) : (
        <div className="mt-6 space-y-3">
          {hosts.map((host) => (
            <div
              key={host.id}
              className="flex items-center justify-between rounded-[var(--radius-card)] border border-[var(--color-border)] bg-[var(--color-bg-surface-raised)] p-4"
            >
              <div>
                <p className="font-medium text-[var(--color-text-primary)]">
                  {users.get(host.id)?.name ?? host.id}
                </p>
                <p className="text-sm text-[var(--color-text-secondary)]">{host.headline}</p>
                <p className="text-xs text-[var(--color-text-secondary)]">{host.city}</p>
              </div>
              <div className="flex gap-2">
                <form action={setHostVerification.bind(null, host.id, "verified")}>
                  <button className="rounded-[var(--radius-input)] bg-[var(--color-success)] px-3 py-1.5 text-sm font-medium text-white">
                    Approve
                  </button>
                </form>
                <form action={setHostVerification.bind(null, host.id, "unverified")}>
                  <button className="rounded-[var(--radius-input)] border border-[var(--color-border)] px-3 py-1.5 text-sm font-medium">
                    Reject
                  </button>
                </form>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
