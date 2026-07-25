import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase-server";
import AppShell from "@/components/AppShell";
import RecipesClient from "./RecipesClient";

const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

export default async function RecipesPage() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const {
    data: { session },
  } = await supabase.auth.getSession();
  const token = session?.access_token ?? "";

  const [recipesRes, recsRes] = await Promise.allSettled([
    fetch(`${API_URL}/recipes`, { cache: "no-store" }),
    fetch(`${API_URL}/recommendations`, {
      headers: { Authorization: `Bearer ${token}` },
      cache: "no-store",
    }),
  ]);

  const recipes =
    recipesRes.status === "fulfilled" && recipesRes.value.ok
      ? await recipesRes.value.json()
      : [];

  const recommendations =
    recsRes.status === "fulfilled" && recsRes.value.ok
      ? await recsRes.value.json()
      : [];

  return (
    <AppShell username={user.email ?? ""}>
      <div className="p-8 max-w-5xl mx-auto">
        <div className="mb-8">
          <h1 className="text-2xl font-bold text-gray-900">Recipes</h1>
          <p className="text-sm text-gray-500 mt-1">
            Personalised picks and a full recipe library.
          </p>
        </div>
        <RecipesClient recipes={recipes} recommendations={recommendations} />
      </div>
    </AppShell>
  );
}
