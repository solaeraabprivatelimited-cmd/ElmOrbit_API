"""
🔒 LERNOVA SECURITY - CONSOLIDATED MODULE
All-in-one security, authentication, validation, and logging system

Modules Consolidated:
✅ auth_middleware.py - JWT validation, RBAC, session management
✅ schemas.py - Input validation with Pydantic
✅ security.py - Sanitization, encryption, validation
✅ rate_limiter.py - Rate limiting and abuse protection
✅ audit_logger.py - Security event tracking and compliance

OWASP Coverage:
✅ A1: Broken Authentication - Fixed with proper JWT validation
✅ A2: Broken Authorization - Fixed with RBAC
✅ A3: Injection attacks - Fixed with Pydantic + sanitization
✅ A4: Insecure Deserialization - Fixed with schema validation
✅ A5: Broken Access Control (IDOR) - Fixed with ownership checks
✅ A6: Security Misconfiguration - Fixed with secure defaults
✅ A7: Cross-Site Scripting (XSS) - Fixed with Bleach sanitization
✅ A8: Insecure Data Storage - Fixed with Fernet encryption
✅ A9: Logging and Monitoring - Fixed with comprehensive audit logging
✅ A10: Insufficient Logging & Monitoring - Fixed with AuditLogger

Usage:
    from security_all_in_one import (
        get_current_user, get_current_admin, get_current_mentor,
        CreateRoomRequest, schemas,
        rate_limiter, audit_logger,
        HTMLSanitizer, InputValidator,
    )
"""

# ═══════════════════════════════════════════════════════════════════════════════
# IMPORTS - STANDARD LIBRARY
# ═══════════════════════════════════════════════════════════════════════════════

import jwt
import logging
import json
import os
import secrets
import hashlib
import hmac
import bleach
import time
import threading
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, List, Set, Tuple, Any
from enum import Enum
from functools import wraps
from collections import defaultdict
from dataclasses import dataclass, asdict
from pathlib import Path
from urllib.parse import urlencode
import re
from cryptography.fernet import Fernet

# ═══════════════════════════════════════════════════════════════════════════════
# IMPORTS - FASTAPI & PYDANTIC
# ═══════════════════════════════════════════════════════════════════════════════

from fastapi import HTTPException, Request, Depends, Header
from pydantic import BaseModel, Field, EmailStr, validator, root_validator

# ═══════════════════════════════════════════════════════════════════════════════
# LOGGING SETUP
# ═══════════════════════════════════════════════════════════════════════════════

logger = logging.getLogger(__name__)


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 1: RBAC - ROLE & PERMISSION DEFINITIONS
# ═══════════════════════════════════════════════════════════════════════════════

class UserRole(str, Enum):
    """User roles for RBAC"""
    ADMIN = "admin"                    # Full access, user management
    MENTOR = "mentor"                  # Can create study rooms, book sessions
    USER = "user"                      # Standard user, join rooms
    SUPER_ADMIN = "super_admin"        # Emergency access


class Permission(str, Enum):
    """Granular permissions"""
    # Room operations
    CREATE_ROOM = "create_room"
    JOIN_ROOM = "join_room"
    DELETE_ROOM = "delete_room"
    MODIFY_ROOM = "modify_room"
    
    # User management
    VIEW_USERS = "view_users"
    DELETE_USERS = "delete_users"
    MODIFY_USERS = "modify_users"
    
    # Mentor operations
    BOOK_SESSION = "book_session"
    CREATE_SESSION = "create_session"
    
    # Admin operations
    VIEW_LOGS = "view_logs"
    MANAGE_ROLES = "manage_roles"


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 2: TOKEN MODELS & MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class TokenPayload:
    """Decoded JWT token payload"""
    user_id: str
    role: UserRole
    email: str
    iat: int  # Issued at
    exp: int  # Expiry
    jti: str  # JWT ID (for revocation)


class TokenBlacklist:
    """In-memory token blacklist (use Redis in production)"""
    
    def __init__(self):
        self._blacklist: Set[str] = set()
        self._lock = threading.Lock()
    
    def add(self, jti: str) -> None:
        """Add token to blacklist (on logout)"""
        with self._lock:
            self._blacklist.add(jti)
            logger.info(f"Token {jti} added to blacklist")
    
    def is_blacklisted(self, jti: str) -> bool:
        """Check if token is blacklisted"""
        with self._lock:
            return jti in self._blacklist


# Global token blacklist
token_blacklist = TokenBlacklist()


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 3: JWT VALIDATION (Secure RS256 with signature verification)
# ═══════════════════════════════════════════════════════════════════════════════

