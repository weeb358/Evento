import type { Metadata } from "next";
import { getOpenReports } from "@/lib/data/admin";
import { getEventById } from "@/lib/data/events";
import { getUsersByIds } from "@/lib/data/users";
import { updateReportStatus } from "@/lib/actions/admin";

export const metadata: Metadata = { title: "Reports · Admin" };

async function targetLabel(report: Awaited<ReturnType<typeof getOpenReports>>[number]) {
  if (report.target_type === "event") {
    const event = await getEventById(report.target_id);
    return event ? `Event: ${event.title}` : "Event (deleted)";
  }
  const users = await getUsersByIds([report.target_id]);
  const user = users.get(report.target_id);
  return user ? `User: ${user.name ?? user.id}` : "User (deleted)";
}

export default async function AdminReportsPage() {
  const reports = await getOpenReports();
  const labels = await Promise.all(reports.map(targetLabel));

  return (
    <div>
      <h1 className="text-2xl font-semibold text-[var(--color-text-primary)]">Reports</h1>
      {reports.length === 0 ? (
        <p className="mt-4 text-[var(--color-text-secondary)]">No open reports. 🎉</p>
      ) : (
        <div className="mt-6 space-y-3">
          {reports.map((report, i) => (
            <div
              key={report.id}
              className="rounded-[var(--radius-card)] border border-[var(--color-border)] bg-[var(--color-bg-surface-raised)] p-4"
            >
              <div className="flex items-start justify-between gap-4">
                <div>
                  <p className="font-medium text-[var(--color-text-primary)]">{labels[i]}</p>
                  <p className="mt-1 text-sm text-[var(--color-text-secondary)]">{report.reason}</p>
                  <p className="mt-1 text-xs text-[var(--color-text-secondary)]">
                    {new Date(report.created_at).toLocaleString()} · status: {report.status}
                  </p>
                </div>
                <div className="flex shrink-0 gap-2">
                  <form action={updateReportStatus.bind(null, report.id, "resolved")}>
                    <button className="rounded-[var(--radius-input)] bg-[var(--color-success)] px-3 py-1.5 text-sm font-medium text-white">
                      Resolve
                    </button>
                  </form>
                  <form action={updateReportStatus.bind(null, report.id, "dismissed")}>
                    <button className="rounded-[var(--radius-input)] border border-[var(--color-border)] px-3 py-1.5 text-sm font-medium">
                      Dismiss
                    </button>
                  </form>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
