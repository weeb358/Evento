import type { Metadata } from "next";
import { EventCard } from "@/components/event-card";
import { EventFilters } from "@/components/event-filters";
import { getPublishedEvents } from "@/lib/data/events";

export const metadata: Metadata = { title: "Browse events" };

export default async function EventsPage({
  searchParams,
}: {
  searchParams: Promise<{ city?: string; category?: string; q?: string }>;
}) {
  const { city, category, q } = await searchParams;
  const events = await getPublishedEvents({ city, category, search: q });

  return (
    <div className="mx-auto max-w-6xl px-6 py-12">
      <h1 className="text-3xl font-semibold text-[var(--color-text-primary)]">Browse events</h1>
      <div className="mt-6">
        <EventFilters />
      </div>
      {events.length === 0 ? (
        <p className="mt-16 text-center text-[var(--color-text-secondary)]">
          No events found. Try a different city or category.
        </p>
      ) : (
        <div className="mt-8 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {events.map((event) => (
            <EventCard key={event.id} event={event} />
          ))}
        </div>
      )}
    </div>
  );
}