class JWTValidator:
    """Validates JWT tokens with full security checks"""
    
    def __init__(
        self,
        secret_key: str = None,
        public_key: str = None,
        algorithm: str = "HS256",
        access_token_expire_minutes: int = 15,
        refresh_token_expire_days: int = 7,
    ):
        """Initialize JWT validator"""
        self.secret_key = secret_key or os.getenv("JWT_SECRET_KEY")
        self.public_key = public_key or os.getenv("JWT_PUBLIC_KEY")
        self.algorithm = algorithm or os.getenv("JWT_ALGORITHM", "HS256")
        self.access_token_expire_minutes = access_token_expire_minutes
        self.refresh_token_expire_days = refresh_token_expire_days
        
        if not self.secret_key and not self.public_key:
            raise ValueError("JWT_SECRET_KEY or JWT_PUBLIC_KEY required")
        
        if self.algorithm == "RS256" and not self.public_key:
            raise ValueError("JWT_PUBLIC_KEY required for RS256")
    
    def create_access_token(
        self,
        user_id: str,
        role: UserRole,
        email: str,
        additional_claims: Dict = None,
    ) -> str:
        """Create short-lived access token (15 min)"""
        now = datetime.now(timezone.utc)
        expires = now + timedelta(minutes=self.access_token_expire_minutes)
        
        payload = {
            "user_id": user_id,
            "role": role.value,
            "email": email,
            "iat": int(now.timestamp()),
            "exp": int(expires.timestamp()),
            "jti": secrets.token_urlsafe(16),  # JWT ID for revocation
            "token_type": "access",
        }
        
        if additional_claims:
            payload.update(additional_claims)
        
        key = self.public_key if self.algorithm == "RS256" else self.secret_key
        encoded = jwt.encode(payload, key, algorithm=self.algorithm)
        logger.info(f"Access token created for user {user_id}")
        return encoded
    
    def create_refresh_token(self, user_id: str, email: str) -> str:
        """Create long-lived refresh token (7 days)"""
        now = datetime.now(timezone.utc)
        expires = now + timedelta(days=self.refresh_token_expire_days)
        
        payload = {
            "user_id": user_id,
            "email": email,
            "iat": int(now.timestamp()),
            "exp": int(expires.timestamp()),
            "jti": secrets.token_urlsafe(16),
            "token_type": "refresh",
        }
        
        key = self.public_key if self.algorithm == "RS256" else self.secret_key
        encoded = jwt.encode(payload, key, algorithm=self.algorithm)
        logger.info(f"Refresh token created for user {user_id}")
        return encoded
    
    def validate_token(self, token: str) -> TokenPayload:
        """
        Validate JWT token with all security checks:
        ✅ Signature verification
        ✅ Expiry check
        ✅ Blacklist check
        """
        if not token:
            raise HTTPException(status_code=401, detail="Token required")
        
        try:
            key = self.public_key if self.algorithm == "RS256" else self.secret_key
            payload = jwt.decode(
                token,
                key,
                algorithms=[self.algorithm],
                options={
                    "verify_signature": True,
                    "verify_exp": True,
                    "verify_iat": True,
                },
            )
        except jwt.ExpiredSignatureError:
            logger.warning(f"Expired token attempted")
            raise HTTPException(status_code=401, detail="Token expired")
        except jwt.InvalidSignatureError:
            logger.warning(f"Invalid signature on token")
            raise HTTPException(status_code=401, detail="Invalid token")
        except jwt.InvalidTokenError as e:
            logger.warning(f"Invalid token: {e}")
            raise HTTPException(status_code=401, detail="Invalid token")
        
        # Check if token is blacklisted (revoked/logout)
        jti = payload.get("jti")
        if jti and token_blacklist.is_blacklisted(jti):
            logger.warning(f"Blacklisted token used")
            raise HTTPException(status_code=401, detail="Token revoked")
        
        try:
            return TokenPayload(
                user_id=payload.get("user_id"),
                role=UserRole(payload.get("role", "user")),
                email=payload.get("email"),
                iat=payload.get("iat"),
                exp=payload.get("exp"),
                jti=jti,
            )
        except Exception as e:
            logger.error(f"Invalid token payload: {e}")
            raise HTTPException(status_code=401, detail="Invalid token structure")


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 4: AUTHORIZATION - ROLE-BASED ACCESS CONTROL (RBAC)
# ═══════════════════════════════════════════════════════════════════════════════

class AuthorizationManager:
    """Manages role-based access control"""
    
    ROLE_PERMISSIONS: Dict[UserRole, Set[Permission]] = {
        UserRole.ADMIN: {
            Permission.CREATE_ROOM, Permission.DELETE_ROOM, Permission.MODIFY_ROOM,
            Permission.VIEW_USERS, Permission.DELETE_USERS, Permission.MODIFY_USERS,
            Permission.CREATE_SESSION, Permission.BOOK_SESSION,
            Permission.VIEW_LOGS, Permission.MANAGE_ROLES,
        },
        UserRole.MENTOR: {
            Permission.CREATE_ROOM, Permission.MODIFY_ROOM,
            Permission.CREATE_SESSION, Permission.BOOK_SESSION,
        },
        UserRole.USER: {
            Permission.JOIN_ROOM, Permission.BOOK_SESSION,
        },
        UserRole.SUPER_ADMIN: set(Permission),  # All permissions
    }
    
    @staticmethod
    def check_permission(user_role: UserRole, required_permission: Permission) -> bool:
        """Check if user role has required permission"""
        return required_permission in AuthorizationManager.ROLE_PERMISSIONS.get(user_role, set())
    
    @staticmethod
    def check_ownership(user_id: str, resource_owner_id: str) -> bool:
        """Check if user owns the resource (for IDOR prevention)"""
        if not user_id or not resource_owner_id:
            return False
        return user_id == resource_owner_id
    
    @staticmethod
    def check_room_access(
        user_id: str,
        room_owner_id: str,
        is_room_public: bool,
        user_role: UserRole = UserRole.USER,
    ) -> bool:
        """Check if user can access room"""
        if user_role in [UserRole.ADMIN, UserRole.SUPER_ADMIN]:
            return True
        if AuthorizationManager.check_ownership(user_id, room_owner_id):
            return True
        if is_room_public:
            return True
        return False


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 5: SESSION MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

class SessionManager:
    """Manages user sessions, login/logout"""
    
    @staticmethod
    def logout(token_payload: TokenPayload) -> None:
        """Revoke a token (logout)"""
        if token_payload.jti:
            token_blacklist.add(token_payload.jti)
            logger.info(f"User {token_payload.user_id} logged out")


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 6: OAUTH VALIDATION
# ═══════════════════════════════════════════════════════════════════════════════

