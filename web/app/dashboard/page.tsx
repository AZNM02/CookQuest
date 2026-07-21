import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase-server";

export default async function DashboardPage() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login");

  return (
    <div className="flex min-h-screen items-center justify-center bg-gray-50">
      <div className="text-center">
        <div className="text-5xl mb-4">🍳</div>
        <h1 className="text-2xl font-bold text-gray-900 mb-2">
          Welcome to CookQuest!
        </h1>
        <p className="text-gray-500 mb-1">Signed in as</p>
        <p className="font-medium text-gray-700 mb-8">{user.email}</p>
        <form action="/auth/signout" method="post">
          <button
            type="submit"
            className="rounded-lg border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 transition-colors"
          >
            Sign out
          </button>
        </form>
        <p className="mt-6 text-xs text-gray-400">
          Dashboard coming in Step 4 ⚡
        </p>
      </div>
    </div>
  );
}
