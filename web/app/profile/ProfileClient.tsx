"use client";

import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from "recharts";

type ProfileData = {
  id: string;
  username: string;
  display_name: string | null;
  xp: number;
  level: number;
  streak_count: number;
  longest_streak: number;
  last_cooked_date: string | null;
  created_at: string;
};

type DashboardData = {
  profile: ProfileData;
  stats: {
    total_sessions: number;
    unique_techniques: number;
    cuisine_count: number;
    longest_streak: number;
  };
  xp_progress: {
    current_xp: number;
    level: number;
    xp_for_current_level: number;
    xp_for_next_level: number;
  };
};

type Badge = {
  name: string;
  icon: string;
  description: string;
  earned_at: string;
};

type Session = {
  id: string;
  dish_name: string;
  cuisine_type: string;
  date: string;
  self_rating: number;
  xp_earned: number;
};

type XpPoint = { date: string; xp: number };

const CUISINE_LABELS: Record<string, string> = {
  asian: "Asian",
  western: "Western",
  mediterranean: "Mediterranean",
  middle_eastern: "Middle Eastern",
  other: "Other",
};

function fmtShort(dateStr: string): string {
  const d = new Date(dateStr + "T00:00:00");
  return d.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

function fmtFull(dateStr: string): string {
  const d = new Date(dateStr + "T00:00:00");
  return d.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
}

function initials(name: string): string {
  return name
    .split(/[\s_]+/)
    .map((w) => w[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();
}

export default function ProfileClient({
  dashboard,
  xpOverTime,
  badges,
  sessions,
}: {
  dashboard: DashboardData | null;
  xpOverTime: XpPoint[];
  badges: Badge[];
  sessions: Session[];
}) {
  if (!dashboard) {
    return <p className="text-gray-500 text-sm">Unable to load profile data.</p>;
  }

  const { profile, stats, xp_progress } = dashboard;
  const displayName = profile.display_name || profile.username;
  const xpInLevel = xp_progress.current_xp - xp_progress.xp_for_current_level;
  const xpNeeded = xp_progress.xp_for_next_level - xp_progress.xp_for_current_level;
  const progressPct =
    xpNeeded > 0 ? Math.min(100, Math.round((xpInLevel / xpNeeded) * 100)) : 100;
  const joined = new Date(profile.created_at).toLocaleDateString("en-US", {
    month: "long",
    year: "numeric",
  });

  return (
    <div className="space-y-6">
      {/* Profile header */}
      <div className="bg-white rounded-2xl border border-gray-100 p-6 flex items-start gap-5">
        <div className="w-16 h-16 rounded-2xl bg-orange-100 text-orange-600 flex items-center justify-center text-xl font-bold shrink-0 select-none">
          {initials(displayName)}
        </div>

        <div className="flex-1 min-w-0">
          <h2 className="text-xl font-bold text-gray-900">{displayName}</h2>
          <p className="text-sm text-gray-400 mt-0.5">
            @{profile.username} · Joined {joined}
          </p>

          {/* XP progress */}
          <div className="mt-4">
            <div className="flex items-center justify-between mb-1.5">
              <span className="text-sm font-semibold text-gray-700">
                Level {xp_progress.level}
              </span>
              <span className="text-xs text-gray-400">
                {xpInLevel.toLocaleString()} / {xpNeeded.toLocaleString()} XP to next level
              </span>
            </div>
            <div className="h-2.5 bg-gray-100 rounded-full overflow-hidden">
              <div
                className="h-full bg-gradient-to-r from-orange-400 to-amber-400 rounded-full transition-all"
                style={{ width: `${progressPct}%` }}
              />
            </div>
            <p className="text-xs text-gray-400 mt-1">
              {xp_progress.current_xp.toLocaleString()} total XP
            </p>
          </div>
        </div>

        {/* Streak */}
        <div className="text-right shrink-0">
          <p className="text-2xl font-bold text-orange-500">🔥 {profile.streak_count}</p>
          <p className="text-xs text-gray-400">day streak</p>
          <p className="text-xs text-gray-400 mt-1.5">
            Best: {profile.longest_streak} days
          </p>
        </div>
      </div>

      {/* Stats row */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        {[
          { label: "Sessions Cooked", value: stats.total_sessions, icon: "🍳" },
          { label: "Techniques Used", value: stats.unique_techniques, icon: "🔪" },
          { label: "Cuisines Explored", value: stats.cuisine_count, icon: "🌍" },
          { label: "Longest Streak", value: `${stats.longest_streak}d`, icon: "🏆" },
        ].map((s) => (
          <div
            key={s.label}
            className="bg-white rounded-2xl border border-gray-100 p-4 text-center"
          >
            <p className="text-2xl mb-1">{s.icon}</p>
            <p className="text-xl font-bold text-gray-900">{s.value}</p>
            <p className="text-xs text-gray-400 mt-0.5">{s.label}</p>
          </div>
        ))}
      </div>

      {/* XP Over Time chart */}
      {xpOverTime.length > 0 && (
        <div className="bg-white rounded-2xl border border-gray-100 p-6">
          <h2 className="text-sm font-semibold text-gray-700 mb-5">XP Over Time</h2>
          <ResponsiveContainer width="100%" height={200}>
            <AreaChart data={xpOverTime} margin={{ top: 5, right: 10, left: 0, bottom: 5 }}>
              <defs>
                <linearGradient id="xpGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#f97316" stopOpacity={0.25} />
                  <stop offset="95%" stopColor="#f97316" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#f3f4f6" />
              <XAxis
                dataKey="date"
                tickFormatter={fmtShort}
                tick={{ fontSize: 11, fill: "#9ca3af" }}
                tickLine={false}
                axisLine={false}
                interval="preserveStartEnd"
              />
              <YAxis
                tick={{ fontSize: 11, fill: "#9ca3af" }}
                tickLine={false}
                axisLine={false}
                width={45}
                tickFormatter={(v) => v.toLocaleString()}
              />
              <Tooltip
                formatter={(v) => [`${Number(v ?? 0).toLocaleString()} XP`, ""]}
                labelFormatter={(l) => fmtFull(String(l))}
                contentStyle={{
                  borderRadius: "8px",
                  border: "1px solid #e5e7eb",
                  fontSize: "12px",
                }}
              />
              <Area
                type="monotone"
                dataKey="xp"
                stroke="#f97316"
                strokeWidth={2}
                fill="url(#xpGrad)"
                dot={false}
                activeDot={{ r: 4, fill: "#f97316" }}
              />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      )}

      {/* Badges */}
      <div className="bg-white rounded-2xl border border-gray-100 p-6">
        <h2 className="text-sm font-semibold text-gray-700 mb-4">
          Badges
          {badges.length > 0 && (
            <span className="ml-2 text-xs text-orange-600 bg-orange-50 px-2 py-0.5 rounded-full font-medium border border-orange-100">
              {badges.length} earned
            </span>
          )}
        </h2>
        {badges.length === 0 ? (
          <p className="text-sm text-gray-400">No badges yet — keep cooking to unlock them!</p>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
            {badges.map((b) => (
              <div
                key={b.name}
                className="flex items-start gap-3 p-3 rounded-xl bg-orange-50 border border-orange-100"
              >
                <span className="text-2xl shrink-0">{b.icon}</span>
                <div className="min-w-0">
                  <p className="text-sm font-semibold text-gray-800 leading-snug">{b.name}</p>
                  <p className="text-xs text-gray-500 leading-relaxed mt-0.5">{b.description}</p>
                  <p className="text-xs text-orange-400 mt-1">
                    {fmtFull(b.earned_at.split("T")[0])}
                  </p>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Session History */}
      <div className="bg-white rounded-2xl border border-gray-100 p-6">
        <h2 className="text-sm font-semibold text-gray-700 mb-4">
          Session History
          <span className="ml-2 text-xs text-gray-400 font-normal">
            {sessions.length} sessions
          </span>
        </h2>
        {sessions.length === 0 ? (
          <p className="text-sm text-gray-400">No sessions yet — log your first cook!</p>
        ) : (
          <div className="divide-y divide-gray-50">
            {sessions.map((s) => (
              <div
                key={s.id}
                className="flex items-center gap-3 py-3 first:pt-0 last:pb-0"
              >
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-gray-800 truncate">{s.dish_name}</p>
                  <p className="text-xs text-gray-400 mt-0.5">
                    {CUISINE_LABELS[s.cuisine_type] ?? s.cuisine_type} · {fmtFull(s.date)}
                  </p>
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  <span className="text-xs text-yellow-500 tracking-tight">
                    {"★".repeat(s.self_rating)}
                    {"☆".repeat(5 - s.self_rating)}
                  </span>
                  <span className="text-xs px-2 py-0.5 rounded-full bg-orange-50 text-orange-600 font-medium border border-orange-100 whitespace-nowrap">
                    +{s.xp_earned} XP
                  </span>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
