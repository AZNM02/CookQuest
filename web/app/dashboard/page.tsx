import { redirect } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase-server";
import { apiRequest } from "@/lib/api";
import AppShell from "@/components/AppShell";

const LEVEL_NAMES: Record<number, string> = {
  1: "Novice Cook",
  2: "Home Chef",
  3: "Skilled Chef",
  4: "Advanced Chef",
  5: "Master Chef",
};
function getLevelName(level: number) {
  return LEVEL_NAMES[level] ?? `Grand Master`;
}

const CUISINE_LABELS: Record<string, string> = {
  asian: "Asian",
  western: "Western",
  mediterranean: "Mediterranean",
  middle_eastern: "Middle Eastern",
  other: "Other",
};

const CUISINE_EMOJI: Record<string, string> = {
  asian: "🍜",
  western: "🥩",
  mediterranean: "🫒",
  middle_eastern: "🥙",
  other: "🍽",
};

type DashboardData = {
  profile: {
    username: string;
    display_name: string | null;
    xp: number;
    level: number;
    streak_count: number;
  };
  recent_sessions: Array<{
    id: string;
    dish_name: string;
    cuisine_type: string;
    date: string;
    self_rating: number;
    xp_earned: number;
  }>;
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

export default async function DashboardPage() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const {
    data: { session },
  } = await supabase.auth.getSession();
  const token = session?.access_token ?? "";

  let data: DashboardData | null = null;
  let apiError = false;

  try {
    data = await apiRequest<DashboardData>("/stats/dashboard", { token });
  } catch {
    apiError = true;
  }

  const displayName =
    data?.profile.display_name ?? data?.profile.username ?? user.email ?? "";

  const xp = data?.xp_progress.current_xp ?? 0;
  const level = data?.xp_progress.level ?? 1;
  const xpForCurrent = data?.xp_progress.xp_for_current_level ?? 0;
  const xpForNext = data?.xp_progress.xp_for_next_level ?? 250;
  const progressPct = Math.min(
    100,
    Math.round(((xp - xpForCurrent) / (xpForNext - xpForCurrent)) * 100)
  );

  return (
    <AppShell username={displayName}>
      <div className="p-8 max-w-4xl mx-auto">
        {/* Header */}
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">
              Welcome back, {displayName.split(" ")[0]}! 👋
            </h1>
            <p className="text-gray-500 text-sm mt-0.5">
              {data?.stats.total_sessions === 0
                ? "Log your first session to get started."
                : `${data?.stats.total_sessions} sessions logged so far.`}
            </p>
          </div>
          <Link
            href="/log"
            className="inline-flex items-center gap-2 rounded-lg bg-orange-500 px-4 py-2.5 text-sm font-semibold text-white hover:bg-orange-600 transition-colors"
          >
            <span>+</span> Log Session
          </Link>
        </div>

        {apiError && (
          <div className="mb-6 rounded-lg bg-amber-50 border border-amber-200 px-4 py-3 text-sm text-amber-700">
            Could not reach the backend. Start FastAPI with{" "}
            <code className="font-mono bg-amber-100 px-1 rounded">
              uvicorn main:app --reload
            </code>{" "}
            then refresh.
          </div>
        )}

        {/* XP Bar */}
        <div className="mb-6 rounded-2xl bg-white border border-gray-100 p-5 shadow-sm">
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-3">
              <span className="inline-flex items-center justify-center w-9 h-9 rounded-full bg-orange-100 text-orange-600 font-bold text-sm">
                {level}
              </span>
              <div>
                <p className="font-semibold text-gray-900">{getLevelName(level)}</p>
                <p className="text-xs text-gray-400">Level {level}</p>
              </div>
            </div>
            <p className="text-sm text-gray-500">
              <span className="font-semibold text-gray-700">{xp.toLocaleString()}</span>
              {" / "}
              <span>{xpForNext.toLocaleString()} XP</span>
            </p>
          </div>
          <div className="h-3 w-full rounded-full bg-gray-100 overflow-hidden">
            <div
              className="h-full rounded-full bg-gradient-to-r from-orange-400 to-orange-500 transition-all"
              style={{ width: `${progressPct}%` }}
            />
          </div>
          <p className="text-xs text-gray-400 mt-1.5 text-right">
            {xpForNext - xp} XP to Level {level + 1}
          </p>
        </div>

        {/* Stat Cards */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-6">
          {[
            {
              icon: "🔥",
              value: data?.profile.streak_count ?? 0,
              label: "Day Streak",
              sub: `Best: ${data?.stats.longest_streak ?? 0}`,
            },
            {
              icon: "🍽",
              value: data?.stats.total_sessions ?? 0,
              label: "Sessions",
              sub: "all time",
            },
            {
              icon: "🥄",
              value: data?.stats.unique_techniques ?? 0,
              label: "Techniques",
              sub: "used",
            },
            {
              icon: "🌍",
              value: data?.stats.cuisine_count ?? 0,
              label: "Cuisines",
              sub: "explored",
            },
          ].map((card) => (
            <div
              key={card.label}
              className="rounded-2xl bg-white border border-gray-100 p-4 shadow-sm text-center"
            >
              <div className="text-2xl mb-1">{card.icon}</div>
              <div className="text-2xl font-bold text-gray-900">{card.value}</div>
              <div className="text-xs font-medium text-gray-700">{card.label}</div>
              <div className="text-xs text-gray-400">{card.sub}</div>
            </div>
          ))}
        </div>

        {/* Recent Sessions */}
        <div className="rounded-2xl bg-white border border-gray-100 shadow-sm overflow-hidden">
          <div className="px-5 py-4 border-b border-gray-100 flex items-center justify-between">
            <h2 className="font-semibold text-gray-900">Recent Sessions</h2>
            <Link
              href="/log"
              className="text-xs text-orange-600 hover:text-orange-500 font-medium"
            >
              + New
            </Link>
          </div>

          {!data?.recent_sessions.length ? (
            <div className="px-5 py-10 text-center">
              <p className="text-gray-400 text-sm">No sessions yet.</p>
              <Link
                href="/log"
                className="mt-3 inline-block text-sm font-medium text-orange-600 hover:text-orange-500"
              >
                Log your first cook →
              </Link>
            </div>
          ) : (
            <ul className="divide-y divide-gray-50">
              {data.recent_sessions.map((s) => (
                <li
                  key={s.id}
                  className="flex items-center justify-between px-5 py-3.5 hover:bg-gray-50 transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <span className="text-xl">
                      {CUISINE_EMOJI[s.cuisine_type] ?? "🍽"}
                    </span>
                    <div>
                      <p className="text-sm font-medium text-gray-900">
                        {s.dish_name}
                      </p>
                      <p className="text-xs text-gray-400">
                        {CUISINE_LABELS[s.cuisine_type] ?? s.cuisine_type} ·{" "}
                        {new Date(s.date).toLocaleDateString("en-US", {
                          month: "short",
                          day: "numeric",
                        })}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center gap-3 text-right">
                    <div className="flex">
                      {Array.from({ length: 5 }).map((_, i) => (
                        <span
                          key={i}
                          className={
                            i < s.self_rating
                              ? "text-orange-400"
                              : "text-gray-200"
                          }
                        >
                          ★
                        </span>
                      ))}
                    </div>
                    <span className="text-xs font-semibold text-orange-600 bg-orange-50 px-2 py-0.5 rounded-full">
                      +{s.xp_earned} XP
                    </span>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </AppShell>
  );
}
