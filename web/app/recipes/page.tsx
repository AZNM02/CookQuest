import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase-server";
import AppShell from "@/components/AppShell";

const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

type Recipe = {
  id: number;
  name: string;
  cuisine_type: string;
  difficulty: string;
  estimated_time_mins: number | null;
  description: string | null;
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

function RecipeCard({
  recipe,
  weakTargeted,
  highlighted,
}: {
  recipe: Recipe;
  weakTargeted?: string[];
  highlighted?: boolean;
}) {
  return (
    <div
      className={`rounded-2xl border p-5 transition-shadow hover:shadow-md ${
        highlighted
          ? "border-orange-200 bg-gradient-to-br from-orange-50 to-amber-50"
          : "border-gray-100 bg-white"
      }`}
    >
      <div className="flex items-start justify-between gap-3 mb-2">
        <h3 className="font-semibold text-gray-900 text-sm">{recipe.name}</h3>
        <span
          className={`shrink-0 text-xs px-2 py-0.5 rounded-full border font-medium ${
            DIFFICULTY_COLORS[recipe.difficulty] ?? "bg-gray-50 text-gray-600 border-gray-200"
          }`}
        >
          {recipe.difficulty}
        </span>
      </div>

      <div className="flex items-center gap-3 text-xs text-gray-400 mb-3">
        <span>{CUISINE_LABELS[recipe.cuisine_type] ?? recipe.cuisine_type}</span>
        {recipe.estimated_time_mins && (
          <>
            <span>·</span>
            <span>{recipe.estimated_time_mins} min</span>
          </>
        )}
      </div>

      {recipe.description && (
        <p className="text-xs text-gray-500 mb-3 leading-relaxed">{recipe.description}</p>
      )}

      {recipe.technique_names.length > 0 && (
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
        <p className="text-xs text-orange-600 font-medium">
          Targets {weakTargeted.length} of your weak technique{weakTargeted.length !== 1 ? "s" : ""}
        </p>
      )}
    </div>
  );
}

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

  const recipes: Recipe[] =
    recipesRes.status === "fulfilled" && recipesRes.value.ok
      ? await recipesRes.value.json()
      : [];

  const recommendations: RecommendedRecipe[] =
    recsRes.status === "fulfilled" && recsRes.value.ok
      ? await recsRes.value.json()
      : [];

  const recIds = new Set(recommendations.map((r) => r.id));
  const browseable = recipes.filter((r) => !recIds.has(r.id));

  return (
    <AppShell username={user.email ?? ""}>
      <div className="p-8 max-w-5xl mx-auto space-y-10">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Recipes</h1>
          <p className="text-sm text-gray-500 mt-1">
            Personalised picks and a full recipe library.
          </p>
        </div>

        {/* Recommendations */}
        {recommendations.length > 0 && (
          <section>
            <div className="flex items-center gap-2 mb-4">
              <span className="text-lg">✨</span>
              <h2 className="text-base font-semibold text-gray-800">
                Recommended for you
              </h2>
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

        {/* All recipes */}
        <section>
          <h2 className="text-base font-semibold text-gray-800 mb-4">
            All Recipes
          </h2>
          {browseable.length === 0 && recipes.length === 0 ? (
            <p className="text-sm text-gray-400">No recipes found.</p>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              {(browseable.length > 0 ? browseable : recipes).map((r) => (
                <RecipeCard key={r.id} recipe={r} />
              ))}
            </div>
          )}
        </section>
      </div>
    </AppShell>
  );
}
