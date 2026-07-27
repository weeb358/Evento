import Link from "next/link";
import { EventCard } from "@/components/event-card";
import { getPublishedEvents } from "@/lib/data/events";

export default async function Home() {
  const events = await getPublishedEvents();
  const featured = events.slice(0, 6);

  return (
    <div className="mx-auto max-w-6xl px-6 py-24">
      <div className="flex flex-col items-center text-center">
        <span
          aria-hidden
          className="mb-6 flex h-14 w-14 items-center justify-center rounded-full bg-[var(--color-brand)]/10 text-2xl"
        >
          🎉
        </span>
        <h1 className="max-w-2xl text-4xl font-semibold tracking-tight text-[var(--color-text-primary)]">
          Discover what&apos;s happening around you
        </h1>
        <p className="mt-4 max-w-xl text-lg text-[var(--color-text-secondary)]">
          Concerts, meetups, workshops, and more across Pakistan — all in one place.
        </p>
        <div className="mt-8 flex gap-3">
          <Link
            href="/events"
            className="rounded-[var(--radius-input)] bg-[var(--color-brand)] px-5 py-2.5 font-medium text-white"
          >
            Browse events
          </Link>
          <Link
            href="/hosting"
            className="rounded-[var(--radius-input)] border border-[var(--color-border)] px-5 py-2.5 font-medium text-[var(--color-text-primary)]"
          >
            Find a host
          </Link>
        </div>
      </div>

      {featured.length > 0 && (
        <div className="mt-20">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-semibold text-[var(--color-text-primary)]">Happening soon</h2>
            <Link href="/events" className="text-sm font-medium text-[var(--color-brand)]">
              See all
            </Link>
          </div>
          <div className="mt-6 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {featured.map((event) => (
              <EventCard key={event.id} event={event} />
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