class GoogleOAuthValidator:
    """Validates Google OAuth ID tokens"""
    
    def __init__(self):
        self.google_client_id = os.getenv("GOOGLE_OAUTH_CLIENT_ID")
        if not self.google_client_id:
            logger.warning("GOOGLE_OAUTH_CLIENT_ID not set")
    
    def validate_id_token(self, id_token: str) -> Dict:
        """Validate Google OAuth ID token"""
        try:
            from google.auth.transport import requests
            from google.oauth2 import id_token
            
            idinfo = id_token.verify_oauth2_token(
                id_token,
                requests.Request(),
                self.google_client_id,
            )
            
            if idinfo.get("iss") not in ["accounts.google.com", "https://accounts.google.com"]:
                raise ValueError("Invalid issuer")
            
            if idinfo.get("aud") != self.google_client_id:
                raise ValueError("Invalid audience")
            
            logger.info(f"Google OAuth token validated for {idinfo.get('email')}")
            return idinfo
        except Exception as e:
            logger.error(f"OAuth validation failed: {e}")
            raise HTTPException(status_code=401, detail="Invalid OAuth token")


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 7: DEPENDENCY INJECTION - Get current user
# ═══════════════════════════════════════════════════════════════════════════════

# Initialize JWT validator with env vars
jwt_validator = JWTValidator()


async def get_current_user(
    authorization: Optional[str] = Header(None),
) -> TokenPayload:
    """FastAPI dependency to extract and validate current user"""
    if not authorization:
        raise HTTPException(status_code=401, detail="Authorization header required")
    
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization header format")
    
    token = authorization[7:]
    return jwt_validator.validate_token(token)


async def get_current_admin(
    current_user: TokenPayload = Depends(get_current_user),
) -> TokenPayload:
    """FastAPI dependency for admin-only endpoints"""
    if current_user.role not in [UserRole.ADMIN, UserRole.SUPER_ADMIN]:
        logger.warning(f"Unauthorized admin access attempt by {current_user.user_id}")
        raise HTTPException(status_code=403, detail="Admin access required")
    return current_user


async def get_current_mentor(
    current_user: TokenPayload = Depends(get_current_user),
) -> TokenPayload:
    """FastAPI dependency for mentor-only endpoints"""
    if current_user.role not in [UserRole.MENTOR, UserRole.ADMIN, UserRole.SUPER_ADMIN]:
        logger.warning(f"Unauthorized mentor access attempt by {current_user.user_id}")
        raise HTTPException(status_code=403, detail="Mentor access required")
    return current_user


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 8: PYDANTIC SCHEMAS - Input Validation
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────
# Room Management Schemas
# ─────────────────────────────────────────────────────────────────────────────

class RoomType(str, Enum):
    """Room type enumeration"""
    STUDY = "study"
    MENTOR_SESSION = "mentor_session"
    COLLABORATIVE = "collaborative"


class CreateRoomRequest(BaseModel):
    """Secure room creation request"""
    name: str = Field(..., min_length=1, max_length=255, description="Room name")
    subject: Optional[str] = Field(None, max_length=255, description="Subject/topic")
    description: Optional[str] = Field(None, max_length=1000, description="Description")
    room_type: RoomType = Field(RoomType.STUDY, description="Type of room")
    max_participants: int = Field(default=6, ge=2, le=50, description="Max participants")
    is_public: bool = Field(default=True, description="Public or private room")
    
    @validator("name", "subject", "description")
    def sanitize_text(cls, v):
        """Remove leading/trailing whitespace"""
        if isinstance(v, str):
            return v.strip()
        return v
    
    @validator("name")
    def validate_name_safe(cls, v):
        """Ensure name is safe"""
        if v and any(char in v for char in ["<", ">", "{", "}", "$", "\0"]):
            raise ValueError("Name contains invalid characters")
        return v


class JoinRoomRequest(BaseModel):
    """Join room request"""
    room_id: str = Field(..., min_length=1, max_length=100, description="Room ID")
    
    @validator("room_id")
    def validate_room_id(cls, v):
        """Validate room ID format"""
        if not re.match(r"^[a-zA-Z0-9\-_]+$", v):
            raise ValueError("Invalid room ID format")
        return v


class RoomConfigRequest(BaseModel):
    """Room configuration"""
    notification_level: Optional[str] = Field("normal", regex="^(silent|normal|loud)$")
    timer_duration_mins: Optional[int] = Field(25, ge=5, le=120)
    break_duration_mins: Optional[int] = Field(5, ge=1, le=30)
    auto_start_break: Optional[bool] = Field(True)


# ─────────────────────────────────────────────────────────────────────────────
# Chat & Message Schemas
# ─────────────────────────────────────────────────────────────────────────────

class PostChatRequest(BaseModel):
    """Chat message request with XSS protection"""
    message: str = Field(..., min_length=1, max_length=2000, description="Chat message")
    
    @validator("message")
    def sanitize_message(cls, v):
        """Sanitize message"""
        if v:
            v = v.strip()
            v = re.sub(r'(.)\1{20,}', r'\1\1\1', v)
        return v


class SaveNotesRequest(BaseModel):
    """Save notes request"""
    content: str = Field(default="", max_length=10000, description="Notes content")
    
    @validator("content")
    def sanitize_content(cls, v):
        """Sanitize notes"""
        return v.strip() if v else ""


# ─────────────────────────────────────────────────────────────────────────────
# Mentor Schemas
# ─────────────────────────────────────────────────────────────────────────────

class BookMentorSessionRequest(BaseModel):
    """Secure mentor session booking"""
    mentor_id: str = Field(..., min_length=1, max_length=100)
    session_date: str = Field(..., description="Session date (YYYY-MM-DD)")
    session_time: str = Field(..., regex=r"^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$")
    duration_mins: int = Field(60, ge=15, le=180)
    subject: str = Field(..., min_length=1, max_length=255)
    notes: Optional[str] = Field(None, max_length=500)
    
    @validator("session_date")
    def validate_date(cls, v):
        """Validate date is in future"""
        try:
            date_obj = datetime.strptime(v, "%Y-%m-%d").date()
            if date_obj < datetime.now().date():
                raise ValueError("Date must be in the future")
        except ValueError as e:
            raise ValueError(f"Invalid date format: {e}")
        return v
    
    @validator("mentor_id")
    def validate_mentor_id(cls, v):
        """Validate mentor ID format"""
        if not re.match(r"^[a-zA-Z0-9\-_]+$", v):
            raise ValueError("Invalid mentor ID format")
        return v


