"""
MongoDB connection management using Motor (async driver).
"""

from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase
from typing import Optional

from config import settings


class MongoDB:
    """MongoDB connection manager."""

    client: Optional[AsyncIOMotorClient] = None
    database: Optional[AsyncIOMotorDatabase] = None

    @classmethod
    async def connect(cls) -> None:
        """Establish MongoDB connection."""
        if cls.client is None:
            mongo_url = settings.get_mongodb_url
            cls.client = AsyncIOMotorClient(mongo_url)
            cls.database = cls.client[settings.mongodb_database]
            # Verify connection
            await cls.client.admin.command("ping")
            print(f"✅ Connected to MongoDB: {settings.mongodb_database}")

    @classmethod
    async def disconnect(cls) -> None:
        """Close MongoDB connection."""
        if cls.client is not None:
            cls.client.close()
            cls.client = None
            cls.database = None
            print("Disconnected from MongoDB")

    @classmethod
    def get_database(cls) -> AsyncIOMotorDatabase:
        """Get database instance."""
        if cls.database is None:
            raise RuntimeError("Database not connected. Call connect() first.")
        return cls.database


# Convenience function
def get_db() -> AsyncIOMotorDatabase:
    """Get database instance for dependency injection."""
    return MongoDB.get_database()
