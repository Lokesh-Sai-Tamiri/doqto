import { NextResponse } from "next/server";

import { rejectOrg, ApiError } from "@/lib/api";

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  let body: { reason?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { error: "Please provide a rejection reason." },
      { status: 400 },
    );
  }

  const reason = body.reason?.trim();
  if (!reason) {
    return NextResponse.json(
      { error: "Please provide a rejection reason." },
      { status: 400 },
    );
  }

  try {
    const org = await rejectOrg(id, reason);
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