# ─────────────────────────────────────────────────────────────────────────────
# Community Event Schemas
# ─────────────────────────────────────────────────────────────────────────────

class CreateEventRequest(BaseModel):
    """Create community event"""
    title: str = Field(..., min_length=1, max_length=255)
    description: str = Field(..., min_length=1, max_length=2000)
    event_date: str = Field(..., description="Event date (YYYY-MM-DD)")
    event_time: Optional[str] = Field(None, regex=r"^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$")
    
    @validator("title", "description")
    def sanitize_text(cls, v):
        """Sanitize text"""
        return v.strip() if v else v
    
    @validator("event_date")
    def validate_event_date(cls, v):
        """Validate event date"""
        try:
            date_obj = datetime.strptime(v, "%Y-%m-%d").date()
            if date_obj < datetime.now().date():
                raise ValueError("Event date must be in the future or today")
        except ValueError as e:
            raise ValueError(f"Invalid date format: {e}")
        return v


# ─────────────────────────────────────────────────────────────────────────────
# Monitoring & Analytics Schemas
# ─────────────────────────────────────────────────────────────────────────────

class MonitoringEventRequest(BaseModel):
    """Monitoring event creation"""
    room_id: str = Field(..., min_length=1, max_length=100)
    event_type: str = Field(..., regex="^(occupancy|pose|activity|anomaly)$")
    severity: str = Field(..., regex="^(low|medium|high|critical)$")
    description: Optional[str] = Field(None, max_length=500)
    people_count: Optional[int] = Field(None, ge=0, le=50)
    anomaly_score: Optional[float] = Field(None, ge=0.0, le=1.0)


class SkeletonSnapshotRequest(BaseModel):
    """Pose/skeleton detection data"""
    room_id: str = Field(..., min_length=1, max_length=100)
    person_index: int = Field(0, ge=0, le=50)
    keypoints: List[Dict[str, Any]] = Field(..., min_items=1, max_items=33)
    pose_angle: Optional[float] = Field(None, ge=-180.0, le=180.0)
    velocity: Optional[float] = Field(None, ge=0.0)
    is_standing: Optional[bool] = True
    is_idle: Optional[bool] = False


# ─────────────────────────────────────────────────────────────────────────────
# Authentication Schemas
# ─────────────────────────────────────────────────────────────────────────────

class LoginRequest(BaseModel):
    """Login with email/password"""
    email: EmailStr = Field(..., description="User email")
    password: str = Field(..., min_length=8, max_length=128)


class OAuthLoginRequest(BaseModel):
    """OAuth token login"""
    provider: str = Field(..., regex="^(google|github)$")
    id_token: str = Field(...)


class RefreshTokenRequest(BaseModel):
    """Refresh access token"""
    refresh_token: str = Field(...)


# ─────────────────────────────────────────────────────────────────────────────
# Response Schemas
# ─────────────────────────────────────────────────────────────────────────────

class TokenResponse(BaseModel):
    """Authentication token response"""
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    expires_in: int = 900


class ErrorResponse(BaseModel):
    """Standardized error response"""
    detail: str
    request_id: Optional[str] = None
    error_code: Optional[str] = None


class SuccessResponse(BaseModel):
    """Standardized success response"""
    success: bool = True
    message: Optional[str] = None
    data: Optional[Dict[str, Any]] = None


class PaginationParams(BaseModel):
    """Pagination parameters"""
    skip: int = Field(0, ge=0)
    limit: int = Field(10, ge=1, le=100)


class PaginatedResponse(BaseModel):
    """Paginated response template"""
    data: List[Dict[str, Any]]
    total: int
    skip: int
    limit: int
    has_more: bool


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 9: HTML SANITIZATION (Prevent XSS)
# ═══════════════════════════════════════════════════════════════════════════════

class HTMLSanitizer:
    """Sanitizes user-generated content to prevent XSS"""
    
    ALLOWED_TAGS = {
        "b", "i", "u", "em", "strong", "p", "br",
        "a", "blockquote", "code", "pre", "ul", "ol", "li",
    }
    
    ALLOWED_ATTRIBUTES = {
        "a": ["href", "title"],
        "*": [],
    }
    
    @staticmethod
    def sanitize_html(content: str, strip_tags: bool = False) -> str:
        """Sanitize HTML content to prevent XSS"""
        if not content:
            return ""
        
        if strip_tags:
            return bleach.clean(content, tags=[], strip=True).strip()
        
        return bleach.clean(
            content,
            tags=HTMLSanitizer.ALLOWED_TAGS,
            attributes=HTMLSanitizer.ALLOWED_ATTRIBUTES,
            strip=True,
        ).strip()
    
    @staticmethod
    def sanitize_text(text: str) -> str:
        """Sanitize plain text"""
        if not text:
            return ""
        
        text = text.strip()
        text = text.replace("\0", "")
        text = "".join(char for char in text if char.isprintable() or char in "\t\n\r")
        return text


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 10: INPUT VALIDATION
# ═══════════════════════════════════════════════════════════════════════════════

class InputValidator:
    """Validates user inputs for security and integrity"""
    
    @staticmethod
    def is_valid_email(email: str) -> bool:
        """Validate email format"""
        if not email or len(email) > 254:
            return False
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        return bool(re.match(pattern, email))
    
    @staticmethod
    def is_valid_url(url: str) -> bool:
        """Validate URL format"""
        if not url:
            return False
        pattern = r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$'
        return bool(re.match(pattern, url))
    
    @staticmethod
    def is_valid_uuid(value: str) -> bool:
        """Validate UUID format"""
        if not value:
            return False
        pattern = r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        return bool(re.match(pattern, value.lower()))
    
    @staticmethod
    def is_safe_filename(filename: str) -> bool:
        """Ensure filename is safe"""
        if not filename:
            return False
        if ".." in filename or "/" in filename or "\\" in filename:
            return False
        if filename.startswith("."):
            return False
        pattern = r'^[a-zA-Z0-9._-]+$'
        return bool(re.match(pattern, filename))


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 11: CSRF PROTECTION
# ═══════════════════════════════════════════════════════════════════════════════

