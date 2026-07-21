"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { apiRequest } from "@/lib/api";
import { cn } from "@/lib/utils";

type Technique = {
  id: number;
  name: string;
  category: string;
  difficulty_tier: string;
  xp_reward: number;
};

type FormData = {
  dish_name: string;
  cuisine_type: string;
  technique_ids: number[];
  self_rating: number;
  difficulty_felt: number;
  time_taken_mins: string;
  notes: string;
};

type LogResult = {
  xp_earned: number;
  new_total_xp: number;
  new_level: number;
  leveled_up: boolean;
};

const CUISINES = [
  { value: "asian", label: "Asian" },
  { value: "western", label: "Western" },
  { value: "mediterranean", label: "Mediterranean" },
  { value: "middle_eastern", label: "Middle Eastern" },
  { value: "other", label: "Other" },
];

const CATEGORY_LABELS: Record<string, string> = {
  knife_skills: "Knife Skills",
  heat_control: "Heat Control",
  sauces: "Sauces",
  baking: "Baking",
  prep: "Prep",
};

const STEPS = ["Dish", "Techniques", "Rating", "Details"];

function StarRating({
  value,
  onChange,
  label,
}: {
  value: number;
  onChange: (v: number) => void;
  label: string;
}) {
  const [hovered, setHovered] = useState(0);
  return (
    <div>
      <p className="text-sm font-medium text-gray-700 mb-2">{label}</p>
      <div className="flex gap-1">
        {[1, 2, 3, 4, 5].map((star) => (
          <button
            key={star}
            type="button"
            onClick={() => onChange(star)}
            onMouseEnter={() => setHovered(star)}
            onMouseLeave={() => setHovered(0)}
            className="text-3xl transition-transform hover:scale-110 focus:outline-none"
          >
            <span
              className={
                star <= (hovered || value)
                  ? "text-orange-400"
                  : "text-gray-200"
              }
            >
              ★
            </span>
          </button>
        ))}
      </div>
      {value > 0 && (
        <p className="text-xs text-gray-400 mt-1">
          {["", "Poor", "Fair", "Good", "Great", "Excellent"][value]}
        </p>
      )}
    </div>
  );
}

