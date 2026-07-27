import type { Metadata } from "next";
import { HostCard } from "@/components/host-card";
import { HostFilters } from "@/components/host-filters";
import { getActiveHosts } from "@/lib/data/hosts";
import { getUsersByIds } from "@/lib/data/users";

export const metadata: Metadata = { title: "Find a host" };

export default async function HostingPage({
  searchParams,
}: {
  searchParams: Promise<{ city?: string }>;
}) {
  const { city } = await searchParams;
  const hosts = await getActiveHosts(city);
  const users = await getUsersByIds(hosts.map((h) => h.id));

  return (
    <div className="mx-auto max-w-6xl px-6 py-12">
      <h1 className="text-3xl font-semibold text-[var(--color-text-primary)]">Find a host</h1>
      <p className="mt-2 text-[var(--color-text-secondary)]">
        Couchsurfing-style stays hosted by verified members of the community.
      </p>
      <div className="mt-6">
        <HostFilters />
      </div>
      {hosts.length === 0 ? (
        <p className="mt-16 text-center text-[var(--color-text-secondary)]">No hosts found in this city yet.</p>
      ) : (
        <div className="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {hosts.map((host) => (
            <HostCard key={host.id} host={host} hostName={users.get(host.id)?.name ?? "Host"} />
          ))}
        </div>
      )}
    </div>
  );
}