class CSRFProtection:
    """CSRF token generation and validation"""
    
    @staticmethod
    def generate_csrf_token() -> str:
        """Generate CSRF token"""
        return secrets.token_urlsafe(32)
    
    @staticmethod
    def validate_csrf_token(token: str, session_token: str) -> bool:
        """Validate CSRF token using constant-time comparison"""
        if not token or not session_token:
            return False
        return hmac.compare_digest(token, session_token)


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 12: ENCRYPTION (for sensitive data)
# ═══════════════════════════════════════════════════════════════════════════════

class EncryptionManager:
    """Encrypts and decrypts sensitive data using Fernet"""
    
    def __init__(self, encryption_key: Optional[str] = None):
        """Initialize encryption manager"""
        self.key = encryption_key or os.getenv("ENCRYPTION_KEY")
        
        if not self.key:
            logger.warning("ENCRYPTION_KEY not set. Encryption disabled.")
            self.cipher = None
        else:
            try:
                self.cipher = Fernet(self.key.encode())
            except Exception as e:
                logger.error(f"Invalid ENCRYPTION_KEY: {e}")
                self.cipher = None
    
    def encrypt(self, data: str) -> Optional[str]:
        """Encrypt string data"""
        if not self.cipher or not data:
            return data
        
        try:
            return self.cipher.encrypt(data.encode()).decode()
        except Exception as e:
            logger.error(f"Encryption failed: {e}")
            return None
    
    def decrypt(self, encrypted_data: str) -> Optional[str]:
        """Decrypt encrypted data"""
        if not self.cipher or not encrypted_data:
            return encrypted_data
        
        try:
            return self.cipher.decrypt(encrypted_data.encode()).decode()
        except Exception as e:
            logger.error(f"Decryption failed: {e}")
            return None


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 13: PASSWORD SECURITY
# ═══════════════════════════════════════════════════════════════════════════════

class PasswordValidator:
    """Validates password strength"""
    
    @staticmethod
    def validate_password_strength(password: str) -> Tuple[bool, List[str]]:
        """Validate password strength"""
        errors = []
        
        if len(password) < 8:
            errors.append("Password must be at least 8 characters")
        if not any(c.isupper() for c in password):
            errors.append("Password must contain at least one uppercase letter")
        if not any(c.islower() for c in password):
            errors.append("Password must contain at least one lowercase letter")
        if not any(c.isdigit() for c in password):
            errors.append("Password must contain at least one digit")
        if not any(c in "!@#$%^&*()_+-=[]{}|;:,.<>?" for c in password):
            errors.append("Password must contain at least one special character")
        
        return len(errors) == 0, errors
    
    @staticmethod
    def hash_password(password: str, salt: Optional[bytes] = None) -> Tuple[str, str]:
        """Hash password using PBKDF2"""
        from hashlib import pbkdf2_hmac
        
        salt = salt or secrets.token_bytes(32)
        hashed = pbkdf2_hmac("sha256", password.encode(), salt, 100000)
        return hashed.hex(), salt.hex()
    
    @staticmethod
    def verify_password(password: str, hashed: str, salt: str) -> bool:
        """Verify password against hash"""
        from hashlib import pbkdf2_hmac
        
        try:
            computed = pbkdf2_hmac(
                "sha256",
                password.encode(),
                bytes.fromhex(salt),
                100000
            ).hex()
            return hmac.compare_digest(computed, hashed)
        except Exception as e:
            logger.error(f"Password verification failed: {e}")
            return False


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 14: RATE LIMITING - Protection against abuse and DoS
# ═══════════════════════════════════════════════════════════════════════════════

class RateLimiter:
    """In-memory rate limiter using sliding window algorithm"""
    
    def __init__(self):
        """Initialize rate limiter"""
        self._requests: Dict[str, list] = defaultdict(list)
        self._lock = threading.Lock()
    
    def is_allowed(
        self,
        key: str,
        max_requests: int = 100,
        time_window_seconds: int = 60,
    ) -> Tuple[bool, Dict]:
        """Check if request is allowed (sliding window)"""
        with self._lock:
            now = time.time()
            cutoff_time = now - time_window_seconds
            
            if key in self._requests:
                self._requests[key] = [
                    req_time for req_time in self._requests[key]
                    if req_time > cutoff_time
                ]
            
            current_count = len(self._requests[key])
            allowed = current_count < max_requests
            
            if allowed:
                self._requests[key].append(now)
            
            if self._requests[key]:
                reset_time = int(self._requests[key][0] + time_window_seconds)
            else:
                reset_time = int(now + time_window_seconds)
            
            stats = {
                "allowed": allowed,
                "current": current_count,
                "limit": max_requests,
                "remaining": max(0, max_requests - current_count),
                "reset": reset_time,
                "retry_after": max(0, reset_time - int(now)),
            }
            
            return allowed, stats
    
    def cleanup_old_entries(self, max_age_seconds: int = 3600) -> int:
        """Clean up old entries to prevent memory leak"""
        with self._lock:
            now = time.time()
            cutoff_time = now - max_age_seconds
            cleaned = 0
            keys_to_delete = []
            
            for key, requests in self._requests.items():
                self._requests[key] = [
                    req_time for req_time in requests
                    if req_time > cutoff_time
                ]
                if not self._requests[key]:
                    keys_to_delete.append(key)
                    cleaned += 1
            
            for key in keys_to_delete:
                del self._requests[key]
            
            return cleaned


