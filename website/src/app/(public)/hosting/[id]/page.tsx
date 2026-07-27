import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import type { Metadata } from "next";
import { getHostById, getHostPhotos, getHostUser } from "@/lib/data/hosts";
import { getReviewsFor, averageRating } from "@/lib/data/reviews";

const HOME_TYPE_LABELS: Record<string, string> = {
  apartment: "Apartment",
  house: "House",
  private_room: "Private room",
  shared_room: "Shared room",
};

export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>;
}): Promise<Metadata> {
  const { id } = await params;
  const user = await getHostUser(id);
  return { title: user?.name ? `Stay with ${user.name}` : "Host" };
}

export default async function HostDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const host = await getHostById(id);
  if (!host || !host.is_active) notFound();

  const [user, photos, reviews] = await Promise.all([
    getHostUser(id),
    getHostPhotos(id),
    getReviewsFor("user", id),
  ]);

  return (
    <div className="mx-auto max-w-3xl px-6 py-12">
      {photos.length > 0 ? (
        <div className="flex gap-3 overflow-x-auto pb-2">
          {photos.map((photo) => (
            <div key={photo.id} className="relative h-48 w-64 shrink-0 overflow-hidden rounded-[var(--radius-card)]">
              <Image src={photo.url} alt="" fill className="object-cover" />
            </div>
          ))}
        </div>
      ) : (
        <div className="flex h-48 items-center justify-center rounded-[var(--radius-card)] bg-[var(--color-bg-surface)] text-4xl">
          🏠
        </div>
      )}

      <div className="mt-6 flex items-center gap-2">
        <h1 className="text-2xl font-semibold text-[var(--color-text-primary)]">{user?.name ?? "Host"}</h1>
        {host.verification_status === "verified" && <span title="Verified host">✅</span>}
      </div>
      {host.headline && <p className="mt-1 text-[var(--color-text-secondary)]">{host.headline}</p>}

      <div className="mt-4 flex flex-wrap gap-2 text-sm">
        {host.home_type && (
          <span className="rounded-full border border-[var(--color-border)] px-3 py-1">
            {HOME_TYPE_LABELS[host.home_type] ?? host.home_type}
          </span>
        )}
        {host.max_guests && (
          <span className="rounded-full border border-[var(--color-border)] px-3 py-1">
            Up to {host.max_guests} guests
          </span>
        )}
        {host.city && <span className="rounded-full border border-[var(--color-border)] px-3 py-1">{host.city}</span>}
      </div>

      {host.about && (
        <div className="mt-6">
          <h2 className="font-semibold text-[var(--color-text-primary)]">About</h2>
          <p className="mt-2 whitespace-pre-line text-[var(--color-text-secondary)]">{host.about}</p>
        </div>
      )}

      {host.house_rules && (
        <div className="mt-6">
          <h2 className="font-semibold text-[var(--color-text-primary)]">House rules</h2>
          <p className="mt-2 whitespace-pre-line text-[var(--color-text-secondary)]">{host.house_rules}</p>
        </div>
      )}

      <div className="mt-8 rounded-[var(--radius-card)] border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-4">
        <p className="text-sm text-[var(--color-text-secondary)]">
          Request a stay and message hosts from the Events Platform app.
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
