import json
from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import Optional
from database import get_client
from dependencies import get_current_user
from services.ai_service import get_anthropic_client, build_system_prompt

router = APIRouter(prefix="/ai", tags=["ai"])

MODEL = "claude-sonnet-4-6"


class Message(BaseModel):
    role: str   # "user" | "assistant"
    content: str


class PreCookRequest(BaseModel):
    recipe_name: str
    recipe_description: Optional[str] = None
    recipe_instructions: Optional[str] = None


class ChatRequest(BaseModel):
    messages: list[Message]
    recipe_name: Optional[str] = None


class DebriefRequest(BaseModel):
    dish_name: str
    cuisine_type: str
    self_rating: int
    difficulty_felt: int
    technique_names: list[str]
    notes: Optional[str] = None


async def _stream_response(system: str, messages: list[dict]):
    """Yield SSE-formatted chunks from a streaming Claude response."""
    anthropic = get_anthropic_client()
    async with anthropic.messages.stream(
        model=MODEL,
        max_tokens=1024,
        system=system,
        messages=messages,
    ) as stream:
        async for text in stream.text_stream:
            yield f"data: {json.dumps({'text': text})}\n\n"
    yield "data: [DONE]\n\n"


@router.post("/precook")
async def precook(body: PreCookRequest, user_id: str = Depends(get_current_user)):
    """Pre-cook walkthrough: explain the recipe and give personalised tips."""
    db = await get_client()
    system = await build_system_prompt(db, user_id)

    content = f"I'm about to cook: **{body.recipe_name}**."
    if body.recipe_description:
        content += f"\n\nDescription: {body.recipe_description}"
    if body.recipe_instructions:
        content += f"\n\nInstructions:\n{body.recipe_instructions}"
    content += "\n\nPlease give me a personalised pre-cook walkthrough — what to prep, key technique tips, and anything to watch out for given my skill level."

    messages = [{"role": "user", "content": content}]
    return StreamingResponse(
        _stream_response(system, messages),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


@router.post("/chat")
async def chat(body: ChatRequest, user_id: str = Depends(get_current_user)):
    """Mid-cook Q&A — stateless, caller passes full message history."""
    db = await get_client()
    system = await build_system_prompt(db, user_id)

    if body.recipe_name:
        system += f"\n\nThe user is currently cooking: {body.recipe_name}."

    messages = [{"role": m.role, "content": m.content} for m in body.messages]
    return StreamingResponse(
        _stream_response(system, messages),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


@router.post("/debrief")
async def debrief(body: DebriefRequest, user_id: str = Depends(get_current_user)):
    """Post-cook AI debrief given session data."""
    db = await get_client()
    system = await build_system_prompt(db, user_id)

    techniques_str = ", ".join(body.technique_names) if body.technique_names else "none specified"
    content = (
        f"I just finished cooking **{body.dish_name}** ({body.cuisine_type} cuisine).\n\n"
        f"- Self-rating: {body.self_rating}/5\n"
        f"- Difficulty felt: {body.difficulty_felt}/5\n"
        f"- Techniques used: {techniques_str}\n"
    )
    if body.notes:
        content += f"- My notes: {body.notes}\n"
    content += "\nPlease give me a personalised debrief: what I did well, what to improve, and a specific tip for next time."

    messages = [{"role": "user", "content": content}]
    return StreamingResponse(
        _stream_response(system, messages),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
