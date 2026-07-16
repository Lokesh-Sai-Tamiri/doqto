import { redirect } from "next/navigation";

import { LoginForm } from "@/components/login-form";
import { Card } from "@/components/ui/card";
import { readToken } from "@/lib/auth";

export default async function LoginPage() {
  if (await readToken()) redirect("/orgs");

  return (
    <main className="flex flex-1 items-center justify-center px-4 py-16">
      <div className="w-full max-w-md">
        <div className="mb-8 text-center">
          <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-2xl bg-primary text-white text-2xl font-bold">
            D2D
          </div>
          <h1 className="text-2xl font-bold text-gray-900">Doqto Admin</h1>
          <p className="mt-1 text-sm text-gray-600">
            Platform administrators only.
          </p>
        </div>
        <Card>
          <LoginForm />
        </Card>
      </div>
    </main>
  );
}
