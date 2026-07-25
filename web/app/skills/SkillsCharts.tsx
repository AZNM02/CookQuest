"use client";

import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  RadarChart,
  PolarGrid,
  PolarAngleAxis,
  Radar,
  ResponsiveContainer,
  Cell,
} from "recharts";

type TechniqueProficiency = {
  id: number;
  name: string;
  category: string;
  difficulty_tier: string;
  times_used: number;
  avg_rating: number;
  last_used: string | null;
  proficiency_score: number;
};

type CuisineRadarPoint = { cuisine: string; count: number };
type HeatmapPoint = { date: string; count: number };

const CATEGORY_COLORS: Record<string, string> = {
  knife_skills: "#f97316",
  heat_control: "#ef4444",
  sauces: "#8b5cf6",
  baking: "#f59e0b",
  prep: "#10b981",
};

const CUISINE_LABELS: Record<string, string> = {
  asian: "Asian",
  western: "Western",
  mediterranean: "Mediterranean",
  middle_eastern: "Middle Eastern",
  other: "Other",
};

function scoreColor(score: number) {
  if (score === 0) return "bg-gray-100 text-gray-400";
  if (score < 30) return "bg-red-50 text-red-500";
  if (score < 60) return "bg-yellow-50 text-yellow-600";
  return "bg-green-50 text-green-600";
}

// ── Proficiency bar chart ─────────────────────────────────────────────────────
export function ProficiencyChart({ data }: { data: TechniqueProficiency[] }) {
  const chartData = data
    .filter((t) => t.times_used > 0)
    .sort((a, b) => b.proficiency_score - a.proficiency_score)
    .slice(0, 15)
    .map((t) => ({
      name: t.name.length > 14 ? t.name.slice(0, 13) + "…" : t.name,
      score: t.proficiency_score,
      category: t.category,
    }));

  if (chartData.length === 0) {
    return (
      <div className="flex items-center justify-center h-48 text-sm text-gray-400">
        Log sessions to see your proficiency chart.
      </div>
    );
  }

  return (
    <ResponsiveContainer width="100%" height={260}>
      <BarChart data={chartData} layout="vertical" margin={{ left: 8, right: 16 }}>
        <XAxis type="number" domain={[0, 100]} tick={{ fontSize: 11 }} />
        <YAxis type="category" dataKey="name" width={110} tick={{ fontSize: 11 }} />
        <Tooltip
          formatter={(v) => [`${v ?? 0}`, "Score"]}
          contentStyle={{ fontSize: 12 }}
        />
        <Bar dataKey="score" radius={[0, 4, 4, 0]}>
          {chartData.map((entry, i) => (
            <Cell key={i} fill={CATEGORY_COLORS[entry.category] ?? "#94a3b8"} />
          ))}
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  );
}

// ── Cuisine radar chart ───────────────────────────────────────────────────────
export function CuisineRadar({ data }: { data: CuisineRadarPoint[] }) {
  const radarData = data.map((d) => ({
    ...d,
    cuisine: CUISINE_LABELS[d.cuisine] ?? d.cuisine,
  }));
  const hasData = data.some((d) => d.count > 0);

  if (!hasData) {
    return (
      <div className="flex items-center justify-center h-48 text-sm text-gray-400">
        Cook dishes from different cuisines to see the radar.
      </div>
    );
  }

  return (
    <ResponsiveContainer width="100%" height={220}>
      <RadarChart data={radarData}>
        <PolarGrid />
        <PolarAngleAxis dataKey="cuisine" tick={{ fontSize: 11 }} />
        <Radar
          dataKey="count"
          stroke="#f97316"
          fill="#f97316"
          fillOpacity={0.3}
        />
        <Tooltip formatter={(v) => [Number(v ?? 0), "Sessions"]} contentStyle={{ fontSize: 12 }} />
      </RadarChart>
    </ResponsiveContainer>
  );
}

// ── Cooking heatmap ───────────────────────────────────────────────────────────
function heatColor(count: number) {
  if (count === 0) return "bg-gray-100";
  if (count === 1) return "bg-orange-200";
  if (count === 2) return "bg-orange-400";
  return "bg-orange-600";
}

export function CookingHeatmap({ data }: { data: HeatmapPoint[] }) {
  // Build a map of date → count for the last 52 weeks
  const countMap = Object.fromEntries(data.map((d) => [d.date, d.count]));

  const today = new Date();
  const cells: { date: string; count: number }[] = [];

  // Go back 364 days (52 weeks × 7)
  for (let i = 363; i >= 0; i--) {
    const d = new Date(today);
    d.setDate(d.getDate() - i);
    const iso = d.toISOString().slice(0, 10);
    cells.push({ date: iso, count: countMap[iso] ?? 0 });
  }

  // Split into weeks (columns of 7 days)
  const weeks: { date: string; count: number }[][] = [];
  for (let i = 0; i < cells.length; i += 7) {
    weeks.push(cells.slice(i, i + 7));
  }

  const MONTHS = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];

  return (
    <div className="overflow-x-auto">
      <div className="flex gap-0.5 min-w-max">
        {weeks.map((week, wi) => (
          <div key={wi} className="flex flex-col gap-0.5">
            {week.map((cell) => (
              <div
                key={cell.date}
                title={`${cell.date}: ${cell.count} session${cell.count !== 1 ? "s" : ""}`}
                className={`w-3 h-3 rounded-sm ${heatColor(cell.count)}`}
              />
            ))}
          </div>
        ))}
      </div>
      <div className="flex justify-between mt-1 text-xs text-gray-400">
        {MONTHS.map((m) => <span key={m}>{m}</span>)}
      </div>
    </div>
  );
}

// ── Technique list ────────────────────────────────────────────────────────────
export function TechniqueList({ data }: { data: TechniqueProficiency[] }) {
  const DIFF_LABELS: Record<string, string> = {
    beginner: "Beginner",
    intermediate: "Intermediate",
    advanced: "Advanced",
  };

  return (
    <div className="space-y-2">
      {data.map((t) => (
        <div
          key={t.id}
          className="flex items-center gap-3 rounded-lg border border-gray-100 bg-white px-4 py-3"
        >
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <span className="text-sm font-medium text-gray-800">{t.name}</span>
              <span
                className="text-xs px-1.5 py-0.5 rounded-full"
                style={{
                  backgroundColor: (CATEGORY_COLORS[t.category] ?? "#94a3b8") + "20",
                  color: CATEGORY_COLORS[t.category] ?? "#94a3b8",
                }}
              >
                {t.category.replace("_", " ")}
              </span>
            </div>
            <div className="flex items-center gap-3 mt-1">
              <div className="flex-1 h-1.5 bg-gray-100 rounded-full overflow-hidden">
                <div
                  className="h-full bg-orange-400 rounded-full transition-all"
                  style={{ width: `${t.proficiency_score}%` }}
                />
              </div>
              <span className="text-xs text-gray-400 w-8 text-right">
                {t.proficiency_score > 0 ? t.proficiency_score : "—"}
              </span>
            </div>
          </div>
          <span
            className={`text-xs px-2 py-1 rounded-full font-medium shrink-0 ${scoreColor(t.proficiency_score)}`}
          >
            {t.times_used === 0 ? "New" : `×${t.times_used}`}
          </span>
        </div>
      ))}
    </div>
  );
}
