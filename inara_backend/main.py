"""
HymnChat Backend
FastAPI application with AI chat and HIPAA-compliant features.
"""

import socketio
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

# Import existing chat routes
from api.routes import router as chat_router

# Import new API v1 routes
from api.v1 import router as api_v1_router

# Import database and realtime
from db.mongodb import MongoDB
from db.collections import create_indexes
from realtime.socket_manager import sio
from realtime.events import register_events

# Configuration
from config import settings


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
