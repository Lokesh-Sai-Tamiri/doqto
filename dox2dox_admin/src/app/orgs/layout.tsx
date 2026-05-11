import { requireToken } from "@/lib/auth";
import { Sidebar } from "@/components/sidebar";

export default async function OrgsLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  await requireToken();
  return (
    <div className="flex min-h-screen">
      <Sidebar />
      <div className="flex-1">{children}</div>
    </div>
  );
}
