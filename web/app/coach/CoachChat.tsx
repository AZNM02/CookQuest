"use client";

import { useState, useRef, useEffect } from "react";
import { cn } from "@/lib/utils";

const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

type Message = { role: "user" | "assistant"; content: string };
type Mode = "precook" | "chat" | "debrief";

type Recipe = { id: number; name: string; description: string | null; instructions: string | null };

// ── Searchable recipe picker ──────────────────────────────────────────────────
function RecipePicker({
  token,
  value,
  onChange,
  placeholder = "Search for a recipe…",
  allowNone = false,
}: {
  token: string;
  value: Recipe | null;
  onChange: (recipe: Recipe | null) => void;
  placeholder?: string;
  allowNone?: boolean;
}) {
  const [inputVal, setInputVal] = useState(value?.name ?? "");
  const [results, setResults] = useState<Recipe[]>([]);
  const [open, setOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  // Sync input when value is cleared externally
  useEffect(() => {
    if (!value) setInputVal("");
  }, [value]);

  // Fetch with debounce; 0ms delay when input is empty (initial open)
  useEffect(() => {
    if (!open) return;
    const delay = inputVal.trim() ? 300 : 0;
    const t = setTimeout(async () => {
      const params = new URLSearchParams({ limit: "20" });
      if (inputVal.trim()) params.set("search", inputVal.trim());
      const res = await fetch(`${API_URL}/recipes?${params}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) {
        const data = await res.json();
        setResults(data.recipes ?? []);
      }
    }, delay);
    return () => clearTimeout(t);
  }, [inputVal, open, token]);

  // Close on outside click, resetting input to the current selection
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (!containerRef.current?.contains(e.target as Node)) {
        setOpen(false);
        setInputVal(value?.name ?? "");
      }
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, [value]);

  function handleSelect(recipe: Recipe | null) {
    onChange(recipe);
    setInputVal(recipe?.name ?? "");
    setOpen(false);
  }

  return (
    <div ref={containerRef} className="relative">
      <input
        type="text"
        value={inputVal}
        onChange={(e) => {
          setInputVal(e.target.value);
          if (value) onChange(null);
        }}
        onFocus={() => setOpen(true)}
        placeholder={placeholder}
        className="w-full rounded-lg border border-gray-300 px-3 py-2.5 text-sm focus:border-orange-500 focus:outline-none focus:ring-1 focus:ring-orange-500"
      />
      {open && (
        <div className="absolute z-20 w-full mt-1 max-h-60 overflow-y-auto rounded-xl border border-gray-200 bg-white shadow-lg">
          {allowNone && (
            <button
              onMouseDown={(e) => { e.preventDefault(); handleSelect(null); }}
              className="w-full text-left px-3 py-2 text-sm text-gray-400 italic hover:bg-gray-50 transition-colors"
            >
              No specific recipe (general Q&amp;A)
            </button>
          )}
          {results.length === 0 ? (
            <p className="px-3 py-2.5 text-xs text-gray-400">
              {inputVal.trim() ? `No recipes found for "${inputVal}".` : "No recipes yet."}
            </p>
          ) : (
            results.map((r) => (
              <button
                key={r.id}
                onMouseDown={(e) => { e.preventDefault(); handleSelect(r); }}
                className={cn(
                  "w-full text-left px-3 py-2 text-sm transition-colors hover:bg-orange-50 hover:text-orange-700",
                  value?.id === r.id
                    ? "bg-orange-50 text-orange-700 font-medium"
                    : "text-gray-700"
                )}
              >
                {r.name}
              </button>
            ))
          )}
        </div>
      )}
    </div>
  );
}

async function streamRequest(
  path: string,
  body: object,
  token: string,
  onChunk: (text: string) => void
): Promise<void> {
  const res = await fetch(`${API_URL}${path}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: "Request failed" }));
    throw new Error(err.detail ?? "Request failed");
  }

  const reader = res.body!.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split("\n");
    buffer = lines.pop() ?? "";
    for (const line of lines) {
      if (line.startsWith("data: ")) {
        const payload = line.slice(6);
        if (payload === "[DONE]") return;
        try {
          const { text } = JSON.parse(payload);
          onChunk(text);
        } catch {
          // ignore malformed chunks
        }
      }
    }
  }
}

// ── Pre-Cook tab ──────────────────────────────────────────────────────────────
function PreCookTab({ token }: { token: string }) {
  const [selected, setSelected] = useState<Recipe | null>(null);
  const [response, setResponse] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function handleStart() {
    if (!selected) return;
    setResponse("");
    setError("");
    setLoading(true);
    try {
      await streamRequest(
        "/ai/precook",
        {
          recipe_name: selected.name,
          recipe_description: selected.description,
          recipe_instructions: selected.instructions,
        },
        token,
        (chunk) => setResponse((r) => r + chunk)
      );
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed to get response");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="space-y-4">
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1.5">
          Choose a recipe
        </label>
        <RecipePicker
          token={token}
          value={selected}
          onChange={(r) => { setSelected(r); setResponse(""); }}
          placeholder="Search for a recipe…"
        />
      </div>
      <button
        onClick={handleStart}
        disabled={!selected || loading}
        className="w-full rounded-lg bg-orange-500 px-4 py-2.5 text-sm font-semibold text-white hover:bg-orange-600 disabled:opacity-50 transition-colors"
      >
        {loading ? "Generating walkthrough…" : "Get Pre-Cook Walkthrough"}
      </button>
      {error && <p className="text-sm text-red-500 bg-red-50 rounded-lg px-3 py-2">{error}</p>}
      {response && (
        <div className="rounded-xl bg-orange-50 border border-orange-100 px-5 py-4 text-sm text-gray-800 whitespace-pre-wrap leading-relaxed">
          {response}
          {loading && <span className="inline-block w-2 h-4 bg-orange-400 ml-1 animate-pulse rounded-sm" />}
        </div>
      )}
    </div>
  );
}

// ── Mid-Cook chat tab ─────────────────────────────────────────────────────────
function ChatTab({ token }: { token: string }) {
  const [selectedRecipe, setSelectedRecipe] = useState<Recipe | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  async function handleSend() {
    const text = input.trim();
    if (!text || loading) return;
    setInput("");
    setError("");

    const newMessages: Message[] = [...messages, { role: "user", content: text }];
    setMessages(newMessages);
    setLoading(true);

    let assistantText = "";
    setMessages((m) => [...m, { role: "assistant", content: "" }]);

    try {
      await streamRequest(
        "/ai/chat",
        { messages: newMessages, recipe_name: selectedRecipe?.name ?? null },
        token,
        (chunk) => {
          assistantText += chunk;
          setMessages((m) => [
            ...m.slice(0, -1),
            { role: "assistant", content: assistantText },
          ]);
        }
      );
    } catch (e: unknown) {
      setMessages((m) => m.slice(0, -1));
      setError(e instanceof Error ? e.message : "Failed to get response");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="space-y-4">
      <RecipePicker
        token={token}
        value={selectedRecipe}
        onChange={setSelectedRecipe}
        placeholder="Search for a recipe (or leave blank for general Q&amp;A)…"
        allowNone
      />

      <div className="rounded-xl border border-gray-200 bg-gray-50 h-80 overflow-y-auto p-4 space-y-3">
        {messages.length === 0 && (
          <p className="text-sm text-gray-400 text-center mt-8">
            Ask anything while you cook — heat levels, substitutions, technique tips…
          </p>
        )}
        {messages.map((m, i) => (
          <div key={i} className={cn("flex", m.role === "user" ? "justify-end" : "justify-start")}>
            <div
              className={cn(
                "max-w-[80%] rounded-2xl px-4 py-2.5 text-sm leading-relaxed whitespace-pre-wrap",
                m.role === "user"
                  ? "bg-orange-500 text-white"
                  : "bg-white border border-gray-200 text-gray-800"
              )}
            >
              {m.content}
              {loading && i === messages.length - 1 && m.role === "assistant" && m.content === "" && (
                <span className="inline-flex gap-1">
                  <span className="w-1.5 h-1.5 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: "0ms" }} />
                  <span className="w-1.5 h-1.5 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: "150ms" }} />
                  <span className="w-1.5 h-1.5 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: "300ms" }} />
                </span>
              )}
            </div>
          </div>
        ))}
        <div ref={bottomRef} />
      </div>

      {error && <p className="text-sm text-red-500 bg-red-50 rounded-lg px-3 py-2">{error}</p>}

      <div className="flex gap-2">
        <input
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && !e.shiftKey && handleSend()}
          placeholder="Ask a cooking question…"
          disabled={loading}
          className="flex-1 rounded-lg border border-gray-300 px-3 py-2.5 text-sm focus:border-orange-500 focus:outline-none focus:ring-1 focus:ring-orange-500"
        />
        <button
          onClick={handleSend}
          disabled={!input.trim() || loading}
          className="rounded-lg bg-orange-500 px-5 py-2.5 text-sm font-semibold text-white hover:bg-orange-600 disabled:opacity-50 transition-colors"
        >
          Send
        </button>
      </div>
    </div>
  );
}

// ── Post-Cook debrief tab ─────────────────────────────────────────────────────
function DebriefTab({ token }: { token: string }) {
  const [dish, setDish] = useState("");
  const [cuisine, setCuisine] = useState("asian");
  const [rating, setRating] = useState(3);
  const [difficulty, setDifficulty] = useState(3);
  const [techniques, setTechniques] = useState("");
  const [notes, setNotes] = useState("");
  const [response, setResponse] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function handleDebrief() {
    if (!dish.trim()) return;
    setResponse("");
    setError("");
    setLoading(true);
    try {
      await streamRequest(
        "/ai/debrief",
        {
          dish_name: dish,
          cuisine_type: cuisine,
          self_rating: rating,
          difficulty_felt: difficulty,
          technique_names: techniques.split(",").map((t) => t.trim()).filter(Boolean),
          notes: notes || null,
        },
        token,
        (chunk) => setResponse((r) => r + chunk)
      );
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed to get debrief");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">Dish cooked</label>
          <input
            type="text"
            value={dish}
            onChange={(e) => setDish(e.target.value)}
            placeholder="e.g. Chicken Stir-fry"
            className="w-full rounded-lg border border-gray-300 px-3 py-2.5 text-sm focus:border-orange-500 focus:outline-none focus:ring-1 focus:ring-orange-500"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">Cuisine</label>
          <select
            value={cuisine}
            onChange={(e) => setCuisine(e.target.value)}
            className="w-full rounded-lg border border-gray-300 px-3 py-2.5 text-sm focus:border-orange-500 focus:outline-none focus:ring-1 focus:ring-orange-500"
          >
            {["asian","western","mediterranean","middle_eastern","other"].map((c) => (
              <option key={c} value={c}>{c.replace("_", " ")}</option>
            ))}
          </select>
        </div>
      </div>
      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">Self-rating (1–5)</label>
          <input type="range" min={1} max={5} value={rating} onChange={(e) => setRating(Number(e.target.value))}
            className="w-full accent-orange-500" />
          <p className="text-xs text-gray-400 mt-1">{["","Poor","Fair","Good","Great","Excellent"][rating]}</p>
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1.5">Difficulty felt (1–5)</label>
          <input type="range" min={1} max={5} value={difficulty} onChange={(e) => setDifficulty(Number(e.target.value))}
            className="w-full accent-orange-500" />
          <p className="text-xs text-gray-400 mt-1">{["","Very easy","Easy","Moderate","Hard","Very hard"][difficulty]}</p>
        </div>
      </div>
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1.5">
          Techniques used <span className="text-gray-400 font-normal">(comma-separated)</span>
        </label>
        <input
          type="text"
          value={techniques}
          onChange={(e) => setTechniques(e.target.value)}
          placeholder="e.g. Stir-fry, Dice, Deglaze"
          className="w-full rounded-lg border border-gray-300 px-3 py-2.5 text-sm focus:border-orange-500 focus:outline-none focus:ring-1 focus:ring-orange-500"
        />
      </div>
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1.5">
          Notes <span className="text-gray-400 font-normal">(optional)</span>
        </label>
        <textarea
          rows={3}
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          placeholder="What went well? What would you do differently?"
          className="w-full rounded-lg border border-gray-300 px-3 py-2.5 text-sm focus:border-orange-500 focus:outline-none focus:ring-1 focus:ring-orange-500 resize-none"
        />
      </div>
      <button
        onClick={handleDebrief}
        disabled={!dish.trim() || loading}
        className="w-full rounded-lg bg-orange-500 px-4 py-2.5 text-sm font-semibold text-white hover:bg-orange-600 disabled:opacity-50 transition-colors"
      >
        {loading ? "Generating debrief…" : "Get AI Debrief"}
      </button>
      {error && <p className="text-sm text-red-500 bg-red-50 rounded-lg px-3 py-2">{error}</p>}
      {response && (
        <div className="rounded-xl bg-orange-50 border border-orange-100 px-5 py-4 text-sm text-gray-800 whitespace-pre-wrap leading-relaxed">
          {response}
          {loading && <span className="inline-block w-2 h-4 bg-orange-400 ml-1 animate-pulse rounded-sm" />}
        </div>
      )}
    </div>
  );
}

// ── Main component ────────────────────────────────────────────────────────────
export default function CoachChat({ token }: { token: string }) {
  const [mode, setMode] = useState<Mode>("precook");

  const tabs: { id: Mode; label: string; icon: string }[] = [
    { id: "precook", label: "Pre-Cook", icon: "📋" },
    { id: "chat", label: "Mid-Cook", icon: "💬" },
    { id: "debrief", label: "Post-Cook", icon: "📝" },
  ];

  return (
    <div className="p-8 max-w-3xl mx-auto">
      <h1 className="text-2xl font-bold text-gray-900 mb-2">AI Coach</h1>
      <p className="text-sm text-gray-500 mb-6">
        Personalised advice calibrated to your skill level.
      </p>

      {/* Tab switcher */}
      <div className="flex rounded-xl bg-gray-100 p-1 mb-6">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setMode(tab.id)}
            className={cn(
              "flex-1 rounded-lg px-4 py-2 text-sm font-medium transition-all",
              mode === tab.id
                ? "bg-white text-orange-600 shadow-sm"
                : "text-gray-500 hover:text-gray-700"
            )}
          >
            {tab.icon} {tab.label}
          </button>
        ))}
      </div>

      <div className="rounded-2xl bg-white border border-gray-100 shadow-sm p-6">
        {mode === "precook" && <PreCookTab token={token} />}
        {mode === "chat" && <ChatTab token={token} />}
        {mode === "debrief" && <DebriefTab token={token} />}
      </div>
    </div>
  );
}
