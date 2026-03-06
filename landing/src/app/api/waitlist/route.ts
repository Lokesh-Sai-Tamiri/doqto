import { NextRequest, NextResponse } from "next/server";
import fs from "fs/promises";
import path from "path";

const WAITLIST_FILE = path.join(process.cwd(), "waitlist.json");

async function getWaitlist(): Promise<string[]> {
  try {
    const data = await fs.readFile(WAITLIST_FILE, "utf-8");
    return JSON.parse(data);
  } catch {
    return [];
  }
}

async function saveWaitlist(emails: string[]) {
  await fs.writeFile(WAITLIST_FILE, JSON.stringify(emails, null, 2));
}

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

    const waitlist = await getWaitlist();

    if (waitlist.includes(email.toLowerCase())) {
      return NextResponse.json(
        { success: true, message: "You're already on the waitlist!" },
        { status: 200 }
      );
    }

    waitlist.push(email.toLowerCase());
    await saveWaitlist(waitlist);

    return NextResponse.json(
      { success: true, message: "Successfully joined the waitlist!" },
      { status: 200 }
    );
  } catch {
    return NextResponse.json(
      { success: false, message: "Something went wrong. Please try again." },
      { status: 500 }
    );
  }
}
