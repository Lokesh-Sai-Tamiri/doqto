"""
Supabase JWT Authentication Middleware.
Verifies JWT tokens from Supabase Auth on all protected API requests.
"""

import httpx
import jwt
from jwt import PyJWKClient
from datetime import datetime, timezone
from typing import Optional
from functools import lru_cache
from pydantic import BaseModel

from fastapi import HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from config import settings


# Security scheme for Swagger UI
security = HTTPBearer()


class AuthUser(BaseModel):
    """Authenticated user information extracted from JWT."""
    user_id: str
    email: Optional[str] = None
    phone: Optional[str] = None
    role: str = "authenticated"
    aud: str = "authenticated"


class SupabaseJWTVerifier:
    """Handles Supabase JWT verification with JWKS caching."""

    def __init__(self):
        self._jwks_client: Optional[PyJWKClient] = None
        self._jwks_url: Optional[str] = None

    def _get_jwks_url(self) -> Optional[str]:
        """Construct JWKS URL from Supabase URL."""
        # Supabase URL format: https://<project-ref>.supabase.co
        # JWKS URL: https://<project-ref>.supabase.co/auth/v1/.well-known/jwks.json
        if not settings.supabase_url:
            return None
        base_url = settings.supabase_url.rstrip("/")
        return f"{base_url}/auth/v1/.well-known/jwks.json"

    @property
    def jwks_client(self) -> Optional[PyJWKClient]:
        """Get or create cached JWKS client."""
        if self._jwks_client is None:
            self._jwks_url = self._get_jwks_url()
            if self._jwks_url is None:
                return None
            self._jwks_client = PyJWKClient(
                self._jwks_url,
                cache_keys=True,
                lifespan=3600,  # Cache keys for 1 hour
            )
        return self._jwks_client

    async def verify_token(self, token: str) -> AuthUser:
        """
        Verify a Supabase JWT token and extract user information.

        Args:
            token: The JWT token from the Authorization header

        Returns:
            AuthUser with extracted user information

        Raises:
            HTTPException: If token is invalid or expired
        """
        try:
            # First, try RS256 verification with JWKS
            try:
                jwks = self.jwks_client
                if jwks is None:
                    raise jwt.exceptions.PyJWKClientError("JWKS client not configured")
                signing_key = jwks.get_signing_key_from_jwt(token)
                payload = jwt.decode(
                    token,
                    signing_key.key,
                    algorithms=["RS256"],
                    audience="authenticated",
                    options={
                        "verify_exp": True,
                        "verify_aud": True,
                        "require": ["sub", "exp", "aud"],
                    }
                )
            except (jwt.exceptions.PyJWKClientError, AttributeError, Exception) as e:
                # Fallback to HS256 if JWKS fails and we have a secret
                if settings.supabase_jwt_secret:
                    payload = jwt.decode(
                        token,
                        settings.supabase_jwt_secret,
                        algorithms=["HS256"],
                        audience="authenticated",
                        options={
                            "verify_exp": True,
                            "verify_aud": True,
                            "require": ["sub", "exp", "aud"],
                        }
                    )
                elif settings.debug:
                    # DEVELOPMENT MODE: Decode without verification
                    # WARNING: Only use this in local development!
                    print("⚠️  DEV MODE: Decoding JWT without signature verification")
                    payload = jwt.decode(
                        token,
                        options={
                            "verify_signature": False,
                            "verify_exp": True,
                            "verify_aud": False,
                            "require": ["sub"],
                        }
                    )
                else:
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail="Unable to verify token: JWKS unavailable and no JWT secret configured",
                        headers={"WWW-Authenticate": "Bearer"},
                    )

            # Check token expiration explicitly
            exp = payload.get("exp")
            if exp and datetime.fromtimestamp(exp, tz=timezone.utc) < datetime.now(timezone.utc):
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Token has expired",
                    headers={"WWW-Authenticate": "Bearer"},
                )

            # Extract user information
            return AuthUser(
                user_id=payload.get("sub"),
                email=payload.get("email"),
                phone=payload.get("phone"),
                role=payload.get("role", "authenticated"),
                aud=payload.get("aud", "authenticated"),
            )

        except jwt.ExpiredSignatureError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token has expired",
                headers={"WWW-Authenticate": "Bearer"},
            )
        except jwt.InvalidAudienceError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token audience",
                headers={"WWW-Authenticate": "Bearer"},
            )
        except jwt.InvalidTokenError as e:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid token: {str(e)}",
                headers={"WWW-Authenticate": "Bearer"},
            )
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Token verification failed: {str(e)}",
                headers={"WWW-Authenticate": "Bearer"},
            )


# Global verifier instance
_verifier = SupabaseJWTVerifier()


async def verify_supabase_token(token: str) -> AuthUser:
    """
    Verify a Supabase JWT token.

    Args:
        token: The JWT token string

    Returns:
        AuthUser with user information
    """
    return await _verifier.verify_token(token)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> AuthUser:
    """
    FastAPI dependency to get the current authenticated user.

    Usage:
        @router.get("/protected")
        async def protected_route(user: AuthUser = Depends(get_current_user)):
            return {"user_id": user.user_id}
    """
    return await verify_supabase_token(credentials.credentials)


# Optional: Dependency that allows unauthenticated access
async def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(
        HTTPBearer(auto_error=False)
    )
) -> Optional[AuthUser]:
    """
    FastAPI dependency for optional authentication.
    Returns None if no token provided, AuthUser if valid token.
    """
    if credentials is None:
        return None
    try:
        return await verify_supabase_token(credentials.credentials)
    except HTTPException:
        return None
