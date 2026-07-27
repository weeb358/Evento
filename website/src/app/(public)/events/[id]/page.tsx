import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import type { Metadata } from "next";
import { getEventById, getEventRsvpCounts, getOrganizer } from "@/lib/data/events";
import { getReviewsFor, averageRating } from "@/lib/data/reviews";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}): Promise<Metadata> {
  const { id } = await params;
  const event = await getEventById(id);
  return { title: event?.title ?? "Event" };
}

export default async function EventDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const event = await getEventById(id);
  if (!event || event.status !== "published") notFound();

  const [organizer, counts, reviews] = await Promise.all([
    getOrganizer(event.organizer_id),
    getEventRsvpCounts(event.id),
    getReviewsFor("event", event.id),
  ]);

  const startTime = new Date(event.start_time).toLocaleString("en-US", {
    weekday: "long",
    month: "long",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });

  return (
    <div className="mx-auto max-w-3xl px-6 py-12">
      <div className="relative aspect-video overflow-hidden rounded-[var(--radius-card)] bg-[var(--color-bg-surface)]">
        {event.cover_image_url ? (
          <Image src={event.cover_image_url} alt={event.title} fill className="object-cover" />
        ) : (
          <div className="flex h-full items-center justify-center text-5xl">🎉</div>
        )}
      </div>

      {event.is_featured && (
        <span className="mt-4 inline-block rounded-full bg-[var(--color-brand)] px-2 py-0.5 text-[10px] font-bold text-white">
          FEATURED
        </span>
      )}

      <h1 className="mt-4 text-3xl font-semibold text-[var(--color-text-primary)]">{event.title}</h1>

      <div className="mt-4 space-y-1 text-[var(--color-text-secondary)]">
        <p>📅 {startTime}</p>
        <p>
          📍 {[event.venue_name, event.city].filter(Boolean).join(", ")}
        </p>
        <p>💰 {event.price > 0 ? `Rs ${event.price.toFixed(0)}` : "Free"}</p>
        <p>
          {counts.going} going · {counts.interested} interested
        </p>
      </div>

      {organizer && (
        <p className="mt-4 text-sm text-[var(--color-text-secondary)]">
          Hosted by <span className="font-medium text-[var(--color-text-primary)]">{organizer.name}</span>
        </p>
      )}

      {event.description && <p className="mt-6 whitespace-pre-line">{event.description}</p>}

      <div className="mt-8 rounded-[var(--radius-card)] border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-4">
        <p className="text-sm text-[var(--color-text-secondary)]">
          RSVP, save, and get reminders from the Events Platform app.
        </p>
        <Link
          href="/"
          className="mt-2 inline-block rounded-[var(--radius-input)] bg-[var(--color-brand)] px-4 py-2 text-sm font-medium text-white"
        >
          Open in app
        </Link>
      </div>

      <section className="mt-10">
        <h2 className="text-xl font-semibold text-[var(--color-text-primary)]">
          Reviews {reviews.length > 0 && `· ${averageRating(reviews).toFixed(1)}★`}
        </h2>
        {reviews.length === 0 ? (
          <p className="mt-2 text-[var(--color-text-secondary)]">No reviews yet.</p>
        ) : (
          <ul className="mt-4 space-y-3">
            {reviews.map((review) => (
              <li key={review.id} className="text-sm">
                <span className="font-medium">{"★".repeat(review.rating)}</span>{" "}
                {review.text && <span className="text-[var(--color-text-secondary)]">{review.text}</span>}
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
