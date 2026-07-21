"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";

const NAV = [
  { href: "/dashboard", label: "Dashboard", icon: "🏠" },
  { href: "/log",       label: "Log Session", icon: "📝" },
  { href: "/skills",    label: "Skills",       icon: "📊" },
  { href: "/recipes",   label: "Recipes",      icon: "📖" },
  { href: "/coach",     label: "AI Coach",     icon: "🤖" },
  { href: "/profile",   label: "Profile",      icon: "👤" },
];

export default function AppShell({
  children,
  username,
}: {
  children: React.ReactNode;
  username: string;
}) {
  const pathname = usePathname();

  return (
    <div className="flex min-h-screen">
      {/* Sidebar */}
      <aside className="fixed top-0 left-0 h-full w-56 bg-white border-r border-gray-100 flex flex-col z-10">
        <div className="flex items-center gap-2 px-5 py-4 border-b border-gray-100">
          <span className="text-2xl">🍳</span>
          <span className="font-bold text-gray-900 text-lg">CookQuest</span>
        </div>

        <nav className="flex-1 p-3 space-y-0.5 overflow-y-auto">
          {NAV.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-colors",
                pathname === item.href
                  ? "bg-orange-50 text-orange-600 font-semibold"
                  : "text-gray-600 hover:bg-gray-50 hover:text-gray-900"
              )}
            >
              <span className="text-base w-5 text-center">{item.icon}</span>
              <span>{item.label}</span>
            </Link>
          ))}
        </nav>

        <div className="p-3 border-t border-gray-100">
          <p className="px-3 py-1 text-xs text-gray-400 truncate">{username}</p>
          <form action="/auth/signout" method="post">
            <button
              type="submit"
              className="w-full text-left px-3 py-2 text-sm text-gray-500 rounded-lg hover:bg-red-50 hover:text-red-600 transition-colors"
            >
              Sign out
            </button>
          </form>
        </div>
      </aside>

      {/* Page content */}
      <main className="ml-56 flex-1 min-h-screen bg-gray-50">{children}</main>
    </div>
  );
}
