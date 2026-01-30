from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

class ChatRequest(BaseModel):
    message: str
    session_id: Optional[str] = None

class ChatResponse(BaseModel):
    response: str
    session_id: str

class SessionCreateRequest(BaseModel):
    user_id: Optional[str] = None
    title: Optional[str] = None

class SessionResponse(BaseModel):
    session_id: str
    user_id: Optional[str] = None
    title: Optional[str] = None
    created_at: datetime
    updated_at: Optional[datetime] = None
    history: Optional[List[dict]] = None

class SessionListItem(BaseModel):
    """Lightweight session info for listing (without full history)."""
    session_id: str
    user_id: Optional[str] = None
    title: Optional[str] = None
    created_at: datetime
    updated_at: Optional[datetime] = None
    message_count: int = 0

class DeleteResponse(BaseModel):
    success: bool
    message: str
