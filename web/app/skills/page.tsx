import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase-server";
import AppShell from "@/components/AppShell";
import {
  ProficiencyChart,
  CuisineRadar,
  CookingHeatmap,
  TechniqueList,
} from "./SkillsCharts";

const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

async function fetchWithToken<T>(path: string, token: string): Promise<T | null> {
  try {
    const res = await fetch(`${API_URL}${path}`, {
      headers: { Authorization: `Bearer ${token}` },
      cache: "no-store",
    });
    if (!res.ok) return null;
    return res.json();
  } catch {
    return null;
  }
}

export default async function SkillsPage() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const {
    data: { session },
  } = await supabase.auth.getSession();
  const token = session?.access_token ?? "";

  const [proficiency, charts] = await Promise.all([
    fetchWithToken<{ id: number; name: string; category: string; difficulty_tier: string; times_used: number; avg_rating: number; last_used: string | null; proficiency_score: number }[]>(
      "/techniques/proficiency",
      token
    ),
    fetchWithToken<{
      cuisine_radar: { cuisine: string; count: number }[];
      heatmap: { date: string; count: number }[];
      xp_over_time: { date: string; xp: number }[];
    }>("/stats/charts", token),
  ]);

  const sortedByGap = proficiency
    ? [...proficiency].sort((a, b) => a.proficiency_score - b.proficiency_score)
    : [];

  const tried = proficiency ? proficiency.filter((t) => t.times_used > 0).length : 0;
  const total = proficiency ? proficiency.length : 0;

  return (
    <AppShell username={user.email ?? ""}>
      <div className="p-8 max-w-5xl mx-auto space-y-8">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Skills</h1>
          <p className="text-sm text-gray-500 mt-1">
            {tried} of {total} techniques tried
          </p>
        </div>

        {/* Proficiency bar chart */}
        <section className="rounded-2xl bg-white border border-gray-100 shadow-sm p-6">
          <h2 className="text-base font-semibold text-gray-800 mb-4">
            Proficiency by Technique
          </h2>
          {proficiency ? (
            <ProficiencyChart data={proficiency} />
          ) : (
            <p className="text-sm text-gray-400">Could not load data.</p>
          )}
          {/* Legend */}
          <div className="flex flex-wrap gap-3 mt-4">
            {[
              ["knife_skills", "#f97316", "Knife Skills"],
              ["heat_control", "#ef4444", "Heat Control"],
              ["sauces", "#8b5cf6", "Sauces"],
              ["baking", "#f59e0b", "Baking"],
              ["prep", "#10b981", "Prep"],
            ].map(([, color, label]) => (
              <div key={label} className="flex items-center gap-1.5 text-xs text-gray-500">
                <div className="w-3 h-3 rounded-sm" style={{ backgroundColor: color }} />
                {label}
              </div>
            ))}
          </div>
        </section>

        {/* Cuisine radar + heatmap side by side */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <section className="rounded-2xl bg-white border border-gray-100 shadow-sm p-6">
            <h2 className="text-base font-semibold text-gray-800 mb-4">
              Cuisine Diversity
            </h2>
            {charts ? (
              <CuisineRadar data={charts.cuisine_radar} />
            ) : (
              <p className="text-sm text-gray-400">Could not load data.</p>
            )}
          </section>

          <section className="rounded-2xl bg-white border border-gray-100 shadow-sm p-6">
            <h2 className="text-base font-semibold text-gray-800 mb-4">
              Cooking Activity
            </h2>
            {charts ? (
              <CookingHeatmap data={charts.heatmap} />
            ) : (
              <p className="text-sm text-gray-400">Could not load data.</p>
            )}
            <div className="flex items-center gap-2 mt-3 text-xs text-gray-400">
              <span>Less</span>
              <div className="w-3 h-3 rounded-sm bg-gray-100" />
              <div className="w-3 h-3 rounded-sm bg-orange-200" />
              <div className="w-3 h-3 rounded-sm bg-orange-400" />
              <div className="w-3 h-3 rounded-sm bg-orange-600" />
              <span>More</span>
            </div>
          </section>
        </div>

        {/* Full technique list sorted by gap */}
        <section className="rounded-2xl bg-white border border-gray-100 shadow-sm p-6">
          <h2 className="text-base font-semibold text-gray-800 mb-4">
            All Techniques{" "}
            <span className="text-gray-400 font-normal text-sm">
              — weakest first
            </span>
          </h2>
          {sortedByGap.length > 0 ? (
            <TechniqueList data={sortedByGap} />
          ) : (
            <p className="text-sm text-gray-400">No technique data yet.</p>
          )}
        </section>
      </div>
    </AppShell>
  );
}
