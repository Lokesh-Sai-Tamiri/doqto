import { NextRequest, NextResponse } from "next/server";
import { getDb } from "@/lib/mongodb";

const COLLECTION = "waitlist";

export async function POST(request: NextRequest) {
  try {
    const { email } = await request.json();

    if (!email || typeof email !== "string") {
      return NextResponse.json(
        { success: false, message: "Email is required." },
        { status: 400 }
      );
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return NextResponse.json(
        { success: false, message: "Please enter a valid email address." },
        { status: 400 }
      );
    }

    const db = await getDb();
    const collection = db.collection(COLLECTION);

    const normalizedEmail = email.toLowerCase().trim();

    const existing = await collection.findOne({ email: normalizedEmail });
    if (existing) {
      return NextResponse.json(
        { success: true, message: "You're already on the waitlist!" },
        { status: 200 }
      );
    }

    await collection.insertOne({
      email: normalizedEmail,
      created_at: new Date(),
      source: "landing_page",
    });

    return NextResponse.json(
      { success: true, message: "Successfully joined the waitlist!" },
      { status: 200 }
    );
  } catch (error) {
    console.error("Waitlist error:", error);
    return NextResponse.json(
      { success: false, message: "Something went wrong. Please try again." },
      { status: 500 }
    );
  }
}
