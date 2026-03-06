from fastapi import APIRouter, File, UploadFile, Form, HTTPException, Body
from typing import Optional, List
from services.llm_service import LLMService
from services.session_service import SessionService
from api.chat_models import ChatResponse, SessionCreateRequest, SessionResponse, SessionListItem, DeleteResponse

router = APIRouter()
llm_service = LLMService()
session_service = SessionService()

@router.post("/sessions", response_model=SessionResponse)
async def create_session(request: SessionCreateRequest = Body(...)):
    """Creates a new session, optionally linked to a user_id."""
    session_id = await session_service.create_session(request.user_id, request.title)
    # Fetch back to get created_at
    session = await session_service.get_session(session_id)
    return SessionResponse(
        session_id=session_id,
        user_id=request.user_id,
        title=session.get("title"),
        created_at=session["created_at"],
        updated_at=session.get("updated_at"),
        history=[]
    )

@router.get("/sessions/{session_id}", response_model=SessionResponse)
async def get_session(session_id: str):
    """Gets details and history of a specific session."""
    session = await session_service.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    return SessionResponse(
        session_id=session["session_id"],
        user_id=session.get("user_id"),
        title=session.get("title"),
        created_at=session.get("created_at"),
        updated_at=session.get("updated_at"),
        history=session.get("history", [])
    )

@router.delete("/sessions/{session_id}", response_model=DeleteResponse)
async def delete_session(session_id: str):
    """Deletes a session by its ID."""
    deleted = await session_service.delete_session(session_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Session not found")
    return DeleteResponse(success=True, message="Session deleted successfully")

@router.get("/users/{user_id}/sessions", response_model=List[SessionListItem])
async def get_user_sessions(user_id: str):
    """Lists all sessions for a specific user (without full history for performance)."""
    sessions = await session_service.get_user_sessions(user_id)
    return [
        SessionListItem(
            session_id=s["session_id"],
            user_id=s.get("user_id"),
            title=s.get("title", "New Chat"),
            created_at=s.get("created_at"),
            updated_at=s.get("updated_at"),
            message_count=len(s.get("history", []))
        ) for s in sessions
    ]

@router.post("/chat", response_model=ChatResponse)
async def chat_endpoint(
    message: str = Form(...),
    session_id: Optional[str] = Form(None),
    user_id: Optional[str] = Form(None),
    file: Optional[UploadFile] = File(None)
):
    """
    Endpoint to chat with the AI.
    Accepts 'message', optional 'session_id', optional 'user_id', and an optional 'file'.
    If session_id is not provided but user_id is, creates a new session linked to the user.
    Persistence: Stores conversation (including images) in underlying MongoDB.
    """
    try:
        # Create new session if not provided
        if not session_id:
            session_id = await session_service.create_session(user_id=user_id)
        
        # Get history
        history = await session_service.get_history(session_id)

        image_data = None
        mime_type = None

        if file:
            if file.content_type and file.content_type.startswith("image/"):
                image_data = await file.read()
                mime_type = file.content_type

        # Generate response using history
        response_text = await llm_service.generate_response(message, history, image_data, mime_type)
        
        # Update history with new turn
        # Store USER message with image (if any)
        await session_service.add_message(session_id, "user", message, image_data, mime_type)
        
        # Store MODEL response
        await session_service.add_message(session_id, "model", response_text)
        
        # Generate title after first exchange (user + model response)
        if await session_service.should_generate_title(session_id):
            title = await llm_service.generate_title(message, response_text)
            await session_service.update_session_title(session_id, title)

        return ChatResponse(response=response_text, session_id=session_id)

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
