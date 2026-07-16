import { redirect } from "next/navigation";

import { readToken } from "@/lib/auth";

export default async function IndexPage() {
  const token = await readToken();
  redirect(token ? "/orgs" : "/login");
}
