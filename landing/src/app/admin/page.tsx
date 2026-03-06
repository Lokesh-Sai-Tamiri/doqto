import { getDb } from "@/lib/mongodb";

interface WaitlistEntry {
  email: string;
  created_at: string;
  source?: string;
}

export const dynamic = "force-dynamic";

export default async function AdminPage() {
  const db = await getDb();
  const entries = (await db
    .collection("waitlist")
    .find()
    .sort({ created_at: -1 })
    .toArray()) as unknown as WaitlistEntry[];

  return (
    <main className="min-h-screen px-4 py-12 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-4xl">
        <div className="mb-8 flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-white">
              Waitlist Submissions
            </h1>
            <p className="mt-1 text-text-secondary">
              {entries.length} total signup{entries.length !== 1 ? "s" : ""}
            </p>
          </div>
          <a
            href="/"
            className="text-sm text-text-secondary transition-colors hover:text-white"
          >
            Back to site
          </a>
        </div>

        {entries.length === 0 ? (
          <div className="rounded-lg border border-surface-light bg-surface py-16 text-center">
            <p className="text-text-secondary">No waitlist submissions yet.</p>
          </div>
        ) : (
          <div className="overflow-x-auto rounded-lg border border-surface-light">
            <table className="w-full text-left text-sm">
              <thead className="border-b border-surface-light bg-surface">
                <tr>
                  <th className="px-4 py-3 font-medium text-text-secondary">
                    #
                  </th>
                  <th className="px-4 py-3 font-medium text-text-secondary">
                    Email
                  </th>
                  <th className="px-4 py-3 font-medium text-text-secondary">
                    Date Joined
                  </th>
                  <th className="px-4 py-3 font-medium text-text-secondary">
                    Source
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-surface-light">
                {entries.map((entry, i) => (
                  <tr
                    key={entry.email + i}
                    className="transition-colors hover:bg-surface"
                  >
                    <td className="px-4 py-3 text-text-secondary">{i + 1}</td>
                    <td className="px-4 py-3 text-white">{entry.email}</td>
                    <td className="px-4 py-3 text-text-secondary">
                      {new Date(entry.created_at).toLocaleDateString("en-US", {
                        year: "numeric",
                        month: "short",
                        day: "numeric",
                        hour: "2-digit",
                        minute: "2-digit",
                      })}
                    </td>
                    <td className="px-4 py-3 text-text-secondary">
                      {entry.source || "—"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </main>
  );
}
