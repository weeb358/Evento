import Link from "next/link";
import { AdminSignOutButton } from "@/components/admin-sign-out-button";

const NAV_ITEMS = [
  { href: "/admin/reports", label: "Reports" },
  { href: "/admin/verifications", label: "Host verifications" },
];

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-full flex-1">
      <aside className="flex w-56 shrink-0 flex-col border-r border-[var(--color-border)] bg-[var(--color-bg-surface)] p-6">
        <p className="text-sm font-semibold text-[var(--color-text-primary)]">Admin</p>
        <nav className="mt-6 flex flex-col gap-1 text-sm">
          {NAV_ITEMS.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="rounded-[var(--radius-input)] px-3 py-2 text-[var(--color-text-secondary)] hover:bg-[var(--color-bg-surface-raised)] hover:text-[var(--color-text-primary)]"
            >
              {item.label}
            </Link>
          ))}
        </nav>
        <div className="mt-auto pt-6">
          <AdminSignOutButton />
        </div>
      </aside>
      <main className="flex-1 p-8">{children}</main>
    </div>
  );
}
