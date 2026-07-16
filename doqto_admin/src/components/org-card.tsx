"use client";

import { Building2, MapPin, Users } from "lucide-react";
import { useState } from "react";

import { ApproveDialog } from "@/components/approve-dialog";
import { RejectDialog } from "@/components/reject-dialog";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import type { Organization } from "@/lib/types";

function formatDate(iso: string) {
  const date = new Date(iso);
  return date.toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

export function OrgCard({ org }: { org: Organization }) {
  const [approveOpen, setApproveOpen] = useState(false);
  const [rejectOpen, setRejectOpen] = useState(false);

  return (
    <Card className="flex flex-col gap-4">
      <div className="flex items-start justify-between gap-4">
        <div className="flex gap-4">
          <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-primary-light text-primary-dark shrink-0">
            <Building2 size={22} />
          </div>
          <div>
            <h3 className="text-lg font-bold text-gray-900">{org.name}</h3>
            <div className="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-gray-600">
              {(org.city || org.state) && (
                <span className="inline-flex items-center gap-1">
                  <MapPin size={14} />
                  {[org.city, org.state].filter(Boolean).join(", ")}
                </span>
              )}
              {org.practice_type && (
                <span className="capitalize">
                  {org.practice_type.replaceAll("_", " ")}
                </span>
              )}
              <span className="inline-flex items-center gap-1">
                <Users size={14} /> {org.member_count} member
                {org.member_count === 1 ? "" : "s"}
              </span>
            </div>
          </div>
        </div>
        <Badge tone={org.status}>{org.status}</Badge>
      </div>

      <dl className="grid grid-cols-2 gap-x-6 gap-y-2 text-sm">
        <div>
          <dt className="text-[11px] uppercase tracking-wider text-gray-400">
            Invite code
          </dt>
          <dd className="font-mono font-bold tracking-[0.2em] text-primary-dark">
            {org.invite_code}
          </dd>
        </div>
        <div>
          <dt className="text-[11px] uppercase tracking-wider text-gray-400">
            Submitted
          </dt>
          <dd className="text-gray-800">{formatDate(org.created_at)}</dd>
        </div>
      </dl>

      {org.review_notes && (
        <div className="rounded-md bg-surface-alt px-3 py-2 text-sm">
          <div className="text-[11px] uppercase tracking-wider text-gray-400 mb-1">
            Review notes
          </div>
          <div className="text-gray-800 whitespace-pre-wrap">
            {org.review_notes}
          </div>
        </div>
      )}

      {org.status === "pending" && (
        <div className="flex gap-2 pt-2">
          <Button
            variant="success"
            size="sm"
            onClick={() => setApproveOpen(true)}
          >
            Approve
          </Button>
          <Button
            variant="danger"
            size="sm"
            onClick={() => setRejectOpen(true)}
          >
            Reject
          </Button>
        </div>
      )}

      <ApproveDialog
        open={approveOpen}
        onClose={() => setApproveOpen(false)}
        org={org}
      />
      <RejectDialog
        open={rejectOpen}
        onClose={() => setRejectOpen(false)}
        org={org}
      />
    </Card>
  );
}