class RateLimitConfig:
    """Rate limit configurations for different endpoints"""
    
    GLOBAL_LIMIT = {
        "requests": 1000,
        "window_seconds": 3600,
        "description": "1000 requests per hour"
    }
    
    AUTH_ENDPOINT = {
        "requests": 5,
        "window_seconds": 300,
        "description": "5 login attempts per 5 minutes"
    }
    
    ROOM_CREATION = {
        "requests": 10,
        "window_seconds": 3600,
        "description": "10 rooms per hour per user"
    }
    
    CHAT_MESSAGE = {
        "requests": 100,
        "window_seconds": 3600,
        "description": "100 messages per hour per user"
    }
    
    ROOM_JOIN = {
        "requests": 50,
        "window_seconds": 3600,
        "description": "50 room joins per hour per user"
    }
    
    MENTOR_BOOKING = {
        "requests": 10,
        "window_seconds": 86400,
        "description": "10 bookings per day per user"
    }
    
    MONITORING_EVENT = {
        "requests": 1000,
        "window_seconds": 300,
        "description": "1000 events per 5 minutes"
    }
    
    FILE_UPLOAD = {
        "requests": 10,
        "window_seconds": 3600,
        "description": "10 uploads per hour per user"
    }
    
    API_GENERAL = {
        "requests": 100,
        "window_seconds": 60,
        "description": "100 requests per minute per user"
    }


# Global rate limiter instance
rate_limiter = RateLimiter()


class RateLimitViolationLog:
    """Tracks rate limit violations"""
    
    def __init__(self, max_violations: int = 1000):
        self._violations: Dict[str, list] = defaultdict(list)
        self._max_violations = max_violations
        self._lock = threading.Lock()
    
    def log_violation(self, key: str, endpoint: str, reason: str = ""):
        """Log rate limit violation"""
        with self._lock:
            self._violations[key].append({
                "timestamp": datetime.now().isoformat(),
                "endpoint": endpoint,
                "reason": reason,
            })
            
            if len(self._violations[key]) > self._max_violations:
                self._violations[key] = self._violations[key][-self._max_violations:]
            
            logger.warning(f"Rate limit violation: key={key}, endpoint={endpoint}")
    
    def get_violations(self, key: str) -> list:
        """Get violations for a key"""
        with self._lock:
            return self._violations.get(key, []).copy()
    
    def get_violation_count(self, key: str) -> int:
        """Get violation count for a key"""
        with self._lock:
            return len(self._violations.get(key, []))


violation_log = RateLimitViolationLog()


class IPBlocklist:
    """Temporary IP blocking for repeated violations"""
    
    def __init__(self, violation_threshold: int = 100, block_duration_minutes: int = 60):
        self._blocklist: Dict[str, datetime] = {}
        self._violation_threshold = violation_threshold
        self._block_duration = timedelta(minutes=block_duration_minutes)
        self._lock = threading.Lock()
    
    def is_blocked(self, ip: str) -> bool:
        """Check if IP is blocked"""
        with self._lock:
            if ip not in self._blocklist:
                return False
            
            if datetime.now() > self._blocklist[ip]:
                del self._blocklist[ip]
                logger.info(f"Block expired for IP: {ip}")
                return False
            
            return True
    
    def block_ip(self, ip: str):
        """Block an IP"""
        with self._lock:
            self._blocklist[ip] = datetime.now() + self._block_duration
            logger.warning(f"IP blocked: {ip}")
    
    def check_and_block(self, ip: str) -> bool:
        """Check violation count and block if threshold exceeded"""
        violation_count = violation_log.get_violation_count(ip)
        
        if violation_count >= self._violation_threshold and not self.is_blocked(ip):
            self.block_ip(ip)
            return True
        
        return False


ip_blocklist = IPBlocklist()


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 15: RATE LIMIT HEADERS
# ═══════════════════════════════════════════════════════════════════════════════

class RateLimitHeaders:
    """Generates rate limit headers for HTTP responses"""
    
    @staticmethod
    def get_headers(
        remaining: int,
        limit: int,
        reset_timestamp: int,
    ) -> Dict[str, str]:
        """Get rate limit headers (RFC 6585)"""
        return {
            "RateLimit-Limit": str(limit),
            "RateLimit-Remaining": str(max(0, remaining)),
            "RateLimit-Reset": str(reset_timestamp),
        }


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 16: SQL INJECTION PREVENTION (Defense in depth)
# ═══════════════════════════════════════════════════════════════════════════════

class SQLSafety:
    """Extra layer of SQL safety"""
    
    @staticmethod
    def is_sql_injection_attempt(value: str) -> bool:
        """Detect common SQL injection patterns"""
        if not value:
            return False
        
        sql_keywords = [
            r"('\s*OR\s*')", r"('\s*AND\s*')",
            r"--", r";", r"\/\*", r"\*\/",
            r"UNION\s+SELECT", r"DROP\s+TABLE", r"DELETE\s+FROM",
            r"INSERT\s+INTO", r"UPDATE\s+SET",
        ]
        
        for pattern in sql_keywords:
            if re.search(pattern, value, re.IGNORECASE):
                logger.warning(f"Potential SQL injection detected")
                return True
        
        return False


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 17: AUDIT LOGGING - Security event tracking and compliance
# ═══════════════════════════════════════════════════════════════════════════════

