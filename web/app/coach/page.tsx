import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase-server";
import AppShell from "@/components/AppShell";
import CoachChat from "./CoachChat";

const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

export default async function CoachPage() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const {
    data: { session },
  } = await supabase.auth.getSession();
  const token = session?.access_token ?? "";

  // Fetch recipes for the recipe selector
  let recipes: { id: number; name: string; description: string | null; instructions: string | null }[] = [];
  try {
    const res = await fetch(`${API_URL}/recipes`, { cache: "no-store" });
    if (res.ok) recipes = await res.json();
  } catch {
    // backend offline — coach still works without recipe selector
  }

  return (
    <AppShell username={user.email ?? ""}>
      <CoachChat token={token} recipes={recipes} />
    </AppShell>
  );
}
