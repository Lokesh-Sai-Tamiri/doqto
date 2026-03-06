"""
HymnChat Backend
FastAPI application with AI chat and HIPAA-compliant features.
"""

import asyncio
import logging
import socketio
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

# Configuration
from config import settings

# Import existing chat routes
from api.routes import router as chat_router

# Rate limiting
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

# Initialize limiter
limiter = Limiter(key_func=get_remote_address, default_limits=[f"{settings.rate_limit_requests}/{settings.rate_limit_window} seconds"])

# Import new API v1 routes
from api.v1 import router as api_v1_router

# Import database and realtime
from db.mongodb import MongoDB
from db.collections import create_indexes
from realtime.socket_manager import sio
from realtime.events import register_events
from services.messaging_service import MessagingService


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager for startup/shutdown events."""
    # Startup
    print(f"🚀 Starting {settings.app_name} v{settings.app_version}")

    # Connect to MongoDB
    await MongoDB.connect()

    # Create indexes
    await create_indexes()

    # Register Socket.io events
    register_events()

    # Background job: hard-delete expired disappearing messages every 5 minutes
    async def _message_cleanup_loop():
        while True:
            await asyncio.sleep(300)
            try:
                n = await MessagingService.delete_expired_messages()
                if n > 0:
                    print(f"Deleted {n} expired messages")
            except Exception as e:
                logging.error(f"Message cleanup error: {e}")

    asyncio.create_task(_message_cleanup_loop())

    print("✅ Application started successfully")

    yield

    # Shutdown
    print("👋 Shutting down...")
    await MongoDB.disconnect()
    print("Application stopped")


# Create FastAPI app
app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="HymnChat API - Healthcare Communication Platform with AI",
    lifespan=lifespan,
)

# Apply rate limiting
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include existing chat routes (AI features)
app.include_router(chat_router, prefix="/api", tags=["AI Chat"])

# Include new API v1 routes (profiles, messaging, connections, organizations)
app.include_router(api_v1_router)


# Health check endpoint
@app.get("/")
def read_root():
    return {"status": "online", "service": settings.app_name, "version": settings.app_version}


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "app": settings.app_name,
        "version": settings.app_version,
    }


# Mount Socket.io ASGI app
socket_app = socketio.ASGIApp(sio, app)


# For running with uvicorn
def create_app():
    """Factory function for creating the app."""
    return socket_app


if __name__ == "__main__":
    uvicorn.run(
        "main:socket_app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
    )
