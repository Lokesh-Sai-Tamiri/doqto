import { MongoClient } from "mongodb";

const COLLECTION = "waitlist";
let clientPromise;

async function getDb() {
  clientPromise ??= new MongoClient(process.env.MONGO_URI).connect();
  const client = await clientPromise;
  return client.db(process.env.MONGODB_DATABASE || "hymn-chat");
}

const json = (status, body) => ({
  statusCode: status,
  headers: { "content-type": "application/json" },
  body: JSON.stringify(body),
});

export async function handler(event) {
  const method = event.requestContext.http.method;
  try {
    if (method === "POST") return await join(event);
    if (method === "GET") return await list(event);
    return json(405, { success: false, message: "Method not allowed." });
  } catch (err) {
    console.error("Waitlist error:", err);
    return json(500, { success: false, message: "Something went wrong. Please try again." });
  }
}

async function join(event) {
  const raw = event.isBase64Encoded
    ? Buffer.from(event.body || "", "base64").toString()
    : event.body || "{}";
  const { email } = JSON.parse(raw);

  if (!email || typeof email !== "string" || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return json(400, { success: false, message: "Please enter a valid email address." });
  }

  const col = (await getDb()).collection(COLLECTION);
  const normalized = email.toLowerCase().trim();

  if (await col.findOne({ email: normalized })) {
    return json(200, { success: true, message: "You're already on the waitlist!" });
  }

  await col.insertOne({ email: normalized, created_at: new Date(), source: "landing_page" });
  return json(200, { success: true, message: "Successfully joined the waitlist!" });
}

async function list(event) {
  const token = event.headers?.["x-admin-token"];
  if (!token || token !== process.env.ADMIN_TOKEN) {
    return json(401, { success: false, message: "Unauthorized." });
  }
  const entries = await (await getDb())
    .collection(COLLECTION)
    .find()
    .sort({ created_at: -1 })
    .toArray();
  return json(200, { success: true, entries });
}
