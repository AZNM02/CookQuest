import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase-server";
import AppShell from "@/components/AppShell";
import ProfileClient from "./ProfileClient";

const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

export default async function ProfilePage() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const {
    data: { session },
  } = await supabase.auth.getSession();
  const token = session?.access_token ?? "";
  const headers = { Authorization: `Bearer ${token}` };

  const [dashRes, chartsRes, badgesRes, sessionsRes] = await Promise.allSettled([
    fetch(`${API_URL}/stats/dashboard`, { headers, cache: "no-store" }),
    fetch(`${API_URL}/stats/charts`, { headers, cache: "no-store" }),
    fetch(`${API_URL}/profile/badges`, { headers, cache: "no-store" }),
    fetch(`${API_URL}/sessions?limit=100`, { headers, cache: "no-store" }),
  ]);

  const dashboard =
    dashRes.status === "fulfilled" && dashRes.value.ok
      ? await dashRes.value.json()
      : null;

  const charts =
    chartsRes.status === "fulfilled" && chartsRes.value.ok
      ? await chartsRes.value.json()
      : null;

  const badges =
    badgesRes.status === "fulfilled" && badgesRes.value.ok
      ? await badgesRes.value.json()
      : [];

  const sessions =
    sessionsRes.status === "fulfilled" && sessionsRes.value.ok
      ? await sessionsRes.value.json()
      : [];

  return (
    <AppShell username={user.email ?? ""}>
      <div className="p-8 max-w-4xl mx-auto">
        <div className="mb-8">
          <h1 className="text-2xl font-bold text-gray-900">Profile</h1>
          <p className="text-sm text-gray-500 mt-1">Your cooking journey at a glance.</p>
        </div>
        <ProfileClient
          dashboard={dashboard}
          xpOverTime={charts?.xp_over_time ?? []}
          badges={badges}
          sessions={sessions}
        />
      </div>
    </AppShell>
  );
}