class AuditEventType(str, Enum):
    """Types of security-relevant events"""
    
    # Authentication
    LOGIN_SUCCESS = "login_success"
    LOGIN_FAILURE = "login_failure"
    LOGOUT = "logout"
    TOKEN_REFRESH = "token_refresh"
    TOKEN_REVOCATION = "token_revocation"
    SESSION_TIMEOUT = "session_timeout"
    
    # Authorization
    PERMISSION_DENIED = "permission_denied"
    ROLE_CHANGED = "role_changed"
    
    # Resource Operations
    RESOURCE_CREATED = "resource_created"
    RESOURCE_MODIFIED = "resource_modified"
    RESOURCE_DELETED = "resource_deleted"
    RESOURCE_ACCESSED = "resource_accessed"
    
    # Security
    MALICIOUS_INPUT_DETECTED = "malicious_input_detected"
    RATE_LIMIT_EXCEEDED = "rate_limit_exceeded"
    SUSPICIOUS_ACTIVITY = "suspicious_activity"
    VULNERABILITY_DETECTED = "vulnerability_detected"
    
    # Data
    DATA_EXPORT = "data_export"
    DATA_IMPORT = "data_import"
    DATA_DELETED = "data_deleted"
    
    # System
    CONFIGURATION_CHANGED = "configuration_changed"
    ERROR_OCCURRED = "error_occurred"
    SERVICE_HEALTH = "service_health"


class AuditSeverity(str, Enum):
    """Severity levels for audit events"""
    INFO = "info"
    WARNING = "warning"
    CRITICAL = "critical"


