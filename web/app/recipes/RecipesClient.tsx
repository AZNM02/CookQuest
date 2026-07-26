"use client";

import { useState, useEffect, useCallback } from "react";

const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";
const PAGE_SIZE = 12;

type Recipe = {
  id: number;
  name: string;
  cuisine_type: string;
  difficulty: string;
  estimated_time_mins: number | null;
  description: string | null;
  instructions: string | null;
  technique_names: string[];
  is_favorited: boolean;
};

type RecommendedRecipe = {
  id: number;
  name: string;
  cuisine_type: string;
  difficulty: string;
  estimated_time_mins: number | null;
  description: string | null;
  instructions: string | null;
  technique_names: string[];
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
  isFavorited,
  onToggleFavorite,
}: {
  recipe: Recipe | RecommendedRecipe;
  weakTargeted?: string[];
  highlighted?: boolean;
  isFavorited?: boolean;
  onToggleFavorite?: () => void;
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
        <div className="flex items-start justify-between gap-2 mb-2">
          <h3 className="font-semibold text-gray-900 text-sm leading-snug flex-1 min-w-0">
            {recipe.name}
          </h3>
          <div className="flex items-center gap-1.5 shrink-0">
            {onToggleFavorite && (
              <button
                onClick={onToggleFavorite}
                className={`text-base leading-none transition-colors ${
                  isFavorited
                    ? "text-red-500"
                    : "text-gray-200 hover:text-red-300"
                }`}
                title={isFavorited ? "Remove from favorites" : "Save to favorites"}
              >
                {isFavorited ? "♥" : "♡"}
              </button>
            )}
            <span
              className={`text-xs px-2 py-0.5 rounded-full border font-medium ${
                DIFFICULTY_COLORS[recipe.difficulty] ??
                "bg-gray-50 text-gray-600 border-gray-200"
              }`}
            >
              {recipe.difficulty}
            </span>
          </div>
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

        {steps.length > 0 && (
          <button
            onClick={() => setExpanded((v) => !v)}
            className="text-xs font-medium text-orange-600 hover:text-orange-700 transition-colors"
          >
            {expanded ? "▲ Hide steps" : "▼ Show cooking steps"}
          </button>
        )}
      </div>

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

function SkeletonCard() {
  return (
    <div className="rounded-2xl border border-gray-100 bg-white p-5 animate-pulse">
      <div className="h-4 bg-gray-100 rounded w-3/4 mb-3" />
      <div className="h-3 bg-gray-100 rounded w-1/3 mb-4" />
      <div className="h-3 bg-gray-100 rounded w-full mb-2" />
      <div className="h-3 bg-gray-100 rounded w-5/6" />
    </div>
  );
}

export default function RecipesClient({
  recommendations,
  token,
}: {
  recommendations: RecommendedRecipe[];
  token: string;
}) {
  const [recipes, setRecipes] = useState<Recipe[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);

  const [query, setQuery] = useState("");
  const [debouncedQuery, setDebouncedQuery] = useState("");
  const [cuisineFilter, setCuisineFilter] = useState("");
  const [difficultyFilter, setDifficultyFilter] = useState("");
  const [favoritesOnly, setFavoritesOnly] = useState(false);

  const [importing, setImporting] = useState(false);
  const [importMsg, setImportMsg] = useState("");

  // Debounce search query by 350ms
  useEffect(() => {
    const t = setTimeout(() => setDebouncedQuery(query), 350);
    return () => clearTimeout(t);
  }, [query]);

  const fetchRecipes = useCallback(
    async (offsetVal: number, reset: boolean) => {
      if (reset) setLoading(true);
      else setLoadingMore(true);
      try {
        const params = new URLSearchParams({
          limit: String(PAGE_SIZE),
          offset: String(offsetVal),
        });
        if (cuisineFilter) params.set("cuisine_type", cuisineFilter);
        if (difficultyFilter) params.set("difficulty", difficultyFilter);
        if (debouncedQuery) params.set("search", debouncedQuery);
        if (favoritesOnly) params.set("favorites_only", "true");

        const res = await fetch(`${API_URL}/recipes?${params}`, {
          headers: { Authorization: `Bearer ${token}` },
        });
        if (!res.ok) return;
        const data: { recipes: Recipe[]; total: number } = await res.json();
        setTotal(data.total);
        setRecipes((prev) => (reset ? data.recipes : [...prev, ...data.recipes]));
      } finally {
        setLoading(false);
        setLoadingMore(false);
      }
    },
    [cuisineFilter, difficultyFilter, debouncedQuery, favoritesOnly, token]
  );

  // Re-fetch from page 0 whenever any filter changes
  useEffect(() => {
    fetchRecipes(0, true);
  }, [fetchRecipes]);

  const toggleFavorite = async (recipe: Recipe) => {
    const nowFav = !recipe.is_favorited;
    // When un-favoriting in the favorites-only view, remove the card immediately
    if (favoritesOnly && !nowFav) {
      setRecipes((prev) => prev.filter((r) => r.id !== recipe.id));
      setTotal((prev) => Math.max(0, prev - 1));
    } else {
      setRecipes((prev) =>
        prev.map((r) => (r.id === recipe.id ? { ...r, is_favorited: nowFav } : r))
      );
    }
    try {
      await fetch(`${API_URL}/recipes/${recipe.id}/favorite`, {
        method: nowFav ? "POST" : "DELETE",
        headers: { Authorization: `Bearer ${token}` },
      });
    } catch {
      // Revert optimistic update on network failure
      setRecipes((prev) =>
        prev.map((r) => (r.id === recipe.id ? { ...r, is_favorited: !nowFav } : r))
      );
    }
  };

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
        if (data.imported > 0) fetchRecipes(0, true);
      } else {
        setImportMsg("Import failed — is the backend running?");
      }
    } catch {
      setImportMsg("Import failed — is the backend running?");
    } finally {
      setImporting(false);
    }
  }

  const hasMore = recipes.length < total;

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

      {/* Library */}
      <section>
        {/* Title + Discover more */}
        <div className="flex items-center justify-between flex-wrap gap-3 mb-4">
          <h2 className="text-base font-semibold text-gray-800">
            {favoritesOnly ? "Favorites" : "All Recipes"}
            {!loading && (
              <span className="text-gray-400 font-normal text-sm ml-1">({total})</span>
            )}
          </h2>
          <button
            onClick={handleImport}
            disabled={importing}
            className="rounded-lg bg-orange-500 px-3 py-1.5 text-xs font-semibold text-white hover:bg-orange-600 disabled:opacity-50 transition-colors"
          >
            {importing ? "Importing…" : "✦ Discover more"}
          </button>
        </div>

        {/* Search + filters */}
        <div className="flex flex-wrap gap-2 mb-4">
          <input
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search recipes…"
            className="flex-1 min-w-[160px] rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 placeholder-gray-400 focus:border-orange-400 focus:outline-none"
          />
          <select
            value={cuisineFilter}
            onChange={(e) => setCuisineFilter(e.target.value)}
            className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-600 focus:border-orange-400 focus:outline-none"
          >
            <option value="">All cuisines</option>
            {["asian", "western", "mediterranean", "middle_eastern", "other"].map((c) => (
              <option key={c} value={c}>
                {CUISINE_LABELS[c]}
              </option>
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
          <button
            onClick={() => setFavoritesOnly((v) => !v)}
            className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors border ${
              favoritesOnly
                ? "bg-red-50 text-red-500 border-red-200"
                : "bg-white text-gray-500 border-gray-200 hover:border-red-200 hover:text-red-400"
            }`}
          >
            ♥ Favorites
          </button>
        </div>

        {importMsg && (
          <p className="text-sm text-orange-600 bg-orange-50 rounded-lg px-3 py-2 mb-4">
            {importMsg}
          </p>
        )}

        {loading ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {Array.from({ length: PAGE_SIZE }).map((_, i) => (
              <SkeletonCard key={i} />
            ))}
          </div>
        ) : recipes.length === 0 ? (
          <p className="text-sm text-gray-400">
            {favoritesOnly
              ? "No favorites yet — click ♡ on any recipe to save it."
              : debouncedQuery
              ? `No recipes found for "${debouncedQuery}".`
              : "No recipes match your filters."}
          </p>
        ) : (
          <>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              {recipes.map((r) => (
                <RecipeCard
                  key={r.id}
                  recipe={r}
                  isFavorited={r.is_favorited}
                  onToggleFavorite={() => toggleFavorite(r)}
                />
              ))}
            </div>

            {hasMore && (
              <div className="text-center mt-6">
                <button
                  onClick={() => fetchRecipes(recipes.length, false)}
                  disabled={loadingMore}
                  className="rounded-lg border border-gray-200 bg-white px-6 py-2 text-sm text-gray-600 hover:bg-gray-50 transition-colors disabled:opacity-50"
                >
                  {loadingMore
                    ? "Loading…"
                    : `Load more (${total - recipes.length} remaining)`}
                </button>
              </div>
            )}
          </>
        )}
      </section>
    </div>
  );
}
