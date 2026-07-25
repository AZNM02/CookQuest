"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

type Recipe = {
  id: number;
  name: string;
  cuisine_type: string;
  difficulty: string;
  estimated_time_mins: number | null;
  description: string | null;
  instructions: string | null;
  technique_names: string[];
};

type RecommendedRecipe = Recipe & {
  gap_score: number;
  weak_techniques_targeted: string[];
};

const DIFFICULTY_COLORS: Record<string, string> = {
  beginner: "bg-green-50 text-green-700 border-green-200",
  intermediate: "bg-yellow-50 text-yellow-700 border-yellow-200",
  advanced: "bg-red-50 text-red-700 border-red-200",
};

const CUISINE_LABELS: Record<string, string> = {
  asian: "Asian",
  western: "Western",
  mediterranean: "Mediterranean",
  middle_eastern: "Middle Eastern",
  other: "Other",
};

function parseSteps(instructions: string): string[] {
  return instructions
    .split("\n")
    .map((s) => s.replace(/^\d+\.\s*/, "").trim())
    .filter(Boolean);
}

function RecipeCard({
  recipe,
  weakTargeted,
  highlighted,
}: {
  recipe: Recipe;
  weakTargeted?: string[];
  highlighted?: boolean;
}) {
  const [expanded, setExpanded] = useState(false);
  const steps = recipe.instructions ? parseSteps(recipe.instructions) : [];

  return (
    <div
      className={`rounded-2xl border transition-shadow hover:shadow-md ${
        highlighted
          ? "border-orange-200 bg-gradient-to-br from-orange-50 to-amber-50"
          : "border-gray-100 bg-white"
      }`}
    >
      <div className="p-5">
        {/* Header */}
        <div className="flex items-start justify-between gap-3 mb-2">
          <h3 className="font-semibold text-gray-900 text-sm leading-snug">{recipe.name}</h3>
          <span
            className={`shrink-0 text-xs px-2 py-0.5 rounded-full border font-medium ${
              DIFFICULTY_COLORS[recipe.difficulty] ?? "bg-gray-50 text-gray-600 border-gray-200"
            }`}
          >
            {recipe.difficulty}
          </span>
        </div>

        {/* Meta */}
        <div className="flex items-center gap-3 text-xs text-gray-400 mb-3">
          <span>{CUISINE_LABELS[recipe.cuisine_type] ?? recipe.cuisine_type}</span>
          {recipe.estimated_time_mins && (
            <>
              <span>·</span>
              <span>⏱ {recipe.estimated_time_mins} min</span>
            </>
          )}
        </div>

        {recipe.description && (
          <p className="text-xs text-gray-500 mb-3 leading-relaxed">{recipe.description}</p>
        )}

        {/* Technique tags */}
        {(recipe.technique_names ?? []).length > 0 && (
          <div className="flex flex-wrap gap-1.5 mb-3">
            {recipe.technique_names.map((t) => {
              const isWeak = weakTargeted?.includes(t);
              return (
                <span
                  key={t}
                  className={`text-xs px-2 py-0.5 rounded-full ${
                    isWeak
                      ? "bg-orange-100 text-orange-700 font-medium"
                      : "bg-gray-100 text-gray-500"
                  }`}
                >
                  {t}
                </span>
              );
            })}
          </div>
        )}

        {weakTargeted && weakTargeted.length > 0 && (
          <p className="text-xs text-orange-600 font-medium mb-3">
            ✦ Targets {weakTargeted.length} of your weak technique
            {weakTargeted.length !== 1 ? "s" : ""}
          </p>
        )}

        {/* Expand toggle */}
        {steps.length > 0 && (
          <button
            onClick={() => setExpanded((v) => !v)}
            className="text-xs font-medium text-orange-600 hover:text-orange-700 transition-colors"
          >
            {expanded ? "▲ Hide steps" : "▼ Show cooking steps"}
          </button>
        )}
      </div>

      {/* Expanded steps */}
      {expanded && steps.length > 0 && (
        <div className="border-t border-gray-100 px-5 py-4 space-y-2">
          <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-3">
            Cooking Steps
          </p>
          <ol className="space-y-2">
            {steps.map((step, i) => (
              <li key={i} className="flex gap-3 text-sm text-gray-700">
                <span className="shrink-0 w-5 h-5 rounded-full bg-orange-100 text-orange-600 text-xs font-bold flex items-center justify-center mt-0.5">
                  {i + 1}
                </span>
                <span className="leading-relaxed">{step}</span>
              </li>
            ))}
          </ol>
        </div>
      )}
    </div>
  );
}

