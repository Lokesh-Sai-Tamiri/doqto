"""
Centralized configuration for HymnChat API Backend.
Uses pydantic-settings for environment variable management.
"""

from functools import lru_cache
from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Application
    app_name: str = "HymnChat API"
    app_version: str = "1.0.0"
    debug: bool = True

    # Server
    host: str = "0.0.0.0"
    port: int = 8000

    # AI Services
    google_api_key: Optional[str] = None
    openai_api_key: Optional[str] = None

    # MongoDB - supports both MONGO_URI and mongodb_url
    mongo_uri: Optional[str] = None
    mongodb_url: Optional[str] = None
    mongodb_database: str = "hymn-chat"

    @property
    def get_mongodb_url(self) -> str:
        """Get MongoDB URL from either env var."""
        return self.mongo_uri or self.mongodb_url or "mongodb://localhost:27017"

    # Supabase (for JWT verification)
    supabase_url: Optional[str] = None
    supabase_jwt_secret: Optional[str] = None  # If using HS256
    supabase_project_ref: Optional[str] = None  # For JWKS URL construction

    # AWS S3
    aws_access_key_id: Optional[str] = None
    aws_secret_access_key: Optional[str] = None
    aws_region: str = "us-east-1"
    s3_bucket_avatars: str = "hymnchat-avatars"
    s3_bucket_attachments: str = "hymnchat-attachments"
    s3_bucket_org_logos: str = "hymnchat-org-logos"
    s3_presigned_url_expiry: int = 3600  # 1 hour

    # CORS
    cors_origins: list[str] = ["*"]

    # Rate limiting
    rate_limit_requests: int = 100
    rate_limit_window: int = 60  # seconds

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()


# Export settings instance for convenience
settings = get_settings()
