# CookQuest 🍳

A full-stack cooking skill tracker that helps you grow as a home chef. Log sessions, track technique proficiency, get AI-powered coaching, and discover recipes tailored to your skill gaps.

**Live demo:** [cookquest.vercel.app](https://cook-quest-omega.vercel.app) · **Mobile:** Android APK (sideload)

---

## Features

- **Dashboard** — XP level, cooking streak, session history, and progress stats at a glance
- **Session Logger** — log a cook with dish name, cuisine, techniques used, difficulty, and self-rating; earns XP and updates proficiency automatically
- **Skills Analytics** — proficiency bar chart for your top techniques, cuisine diversity radar chart, GitHub-style cooking activity heatmap, and a full technique list sorted weakest-first
- **Recipe Library** — searchable, filterable recipe library with favorites; "Discover more" imports new recipes from the AI
- **Recommended Recipes** — surfaces recipes that target your weakest techniques, personalised per user
- **AI Coach** — three modes powered by Claude Sonnet:
  - **Pre-Cook** — pick a recipe and get a personalised walkthrough before you start
  - **Mid-Cook** — live chat assistant for questions while you cook
  - **Post-Cook** — submit your session details and get a structured debrief with improvement tips
- **Badges & XP** — gamified progression system with badges awarded for milestones
- **Cross-platform** — identical feature set on web (Next.js) and Android (Flutter)

---

## Tech Stack

| Layer | Technology |
|---|---|
| Web frontend | Next.js 14 (App Router), Tailwind CSS, Recharts |
| Mobile | Flutter 3 (Android) |
| Backend API | FastAPI (Python) |
| Database & Auth | Supabase (PostgreSQL + Row Level Security) |
| AI | Anthropic Claude Sonnet (streaming SSE) |
| Deployment | Vercel (web), Railway (API), Supabase Cloud |

---

## Project Structure

```
cookquest/
├── web/          # Next.js web app
├── mobile/       # Flutter Android app
└── backend/      # FastAPI REST API
```

---

## Running Locally

### Backend
```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload
```

Requires a `.env` file with:
```
SUPABASE_URL=...
SUPABASE_SERVICE_KEY=...
ANTHROPIC_API_KEY=...
```

### Web
```bash
cd web
npm install
npm run dev
```

Requires a `.env.local` file with:
```
NEXT_PUBLIC_SUPABASE_URL=...
NEXT_PUBLIC_SUPABASE_ANON_KEY=...
NEXT_PUBLIC_API_URL=http://localhost:8000
```

### Mobile
```bash
cd mobile
flutter run
```

Update `lib/config.dart` with your local API URL before running.

---

## Deployment

- **API** → [Railway](https://railway.app): set root directory to `backend/`, add env vars, generate domain
- **Web** → [Vercel](https://vercel.com): set root directory to `web/`, add env vars including `NEXT_PUBLIC_API_URL`
- **Android APK** → `flutter build apk --release`, update `config.dart` with the Railway URL first