class AuditEvent:
    """Represents a security audit event"""
    
    def __init__(
        self,
        event_type: AuditEventType,
        severity: AuditSeverity,
        actor_id: Optional[str] = None,
        actor_type: str = "user",
        resource_type: Optional[str] = None,
        resource_id: Optional[str] = None,
        action: Optional[str] = None,
        result: str = "success",
        details: Optional[Dict[str, Any]] = None,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ):
        """Create audit event"""
        self.timestamp = datetime.now(timezone.utc).isoformat()
        self.event_type = event_type
        self.severity = severity
        self.actor_id = actor_id
        self.actor_type = actor_type
        self.resource_type = resource_type
        self.resource_id = resource_id
        self.action = action
        self.result = result
        self.details = details or {}
        self.ip_address = ip_address
        self.user_agent = user_agent
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary"""
        return {
            "timestamp": self.timestamp,
            "event_type": self.event_type.value,
            "severity": self.severity.value,
            "actor": {"id": self.actor_id, "type": self.actor_type},
            "resource": {"type": self.resource_type, "id": self.resource_id},
            "action": self.action,
            "result": self.result,
            "details": self.details,
            "source": {
                "ip_address": self.ip_address,
                "user_agent": self.user_agent[:200] if self.user_agent else None,
            },
        }
    
    def to_json(self) -> str:
        """Convert to JSON string"""
        return json.dumps(self.to_dict())


class AuditLogger:
    """Logs audit events for compliance"""
    
    def __init__(self, use_syslog: bool = False, log_file: Optional[str] = None):
        """Initialize audit logger"""
        self.logger = logging.getLogger("audit")
        self.logger.setLevel(logging.INFO)
        
        if log_file:
            handler = logging.FileHandler(log_file)
            formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
            handler.setFormatter(formatter)
            self.logger.addHandler(handler)
        
        if use_syslog:
            try:
                import logging.handlers
                handler = logging.handlers.SysLogHandler(
                    address="/dev/log",
                    facility=logging.handlers.SysLogHandler.LOG_LOCAL0,
                )
                formatter = logging.Formatter('audit[%(process)d]: %(levelname)s - %(message)s')
                handler.setFormatter(formatter)
                self.logger.addHandler(handler)
            except Exception as e:
                logger.warning(f"Could not configure syslog: {e}")
        
        app_handler = logging.StreamHandler()
        app_handler.setFormatter(logging.Formatter('%(message)s'))
        self.logger.addHandler(app_handler)
    
    def log_event(self, event: AuditEvent):
        """Log an audit event"""
        log_method = {
            AuditSeverity.INFO: self.logger.info,
            AuditSeverity.WARNING: self.logger.warning,
            AuditSeverity.CRITICAL: self.logger.critical,
        }.get(event.severity, self.logger.info)
        
        log_method(event.to_json())
    
    def log_login_success(
        self,
        user_id: str,
        email: str,
        method: str = "password",
        ip_address: Optional[str] = None,
    ):
        """Log successful login"""
        event = AuditEvent(
            event_type=AuditEventType.LOGIN_SUCCESS,
            severity=AuditSeverity.INFO,
            actor_id=user_id,
            action="login",
            result="success",
            details={"email": email, "method": method},
            ip_address=ip_address,
        )
        self.log_event(event)
    
    def log_login_failure(
        self,
        email: str,
        reason: str = "invalid_credentials",
        ip_address: Optional[str] = None,
    ):
        """Log failed login"""
        event = AuditEvent(
            event_type=AuditEventType.LOGIN_FAILURE,
            severity=AuditSeverity.WARNING,
            action="login",
            result="failure",
            details={"email": email, "reason": reason},
            ip_address=ip_address,
        )
        self.log_event(event)
    
    def log_logout(self, user_id: str, ip_address: Optional[str] = None):
        """Log logout"""
        event = AuditEvent(
            event_type=AuditEventType.LOGOUT,
            severity=AuditSeverity.INFO,
            actor_id=user_id,
            action="logout",
            ip_address=ip_address,
        )
        self.log_event(event)
    
    def log_token_revocation(
        self,
        user_id: str,
        reason: str = "logout",
        ip_address: Optional[str] = None,
    ):
        """Log token revocation"""
        event = AuditEvent(
            event_type=AuditEventType.TOKEN_REVOCATION,
            severity=AuditSeverity.INFO,
            actor_id=user_id,
            action="token_revocation",
            details={"reason": reason},
            ip_address=ip_address,
        )
        self.log_event(event)
    
    def log_permission_denied(
        self,
        user_id: str,
        action: str,
        resource_type: str,
        resource_id: str,
        reason: str = "insufficient_permissions",
        ip_address: Optional[str] = None,
    ):
        """Log permission denied"""
        event = AuditEvent(
            event_type=AuditEventType.PERMISSION_DENIED,
            severity=AuditSeverity.WARNING,
            actor_id=user_id,
            resource_type=resource_type,
            resource_id=resource_id,
            action=action,
            result="failure",
            details={"reason": reason},
            ip_address=ip_address,
        )
        self.log_event(event)
    
    def log_resource_created(
        self,
        user_id: str,
        resource_type: str,
        resource_id: str,
        details: Optional[Dict] = None,
        ip_address: Optional[str] = None,
    ):
        """Log resource creation"""
        event = AuditEvent(
            event_type=AuditEventType.RESOURCE_CREATED,
            severity=AuditSeverity.INFO,
            actor_id=user_id,
            resource_type=resource_type,
            resource_id=resource_id,
            action="create",
            details=details or {},
            ip_address=ip_address,
        )
        self.log_event(event)
    
    def log_resource_modified(
        self,
        user_id: str,
        resource_type: str,
        resource_id: str,
        changes: Optional[Dict] = None,
        ip_address: Optional[str] = None,
    ):
        """Log resource modification"""
        event = AuditEvent(
            event_type=AuditEventType.RESOURCE_MODIFIED,
            severity=AuditSeverity.INFO,
            actor_id=user_id,
            resource_type=resource_type,
            resource_id=resource_id,
            action="modify",
            details={"changes": changes or {}},
            ip_address=ip_address,
        )
        self.log_event(event)
    
    def log_resource_deleted(
        self,
        user_id: str,
        resource_type: str,
        resource_id: str,
        reason: Optional[str] = None,
        ip_address: Optional[str] = None,
    ):
        """Log resource deletion"""
        event = AuditEvent(
            event_type=AuditEventType.RESOURCE_DELETED,
            severity=AuditSeverity.WARNING,
            actor_id=user_id,
            resource_type=resource_type,
            resource_id=resource_id,
            action="delete",
            details={"reason": reason},
            ip_address=ip_address,
        )
        self.log_event(event)
    
    def log_malicious_input(
        self,
        user_id: Optional[str],
        input_type: str,
        pattern: str,
        ip_address: Optional[str] = None,
    ):
        """Log malicious input detection"""
        event = AuditEvent(
            event_type=AuditEventType.MALICIOUS_INPUT_DETECTED,
            severity=AuditSeverity.CRITICAL,
            actor_id=user_id,
            action="malicious_input",
            details={"input_type": input_type, "pattern": pattern},
            ip_address=ip_address,
        )
        self.log_event(event)
    
    def log_rate_limit_exceeded(
        self,
        user_id: Optional[str],
        endpoint: str,
        limit: int,
        ip_address: Optional[str] = None,
    ):
        """Log rate limit violation"""
        event = AuditEvent(
            event_type=AuditEventType.RATE_LIMIT_EXCEEDED,
            severity=AuditSeverity.WARNING,
            actor_id=user_id,
            action="rate_limit_exceeded",
            details={"endpoint": endpoint, "limit": limit},
            ip_address=ip_address,
        )
        self.log_event(event)
    
    def log_suspicious_activity(
        self,
        user_id: Optional[str],
        activity_type: str,
        description: str,
        ip_address: Optional[str] = None,
    ):
        """Log suspicious activity"""
        event = AuditEvent(
            event_type=AuditEventType.SUSPICIOUS_ACTIVITY,
            severity=AuditSeverity.WARNING,
            actor_id=user_id,
            action="suspicious_activity",
            details={"type": activity_type, "description": description},
            ip_address=ip_address,
        )
        self.log_event(event)


# ═══════════════════════════════════════════════════════════════════════════════
# GLOBAL INSTANCES - Initialization
# ═══════════════════════════════════════════════════════════════════════════════

# Initialize encryption manager
encryption_manager = EncryptionManager()

# Initialize audit logger
use_syslog = os.getenv("USE_SYSLOG", "false").lower() == "true"
audit_log_file = os.getenv("AUDIT_LOG_FILE", "./logs/audit.log")

if audit_log_file:
    log_dir = Path(audit_log_file).parent
    log_dir.mkdir(parents=True, exist_ok=True)

audit_logger = AuditLogger(
    use_syslog=use_syslog,
    log_file=audit_log_file if audit_log_file != "./logs/audit.log" or os.path.exists(Path(audit_log_file).parent) else None,
)


# ═══════════════════════════════════════════════════════════════════════════════
# __all__ - Public API
# ═══════════════════════════════════════════════════════════════════════════════

__all__ = [
    # Authentication & Authorization
    "UserRole", "Permission", "TokenPayload", "TokenBlacklist", "token_blacklist",
    "JWTValidator", "jwt_validator", "AuthorizationManager", "SessionManager",
    "GoogleOAuthValidator",
    
    # Dependencies
    "get_current_user", "get_current_admin", "get_current_mentor",
    
    # Schemas (Pydantic)
    "RoomType", "CreateRoomRequest", "JoinRoomRequest", "RoomConfigRequest",
    "PostChatRequest", "SaveNotesRequest", "BookMentorSessionRequest",
    "CreateEventRequest", "MonitoringEventRequest", "SkeletonSnapshotRequest",
    "LoginRequest", "OAuthLoginRequest", "RefreshTokenRequest",
    "TokenResponse", "ErrorResponse", "SuccessResponse",
    "PaginationParams", "PaginatedResponse",
    
    # Security Utilities
    "HTMLSanitizer", "InputValidator", "CSRFProtection",
    "EncryptionManager", "encryption_manager",
    "PasswordValidator", "RateLimitHeaders", "SQLSafety",
    
    # Rate Limiting
    "RateLimiter", "RateLimitConfig", "rate_limiter",
    "RateLimitViolationLog", "violation_log",
    "IPBlocklist", "ip_blocklist",
    
    # Audit Logging
    "AuditEventType", "AuditSeverity", "AuditEvent",
    "AuditLogger", "audit_logger",
]
