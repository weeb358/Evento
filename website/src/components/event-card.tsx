import Image from "next/image";
import Link from "next/link";
import type { EventRow } from "@/lib/types";

function formatDateTime(iso: string): string {
  return new Date(iso).toLocaleString("en-US", {
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

export function EventCard({ event }: { event: EventRow }) {
  return (
    <Link
      href={`/events/${event.id}`}
      className="block overflow-hidden rounded-[var(--radius-card)] border border-[var(--color-border)] bg-[var(--color-bg-surface-raised)] transition hover:border-[var(--color-brand)]"
    >
      <div className="relative aspect-video bg-[var(--color-bg-surface)]">
        {event.cover_image_url ? (
          <Image
            src={event.cover_image_url}
            alt={event.title}
            fill
            className="object-cover"
            sizes="(max-width: 768px) 100vw, 33vw"
          />
        ) : (
          <div className="flex h-full items-center justify-center text-3xl">🎉</div>
        )}
        {event.is_featured && (
          <span className="absolute left-2 top-2 rounded-full bg-[var(--color-brand)] px-2 py-0.5 text-[10px] font-bold text-white">
            FEATURED
          </span>
        )}
      </div>
      <div className="p-4">
        <h3 className="truncate font-semibold text-[var(--color-text-primary)]">{event.title}</h3>
        <p className="mt-1 truncate text-sm text-[var(--color-text-secondary)]">
          {formatDateTime(event.start_time)} · {event.city}
        </p>
        <p className="mt-1 text-sm font-semibold text-[var(--color-brand)]">
          {event.price > 0 ? `Rs ${event.price.toFixed(0)}` : "Free"}
        </p>
      </div>
    </Link>
  );
}
