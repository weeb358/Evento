"use client";

export default function GlobalError({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <div className="mx-auto flex min-h-[60vh] max-w-md flex-col items-center justify-center px-6 text-center">
      <span aria-hidden className="text-4xl">
        ⚠️
      </span>
      <h1 className="mt-4 text-xl font-semibold text-[var(--color-text-primary)]">Something went wrong</h1>
      <p className="mt-2 text-sm text-[var(--color-text-secondary)]">
        We couldn&apos;t load this page. This usually means the app isn&apos;t connected to a Supabase
        project yet — check <code>.env.local</code>.
      </p>
      <button
        onClick={reset}
        className="mt-6 rounded-[var(--radius-input)] bg-[var(--color-brand)] px-4 py-2 text-sm font-medium text-white"
      >
        Try again
      </button>
    </div>
  );
}