export default function RecipesClient({
  recipes,
  recommendations,
  token,
}: {
  recipes: Recipe[];
  recommendations: RecommendedRecipe[];
  token: string;
}) {
  const router = useRouter();
  const [cuisineFilter, setCuisineFilter] = useState("");
  const [difficultyFilter, setDifficultyFilter] = useState("");
  const [importing, setImporting] = useState(false);
  const [importMsg, setImportMsg] = useState("");

  async function handleImport() {
    setImporting(true);
    setImportMsg("");
    try {
      const res = await fetch(`${API_URL}/recipes/import`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}` },
      });
      const data = await res.json();
      if (res.ok) {
        setImportMsg(
          data.imported > 0
            ? `Added ${data.imported} new recipes!`
            : `All fetched recipes are already in your library — try again for more.`
        );
        if (data.imported > 0) router.refresh();
      } else {
        setImportMsg("Import failed — is the backend running?");
      }
    } catch {
      setImportMsg("Import failed — is the backend running?");
    } finally {
      setImporting(false);
    }
  }

  const recIds = new Set(recommendations.map((r) => r.id));
  const recMap = new Map(recommendations.map((r) => [r.id, r]));

  const filtered = recipes.filter((r) => {
    if (cuisineFilter && r.cuisine_type !== cuisineFilter) return false;
    if (difficultyFilter && r.difficulty !== difficultyFilter) return false;
    return true;
  });

  return (
    <div className="space-y-10">
      {/* Recommendations */}
      {recommendations.length > 0 && (
        <section>
          <div className="flex items-center gap-2 mb-4">
            <span className="text-lg">✨</span>
            <h2 className="text-base font-semibold text-gray-800">Recommended for you</h2>
            <span className="text-xs text-orange-600 bg-orange-50 px-2 py-0.5 rounded-full font-medium border border-orange-100">
              Targets your skill gaps
            </span>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {recommendations.map((r) => (
              <RecipeCard
                key={r.id}
                recipe={r}
                weakTargeted={r.weak_techniques_targeted}
                highlighted
              />
            ))}
          </div>
        </section>
      )}

      {/* All recipes with filters */}
      <section>
        <div className="flex items-center justify-between flex-wrap gap-3 mb-4">
          <h2 className="text-base font-semibold text-gray-800">
            All Recipes{" "}
            <span className="text-gray-400 font-normal text-sm">({filtered.length})</span>
          </h2>
          <div className="flex gap-2 items-center flex-wrap">
            <button
              onClick={handleImport}
              disabled={importing}
              className="rounded-lg bg-orange-500 px-3 py-1.5 text-xs font-semibold text-white hover:bg-orange-600 disabled:opacity-50 transition-colors"
            >
              {importing ? "Importing…" : "✦ Discover more"}
            </button>
            <select
              value={cuisineFilter}
              onChange={(e) => setCuisineFilter(e.target.value)}
              className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-600 focus:border-orange-400 focus:outline-none"
            >
              <option value="">All cuisines</option>
              {["asian", "western", "mediterranean", "middle_eastern", "other"].map((c) => (
                <option key={c} value={c}>{CUISINE_LABELS[c]}</option>
              ))}
            </select>
            <select
              value={difficultyFilter}
              onChange={(e) => setDifficultyFilter(e.target.value)}
              className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-600 focus:border-orange-400 focus:outline-none"
            >
              <option value="">All difficulties</option>
              <option value="beginner">Beginner</option>
              <option value="intermediate">Intermediate</option>
              <option value="advanced">Advanced</option>
            </select>
          </div>
        </div>

        {importMsg && (
          <p className="text-sm text-orange-600 bg-orange-50 rounded-lg px-3 py-2 mb-4">
            {importMsg}
          </p>
        )}

        {filtered.length === 0 ? (
          <p className="text-sm text-gray-400">No recipes match your filters.</p>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {filtered.map((r) => {
              const rec = recMap.get(r.id);
              return (
                <RecipeCard
                  key={r.id}
                  recipe={r}
                  weakTargeted={rec?.weak_techniques_targeted}
                  highlighted={recIds.has(r.id)}
                />
              );
            })}
          </div>
        )}
      </section>
    </div>
  );
}
