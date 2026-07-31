"use client";

import { useState } from "react";
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

function toLocalIso(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

const MONTHS_LONG = [
  "January","February","March","April","May","June",
  "July","August","September","October","November","December",
];

function ordinal(n: number) {
  const s = ["th", "st", "nd", "rd"];
  const v = n % 100;
  return `${n}${s[(v - 20) % 10] ?? s[v] ?? s[0]}`;
}

function formatTooltip(dateStr: string, count: number) {
  const [year, month, day] = dateStr.split("-").map(Number);
  const label = `${MONTHS_LONG[month - 1]} ${ordinal(day)}, ${year}`;
  return count === 0
    ? `No sessions on ${label}`
    : `${count} session${count !== 1 ? "s" : ""} on ${label}`;
}

export function CookingHeatmap({ data }: { data: HeatmapPoint[] }) {
  const [tooltip, setTooltip] = useState<{ text: string; x: number; y: number } | null>(null);

  const countMap = Object.fromEntries(data.map((d) => [d.date, d.count]));

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  // Start on the Sunday at or before (today − 364 days), so every column = Sun–Sat
  const rangeStart = new Date(today);
  rangeStart.setDate(rangeStart.getDate() - 364);
  rangeStart.setDate(rangeStart.getDate() - rangeStart.getDay());

  // Pad the last column out to Saturday
  const rangeEnd = new Date(today);
  rangeEnd.setDate(rangeEnd.getDate() + (6 - today.getDay()));

  type Cell = { date: string; count: number; isFuture: boolean };
  const allCells: Cell[] = [];
  const cursor = new Date(rangeStart);
  while (cursor <= rangeEnd) {
    const iso = toLocalIso(cursor);
    allCells.push({ date: iso, count: countMap[iso] ?? 0, isFuture: cursor > today });
    cursor.setDate(cursor.getDate() + 1);
  }

  // 7-day columns, each starting on Sunday
  const weeks: Cell[][] = [];
  for (let i = 0; i < allCells.length; i += 7) {
    weeks.push(allCells.slice(i, i + 7));
  }

  // Month labels: skip the partial first month (rangeStart is usually mid-month),
  // and enforce a minimum 3-column gap so adjacent labels never squish.
  const MONTHS = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
  const monthLabels: { label: string; col: number }[] = [];
  let prevMonth = -1;
  let prevLabelCol = -100;

  weeks.forEach((week, wi) => {
    const first = week.find((c) => !c.isFuture);
    if (!first) return;
    const month = parseInt(first.date.slice(5, 7), 10) - 1;
    const dom   = parseInt(first.date.slice(8, 10), 10);
    if (month === prevMonth) return;

    if (wi === 0 && dom > 1) {
      // First column is a partial month — skip its label so the next full month
      // starts cleanly (avoids "Jul Aug" squished in the top-left corner).
      prevMonth = month;
    } else if (wi - prevLabelCol >= 3) {
      monthLabels.push({ label: MONTHS[month], col: wi });
      prevMonth = month;
      prevLabelCol = wi;
    } else {
      prevMonth = month; // too close — track month change but skip the label
    }
  });

  // w-3 = 12 px, gap-0.5 = 2 px → 14 px per column
  const stride = 14;

  // Row indices for Mon (1), Wed (3), Fri (5) — Sunday is index 0
  const DAY_LABELS: (string | null)[] = [null, "Mon", null, "Wed", null, "Fri", null];

  return (
    <div className="flex gap-2">
      {/* Fixed day-of-week labels (Mon/Wed/Fri), offset by the 14px month-label row above */}
      <div className="flex flex-col shrink-0" style={{ marginTop: 16, gap: 2 }}>
        {DAY_LABELS.map((label, i) => (
          <div key={i} style={{ height: 12 }} className="flex items-center justify-end pr-1">
            {label && <span className="text-xs text-gray-400 leading-none">{label}</span>}
          </div>
        ))}
      </div>

      {/* Scrollable month-label row + grid */}
      <div className="overflow-x-auto flex-1 min-w-0">
        {/* Month labels pinned to their column position */}
        <div className="relative mb-0.5" style={{ height: 14, minWidth: weeks.length * stride }}>
          {monthLabels.map(({ label, col }) => (
            <span
              key={`${label}-${col}`}
              className="absolute text-xs text-gray-400 select-none"
              style={{ left: col * stride }}
            >
              {label}
            </span>
          ))}
        </div>
        {/* Grid */}
        <div className="flex gap-0.5 min-w-max">
          {weeks.map((week, wi) => (
            <div key={wi} className="flex flex-col gap-0.5">
              {week.map((cell, di) => (
                <div
                  key={di}
                  onMouseEnter={(e) => {
                    if (cell.isFuture) return;
                    const rect = e.currentTarget.getBoundingClientRect();
                    setTooltip({
                      text: formatTooltip(cell.date, cell.count),
                      x: rect.left + rect.width / 2,
                      y: rect.top - 6,
                    });
                  }}
                  onMouseLeave={() => setTooltip(null)}
                  className={`w-3 h-3 rounded-sm ${cell.isFuture ? "opacity-0 cursor-default" : "cursor-default " + heatColor(cell.count)}`}
                />
              ))}
            </div>
          ))}
        </div>
      </div>

      {/* Tooltip — rendered in fixed space so it's never clipped by the scroll container */}
      {tooltip && (
        <div
          className="fixed z-50 pointer-events-none -translate-x-1/2 -translate-y-full"
          style={{ left: tooltip.x, top: tooltip.y }}
        >
          <div className="bg-gray-900 text-white text-xs rounded px-2 py-1 shadow-lg whitespace-nowrap">
            {tooltip.text}
          </div>
          <div className="mx-auto w-0 h-0 border-x-4 border-x-transparent border-t-4 border-t-gray-900" />
        </div>
      )}
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
