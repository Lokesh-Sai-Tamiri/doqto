import { NextResponse } from "next/server";

import { approveOrg, ApiError } from "@/lib/api";

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  let body: { notes?: string | null } = {};
  try {
    body = await request.json();
  } catch {
    // empty body is fine — notes is optional
  }

  try {
    const org = await approveOrg(id, body.notes ?? undefined);
    return NextResponse.json(org);
  } catch (error) {
    if (error instanceof ApiError) {
      return NextResponse.json(
        { error: error.message },
        { status: error.status || 500 },
      );
    }
    return NextResponse.json(
      { error: "Something went wrong. Please try again." },
      { status: 500 },
    );
  }
}
