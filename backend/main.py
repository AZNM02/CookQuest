from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import get_client
from routers import auth, profile, sessions, techniques, stats, ai_coach, recipes, recommendations


@asynccontextmanager
async def lifespan(app: FastAPI):
    await get_client()   # initialise Supabase client on startup
    yield


app = FastAPI(title="CookQuest API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(profile.router)
app.include_router(sessions.router)
app.include_router(techniques.router)
app.include_router(stats.router)
app.include_router(ai_coach.router)
app.include_router(recipes.router)
app.include_router(recommendations.router)


@app.get("/health", tags=["meta"])
async def health():
    return {"status": "ok"}
