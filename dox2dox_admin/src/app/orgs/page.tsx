import { Suspense } from "react";

import { OrgCard } from "@/components/org-card";
import { StatusTabs } from "@/components/status-tabs";
import { ApiError, listOrgs } from "@/lib/api";
import type { OrgStatus } from "@/lib/types";

const VALID_STATUSES: ReadonlySet<string> = new Set([
  "pending",
  "active",
  "suspended",
  "all",
]);

interface PageProps {
  searchParams: Promise<{ status?: string }>;
}

export default async function OrgsPage({ searchParams }: PageProps) {
  const { status: raw } = await searchParams;
  const status = (VALID_STATUSES.has(raw ?? "") ? raw : "pending") as
    | OrgStatus
    | "all";

  let orgs = [] as Awaited<ReturnType<typeof listOrgs>>;
  let error: string | null = null;
  try {
    orgs = await listOrgs(status);
  } catch (err) {
    error = err instanceof ApiError ? err.message : "Unable to load organizations.";
  }

  return (
    <main className="px-10 py-10 max-w-5xl">
      <header className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Organizations</h1>
        <p className="mt-1 text-sm text-gray-600">
          Review and approve new organizations joining Dox2Dox.
        </p>
      </header>

      <Suspense
        fallback={<div className="h-12 animate-pulse rounded-md bg-gray-100" />}
      >
        <StatusTabs />
      </Suspense>

      <div className="mt-6 flex flex-col gap-4">
        {error ? (
          <div className="rounded-lg border border-danger-light bg-danger-light px-4 py-3 text-sm text-danger">
            {error}
          </div>
        ) : orgs.length === 0 ? (
          <EmptyState status={status} />
        ) : (
          orgs.map((org) => <OrgCard key={org.id} org={org} />)
        )}
      </div>
    </main>
  );
}

function EmptyState({ status }: { status: string }) {
  const copy: Record<string, { title: string; body: string }> = {
    pending: {
      title: "No pending organizations",
      body: "New signups from the mobile app will show up here for review.",
    },
    active: {
      title: "No active organizations",
      body: "Approved organizations will appear here.",
    },
    suspended: {
      title: "No rejected organizations",
      body: "Organizations you reject will appear here for reference.",
    },
    all: {
      title: "No organizations yet",
      body: "Once doctors start signing up from the mobile app their organizations will appear here.",
    },
  };
  const { title, body } = copy[status] ?? copy.all;
  return (
    <div className="rounded-lg border border-dashed border-gray-200 bg-white/50 px-8 py-16 text-center">
      <div className="text-base font-semibold text-gray-800">{title}</div>
      <div className="mt-1 text-sm text-gray-600">{body}</div>
    </div>
  );
}
