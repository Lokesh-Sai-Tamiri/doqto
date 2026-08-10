"use client";

import { useState } from "react";

interface WaitlistEntry {
  email: string;
  created_at: string;
  source?: string;
}

export default function AdminPage() {
  const [token, setToken] = useState("");
  const [entries, setEntries] = useState<WaitlistEntry[] | null>(null);
  const [error, setError] = useState("");

  async function load() {
    setError("");
    const res = await fetch("/api/waitlist", {
      headers: { "x-admin-token": token },
    });
    if (!res.ok) {
      setError(res.status === 401 ? "Invalid token." : "Failed to load.");
      return;
    }
    const data = await res.json();
    setEntries(data.entries);
  }

  return (
    <main className="min-h-screen px-4 py-12 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-4xl">
        <div className="mb-8 flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-white">
              Waitlist Submissions
            </h1>
            {entries && (
              <p className="mt-1 text-text-secondary">
                {entries.length} total signup{entries.length !== 1 ? "s" : ""}
              </p>
            )}
          </div>
          <a
            href="/"
            className="text-sm text-text-secondary transition-colors hover:text-white"
          >
            Back to site
          </a>
        </div>

        {entries === null ? (
          <div className="rounded-lg border border-surface-light bg-surface p-8">
            <label className="mb-2 block text-sm text-text-secondary">
              Admin token
            </label>
            <div className="flex gap-2">
              <input
                type="password"
                value={token}
                onChange={(e) => setToken(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && load()}
                className="flex-1 rounded-lg border border-surface-light bg-transparent px-3 py-2 text-white"
              />
              <button
                onClick={load}
                className="rounded-lg bg-white px-4 py-2 text-sm font-medium text-black"
              >
                View
              </button>
            </div>
            {error && <p className="mt-3 text-sm text-red-400">{error}</p>}
          </div>
        ) : entries.length === 0 ? (
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