export default function LogForm({ token }: { token: string }) {
  const router = useRouter();
  const [step, setStep] = useState(0);
  const [techniques, setTechniques] = useState<Technique[]>([]);
  const [techSearch, setTechSearch] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [result, setResult] = useState<LogResult | null>(null);

  const [form, setForm] = useState<FormData>({
    dish_name: "",
    cuisine_type: "",
    technique_ids: [],
    self_rating: 0,
    difficulty_felt: 0,
    time_taken_mins: "",
    notes: "",
  });

  useEffect(() => {
    apiRequest<Technique[]>("/techniques").catch(() => []).then(setTechniques);
  }, []);

  const grouped = techniques
    .filter((t) =>
      t.name.toLowerCase().includes(techSearch.toLowerCase())
    )
    .reduce<Record<string, Technique[]>>((acc, t) => {
      (acc[t.category] = acc[t.category] ?? []).push(t);
      return acc;
    }, {});

  function toggleTechnique(id: number) {
    setForm((f) => ({
      ...f,
      technique_ids: f.technique_ids.includes(id)
        ? f.technique_ids.filter((x) => x !== id)
        : [...f.technique_ids, id],
    }));
  }

  async function handleSubmit() {
    setError("");
    setLoading(true);
    try {
      const body = {
        dish_name: form.dish_name,
        cuisine_type: form.cuisine_type,
        technique_ids: form.technique_ids,
        self_rating: form.self_rating,
        difficulty_felt: form.difficulty_felt,
        time_taken_mins: form.time_taken_mins
          ? parseInt(form.time_taken_mins)
          : null,
        notes: form.notes || null,
      };

      const res = await apiRequest<{ xp_earned: number; new_total_xp: number; new_level: number; leveled_up: boolean }>(
        "/sessions/log",
        { method: "POST", body: JSON.stringify(body), token }
      );
      setResult(res);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed to log session");
    } finally {
      setLoading(false);
    }
  }

  // ── Success screen ────────────────────────────────────────────────────────
  if (result) {
    return (
      <div className="p-8 max-w-lg mx-auto text-center">
        <div className="rounded-2xl bg-white border border-gray-100 shadow-sm p-10">
          <div className="text-6xl mb-4">🎉</div>
          <h2 className="text-2xl font-bold text-gray-900 mb-2">
            Session logged!
          </h2>
          <div className="inline-flex items-center gap-2 bg-orange-50 text-orange-600 rounded-full px-5 py-2 text-xl font-bold mb-6">
            +{result.xp_earned} XP
          </div>
          {result.leveled_up && (
            <p className="text-sm text-purple-600 font-semibold mb-4 bg-purple-50 rounded-lg px-4 py-2">
              ⭐ Level up! You are now Level {result.new_level}
            </p>
          )}
          <p className="text-sm text-gray-500 mb-8">
            Total XP: {result.new_total_xp.toLocaleString()}
          </p>
          <div className="flex gap-3 justify-center">
            <button
              onClick={() => {
                setResult(null);
                setStep(0);
                setForm({
                  dish_name: "",
                  cuisine_type: "",
                  technique_ids: [],
                  self_rating: 0,
                  difficulty_felt: 0,
                  time_taken_mins: "",
                  notes: "",
                });
              }}
              className="rounded-lg border border-gray-200 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 transition-colors"
            >
              Log another
            </button>
            <button
              onClick={() => router.push("/dashboard")}
              className="rounded-lg bg-orange-500 px-4 py-2 text-sm font-semibold text-white hover:bg-orange-600 transition-colors"
            >
              Go to dashboard
            </button>
          </div>
        </div>
      </div>
    );
  }

  // ── Step indicator ────────────────────────────────────────────────────────
  const canAdvance =
    (step === 0 && form.dish_name.trim() && form.cuisine_type) ||
    step === 1 ||
    (step === 2 && form.self_rating > 0 && form.difficulty_felt > 0) ||
    step === 3;

  return (
    <div className="p-8 max-w-2xl mx-auto">
      <h1 className="text-2xl font-bold text-gray-900 mb-6">Log a Session</h1>

      {/* Step indicator */}
      <div className="flex items-center mb-8">
        {STEPS.map((label, i) => (
          <div key={label} className="flex items-center flex-1 last:flex-none">
            <div className="flex flex-col items-center">
              <div
                className={cn(
                  "w-8 h-8 rounded-full flex items-center justify-center text-sm font-semibold transition-colors",
                  i < step
                    ? "bg-orange-500 text-white"
                    : i === step
                    ? "bg-orange-500 text-white ring-4 ring-orange-100"
                    : "bg-gray-100 text-gray-400"
                )}
              >
                {i < step ? "✓" : i + 1}
              </div>
              <span
                className={cn(
                  "text-xs mt-1",
                  i === step ? "text-orange-600 font-medium" : "text-gray-400"
                )}
              >
                {label}
              </span>
            </div>
            {i < STEPS.length - 1 && (
              <div
                className={cn(
                  "flex-1 h-0.5 mx-2 mb-4 transition-colors",
                  i < step ? "bg-orange-400" : "bg-gray-200"
                )}
              />
            )}
          </div>
        ))}
      </div>

      <div className="rounded-2xl bg-white border border-gray-100 shadow-sm p-6">
        {/* Step 0: Dish */}
        {step === 0 && (
          <div className="space-y-5">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1.5">
                What did you cook?
              </label>
              <input
                type="text"
                value={form.dish_name}
                onChange={(e) =>
                  setForm((f) => ({ ...f, dish_name: e.target.value }))
                }
                placeholder="e.g. Chicken Stir-fry"
                autoFocus
                className="w-full rounded-lg border border-gray-300 px-3 py-2.5 text-sm focus:border-orange-500 focus:outline-none focus:ring-1 focus:ring-orange-500"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1.5">
                Cuisine type
              </label>
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                {CUISINES.map((c) => (
                  <button
                    key={c.value}
                    type="button"
                    onClick={() =>
                      setForm((f) => ({ ...f, cuisine_type: c.value }))
                    }
                    className={cn(
                      "rounded-lg border px-3 py-2.5 text-sm font-medium transition-colors",
                      form.cuisine_type === c.value
                        ? "border-orange-400 bg-orange-50 text-orange-700"
                        : "border-gray-200 text-gray-600 hover:border-orange-200 hover:bg-orange-50"
                    )}
                  >
                    {c.label}
                  </button>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* Step 1: Techniques */}
        {step === 1 && (
          <div>
            <div className="flex items-center justify-between mb-3">
              <label className="text-sm font-medium text-gray-700">
                Which techniques did you use?
              </label>
              {form.technique_ids.length > 0 && (
                <span className="text-xs text-orange-600 font-medium">
                  {form.technique_ids.length} selected
                </span>
              )}
            </div>
            <input
              type="text"
              placeholder="Search techniques…"
              value={techSearch}
              onChange={(e) => setTechSearch(e.target.value)}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm mb-4 focus:border-orange-500 focus:outline-none focus:ring-1 focus:ring-orange-500"
            />
            <div className="space-y-4 max-h-80 overflow-y-auto pr-1">
              {Object.entries(grouped).map(([cat, items]) => (
                <div key={cat}>
                  <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-2">
                    {CATEGORY_LABELS[cat] ?? cat}
                  </p>
                  <div className="space-y-1">
                    {items.map((t) => (
                      <label
                        key={t.id}
                        className={cn(
                          "flex items-center justify-between rounded-lg px-3 py-2 cursor-pointer transition-colors",
                          form.technique_ids.includes(t.id)
                            ? "bg-orange-50"
                            : "hover:bg-gray-50"
                        )}
                      >
                        <div className="flex items-center gap-3">
                          <input
                            type="checkbox"
                            checked={form.technique_ids.includes(t.id)}
                            onChange={() => toggleTechnique(t.id)}
                            className="w-4 h-4 rounded accent-orange-500"
                          />
                          <span className="text-sm text-gray-800">{t.name}</span>
                          <span
                            className={cn(
                              "text-xs px-1.5 py-0.5 rounded-full font-medium",
                              t.difficulty_tier === "beginner"
                                ? "bg-green-50 text-green-600"
                                : t.difficulty_tier === "intermediate"
                                ? "bg-yellow-50 text-yellow-600"
                                : "bg-red-50 text-red-600"
                            )}
                          >
                            {t.difficulty_tier}
                          </span>
                        </div>
                        <span className="text-xs text-gray-400">
                          +{t.xp_reward} XP
                        </span>
                      </label>
                    ))}
                  </div>
                </div>
              ))}
              {Object.keys(grouped).length === 0 && (
                <p className="text-sm text-gray-400 text-center py-6">
                  No techniques match your search.
                </p>
              )}
            </div>
          </div>
        )}

        {/* Step 2: Rating */}
        {step === 2 && (
          <div className="space-y-7">
            <StarRating
              value={form.self_rating}
              onChange={(v) => setForm((f) => ({ ...f, self_rating: v }))}
              label="How well did it turn out?"
            />
            <StarRating
              value={form.difficulty_felt}
              onChange={(v) => setForm((f) => ({ ...f, difficulty_felt: v }))}
              label="How challenging was it?"
            />
          </div>
        )}

        {/* Step 3: Details */}
        {step === 3 && (
          <div className="space-y-5">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1.5">
                Time taken{" "}
                <span className="text-gray-400 font-normal">(optional)</span>
              </label>
              <div className="flex items-center gap-2">
                <input
                  type="number"
                  min={1}
                  value={form.time_taken_mins}
                  onChange={(e) =>
                    setForm((f) => ({ ...f, time_taken_mins: e.target.value }))
                  }
                  placeholder="45"
                  className="w-28 rounded-lg border border-gray-300 px-3 py-2.5 text-sm focus:border-orange-500 focus:outline-none focus:ring-1 focus:ring-orange-500"
                />
                <span className="text-sm text-gray-500">minutes</span>
              </div>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1.5">
                Notes{" "}
                <span className="text-gray-400 font-normal">(optional)</span>
              </label>
              <textarea
                rows={4}
                value={form.notes}
                onChange={(e) =>
                  setForm((f) => ({ ...f, notes: e.target.value }))
                }
                placeholder="What went well? What would you do differently?"
                className="w-full rounded-lg border border-gray-300 px-3 py-2.5 text-sm focus:border-orange-500 focus:outline-none focus:ring-1 focus:ring-orange-500 resize-none"
              />
            </div>
          </div>
        )}

        {error && (
          <p className="mt-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-600">
            {error}
          </p>
        )}

        {/* Navigation buttons */}
        <div className="flex justify-between mt-6 pt-4 border-t border-gray-100">
          <button
            type="button"
            onClick={() => setStep((s) => s - 1)}
            disabled={step === 0}
            className="rounded-lg border border-gray-200 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 disabled:opacity-0 transition-colors"
          >
            ← Back
          </button>

          {step < STEPS.length - 1 ? (
            <button
              type="button"
              onClick={() => setStep((s) => s + 1)}
              disabled={!canAdvance}
              className="rounded-lg bg-orange-500 px-5 py-2 text-sm font-semibold text-white hover:bg-orange-600 disabled:opacity-50 transition-colors"
            >
              Next →
            </button>
          ) : (
            <button
              type="button"
              onClick={handleSubmit}
              disabled={loading}
              className="rounded-lg bg-orange-500 px-6 py-2 text-sm font-semibold text-white hover:bg-orange-600 disabled:opacity-60 transition-colors"
            >
              {loading ? "Logging…" : "Log Session ✓"}
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
