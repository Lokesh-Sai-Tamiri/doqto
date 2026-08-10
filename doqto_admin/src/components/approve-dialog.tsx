"use client";

import { AlertCircle } from "lucide-react";
import { useRouter } from "next/navigation";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { Dialog } from "@/components/ui/dialog";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import type { Organization } from "@/lib/types";

interface Props {
  open: boolean;
  onClose: () => void;
  org: Organization;
}

export function ApproveDialog({ open, onClose, org }: Props) {
  const router = useRouter();
  const [notes, setNotes] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onSubmit() {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`/api/orgs/${org.id}/approve`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ notes: notes.trim() || null }),
      });
      if (!res.ok) {
        const body = (await res.json().catch(() => null)) as
          | { error?: string }
          | null;
        setError(body?.error ?? "Something went wrong. Please try again.");
        return;
      }
      setNotes("");
      onClose();
      router.refresh();
    } catch {
      setError("Couldn't reach the server. Check your connection and try again.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <Dialog
      open={open}
      onClose={loading ? () => {} : onClose}
      title={`Approve ${org.name}?`}
      description="The organization will become active and members will be able to invite doctors using the invite code."
    >
      <div className="flex flex-col gap-3">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="approve-notes">Notes (optional)</Label>
          <Textarea
            id="approve-notes"
            placeholder="e.g. Verified NPI and state license."
            maxLength={500}
            value={notes}
            onChange={(e) => {
              setNotes(e.target.value);
              if (error) setError(null);
            }}
          />
        </div>
        {error && (
          <div className="flex items-start gap-2 text-sm text-danger">
            <AlertCircle size={16} className="mt-0.5 shrink-0" />
            <span>{error}</span>
          </div>
        )}
        <div className="mt-2 flex justify-end gap-2">
          <Button
            type="button"
            variant="ghost"
            onClick={onClose}
            disabled={loading}
          >
            Cancel
          </Button>
          <Button
            type="button"
            variant="success"
            onClick={onSubmit}
            disabled={loading}
          >
            {loading ? "Approving…" : "Approve organization"}
          </Button>
        </div>
      </div>
    </Dialog>
  );
}
