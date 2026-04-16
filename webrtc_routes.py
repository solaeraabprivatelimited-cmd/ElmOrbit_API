"""
WebRTC API Routes - FastAPI implementation
Provides room management, participant tracking, and signaling
Bypasses Supabase Edge Functions ES256 JWT algorithm issues
"""

from fastapi import APIRouter, Depends, HTTPException, Header
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
import json
import logging
from utils.monitoring_config import get_supabase_client

logger = logging.getLogger(__name__)

webrtc_router = APIRouter(prefix="/webrtc", tags=["webrtc"])

# ─────────────────────────────────────────────────────────────
# Request/Response Models
# ─────────────────────────────────────────────────────────────

class CreateRoomRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    mode: str = Field(default="collaborative", pattern="^(focus|silent|collaborative|live)$")
    subject: Optional[str] = Field(default=None, max_length=255)
    description: Optional[str] = Field(default=None, max_length=1000)
    maxParticipants: int = Field(default=6, ge=2, le=20)

class RoomParticipant(BaseModel):
    id: str
    user_id: str
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    connection_state: str
    permissions: str
    joined_at: Optional[str] = None
    disconnected_at: Optional[str] = None

class Room(BaseModel):
    id: str
    code: str
    name: str
    mode: str
    host_id: str
    subject: Optional[str] = None
    description: Optional[str] = None
    max_participants: int
    is_active: bool
    created_at: str
    updated_at: str
    participants: List[RoomParticipant] = []

class ChatMessage(BaseModel):
    id: str
    room_id: str
    sender_user_id: str
    message: str
    created_at: str
    sender: Optional[dict] = None

class RoomNote(BaseModel):
    id: Optional[str] = None
    room_id: str
    user_id: str
    content: str
    created_at: Optional[str] = None
    updated_at: Optional[str] = None

# ─────────────────────────────────────────────────────────────
# Helper Functions
# ─────────────────────────────────────────────────────────────

def extract_user_id_from_token(authorization: Optional[str] = None) -> str:
    """Extract user ID from Bearer JWT token"""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Authorization header required")
    
    token = authorization[7:]  # Remove "Bearer " prefix
    
    try:
        # JWT format: header.payload.signature
        parts = token.split(".")
        if len(parts) != 3:
            raise HTTPException(status_code=401, detail="Invalid token format")
        
        # Decode payload (base64url to base64)
        import base64
        payload = parts[1]
        payload += "=" * (4 - len(payload) % 4)  # Add padding
        payload_decoded = base64.urlsafe_b64decode(payload)
        payload_json = json.loads(payload_decoded)
        
        user_id = payload_json.get("sub") or payload_json.get("user_id")
        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid token: no user ID")
        
        return user_id
    except Exception as e:
        logger.error(f"Token extraction error: {e}")
        raise HTTPException(status_code=401, detail="Invalid token")

def generate_room_code() -> str:
    """Generate a unique room code"""
    import random
    import string
    chars = string.ascii_uppercase + string.digits
    return f"STUDY-{''.join(random.choices(chars, k=6))}"

# ─────────────────────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────────────────────

@webrtc_router.post("/rooms", response_model=Room, status_code=201)
async def create_room(
    request: CreateRoomRequest,
    authorization: Optional[str] = Header(None),
    supabase = Depends(get_supabase_client),
):
    """Create a new WebRTC study room"""
    try:
        user_id = extract_user_id_from_token(authorization)
        
        # Ensure user exists in profiles table
        supabase.table("profiles").upsert({
            "id": user_id,
            "updated_at": datetime.utcnow().isoformat(),
        }).execute()
        
        room_code = generate_room_code()
        
        response = supabase.table("webrtc_rooms").insert({
            "code": room_code,
            "name": request.name.strip(),
            "mode": request.mode,
            "host_id": user_id,
            "subject": request.subject,
            "description": request.description,
            "max_participants": request.maxParticipants,
            "is_active": True,
            "created_by": user_id,
            "updated_by": user_id,
        }).execute()
        
        room = response.data[0] if response.data else None
        if not room:
            raise HTTPException(status_code=500, detail="Failed to create room")
        
        # Add host as participant
        supabase.table("webrtc_participants").insert({
            "room_id": room["id"],
            "user_id": user_id,
            "permissions": "host",
            "connection_state": "connecting",
        }).execute()
        
        logger.info(f"Room created: {room['id']} by {user_id}")
        return Room(**room, participants=[])
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Room creation error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to create room: {str(e)}")

@webrtc_router.get("/rooms/{room_id}", response_model=Room)
async def get_room(
    room_id: str,
    supabase = Depends(get_supabase_client),
):
    """Get room details with participants"""
    try:
        # Try to find by ID or code
        room_response = supabase.table("webrtc_rooms").select(
            "*,participants:webrtc_participants(id,user_id,connection_state,is_audio_enabled,is_video_enabled,is_screen_sharing,is_muted,permissions,joined_at,last_heartbeat,disconnected_at)"
        ).eq("id", room_id).execute()
        
        room = room_response.data[0] if room_response.data else None
        
        if not room:
            # Try by code
            room_response = supabase.table("webrtc_rooms").select(
                "*,participants:webrtc_participants(id,user_id,connection_state,is_audio_enabled,is_video_enabled,is_screen_sharing,is_muted,permissions,joined_at,last_heartbeat,disconnected_at)"
            ).eq("code", room_id.upper()).execute()
            room = room_response.data[0] if room_response.data else None
        
        if not room:
            raise HTTPException(status_code=404, detail="Room not found")
        
        # Enrich participants with user info
        participants = room.get("participants", []) or []
        user_ids = list(set([p.get("user_id") for p in participants if p.get("user_id")]))
        
        user_map = {}
        if user_ids:
            users_response = supabase.table("profiles").select("id,name,avatar_url").in_("id", user_ids).execute()
            user_map = {u["id"]: u for u in (users_response.data or [])}
        
        enriched_participants = []
        for p in participants:
            user = user_map.get(p.get("user_id"), {})
            enriched_participants.append(RoomParticipant(
                id=p.get("id"),
                user_id=p.get("user_id"),
                display_name=user.get("name", "Participant"),
                avatar_url=user.get("avatar_url"),
                connection_state=p.get("connection_state", "unknown"),
                permissions=p.get("permissions", "participant"),
                joined_at=p.get("joined_at"),
                disconnected_at=p.get("disconnected_at"),
            ))
        
        return Room(
            **{k: v for k, v in room.items() if k != "participants"},
            participants=enriched_participants
        )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Room fetch error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch room: {str(e)}")

@webrtc_router.get("/rooms", response_model=List[Room])
async def list_rooms(
    authorization: Optional[str] = Header(None),
    supabase = Depends(get_supabase_client),
):
    """List all active rooms"""
    try:
        user_id = extract_user_id_from_token(authorization)
        
        response = supabase.table("webrtc_rooms").select(
            "id,code,name,mode,subject,host_id,max_participants,is_active,created_at,updated_at"
        ).eq("is_active", True).order("created_at", desc=True).limit(100).execute()
        
        rooms = response.data or []
        return [Room(**room, participants=[]) for room in rooms]
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Rooms list error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch rooms: {str(e)}")

@webrtc_router.post("/rooms/{room_id}/join")
async def join_room(
    room_id: str,
    authorization: Optional[str] = Header(None),
    supabase = Depends(get_supabase_client),
):
    """Join a room as a participant"""
    try:
        user_id = extract_user_id_from_token(authorization)
        
        # Find room
        room_response = supabase.table("webrtc_rooms").select("id,is_active").eq("id", room_id).execute()
        room = room_response.data[0] if room_response.data else None
        
        if not room:
            room_response = supabase.table("webrtc_rooms").select("id,is_active").eq("code", room_id.upper()).execute()
            room = room_response.data[0] if room_response.data else None
        
        if not room:
            raise HTTPException(status_code=404, detail="Room not found")
        
        if not room["is_active"]:
            raise HTTPException(status_code=410, detail="Room is closed")
        
        # Check if already joined
        existing = supabase.table("webrtc_participants").select("id").eq(
            "room_id", room["id"]
        ).eq("user_id", user_id).is_("disconnected_at", True).execute()
        
        if existing.data:
            # Rejoin
            response = supabase.table("webrtc_participants").update({
                "disconnected_at": None,
                "connection_state": "connecting",
                "last_heartbeat": datetime.utcnow().isoformat(),
            }).eq("id", existing.data[0]["id"]).execute()
        else:
            # New participant
            response = supabase.table("webrtc_participants").insert({
                "room_id": room["id"],
                "user_id": user_id,
                "permissions": "participant",
                "connection_state": "connecting",
            }).execute()
        
        logger.info(f"User {user_id} joined room {room['id']}")
        return {"success": True, "room_id": room["id"]}
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Join room error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to join room: {str(e)}")

@webrtc_router.get("/rooms/{room_id}/chat", response_model=List[ChatMessage])
async def get_room_chat(
    room_id: str,
    limit: int = 100,
    authorization: Optional[str] = Header(None),
    supabase = Depends(get_supabase_client),
):
    """Get room chat messages"""
    try:
        user_id = extract_user_id_from_token(authorization)
        
        response = supabase.table("webrtc_chat").select(
            "*"
        ).eq("room_id", room_id).order("created_at", desc=True).limit(limit).execute()
        
        messages = response.data or []
        return [ChatMessage(**msg) for msg in messages]
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Chat fetch error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch chat: {str(e)}")

@webrtc_router.get("/rooms/{room_id}/notes", response_model=List[RoomNote])
async def get_room_notes(
    room_id: str,
    authorization: Optional[str] = Header(None),
    supabase = Depends(get_supabase_client),
):
    """Get room notes"""
    try:
        user_id = extract_user_id_from_token(authorization)
        
        response = supabase.table("webrtc_notes").select(
            "*"
        ).eq("room_id", room_id).order("created_at", desc=True).execute()
        
        notes = response.data or []
        return [RoomNote(**note) for note in notes]
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Notes fetch error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch notes: {str(e)}")

@webrtc_router.post("/rooms/{room_id}/chat")
async def post_room_chat(
    room_id: str,
    message: str = Field(..., min_length=1, max_length=2000),
    authorization: Optional[str] = Header(None),
    supabase = Depends(get_supabase_client),
):
    """Post a message to room chat"""
    try:
        user_id = extract_user_id_from_token(authorization)
        
        response = supabase.table("webrtc_chat").insert({
            "room_id": room_id,
            "sender_user_id": user_id,
            "message": message.strip(),
            "created_at": datetime.utcnow().isoformat(),
        }).execute()
        
        logger.info(f"Message posted to room {room_id} by {user_id}")
        return {"success": True, "message_id": response.data[0].get("id") if response.data else None}
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Chat post error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to post message: {str(e)}")

@webrtc_router.post("/rooms/{room_id}/notes")
async def save_room_notes(
    room_id: str,
    content: str = Field(..., min_length=0),
    authorization: Optional[str] = Header(None),
    supabase = Depends(get_supabase_client),
):
    """Save room notes"""
    try:
        user_id = extract_user_id_from_token(authorization)
        
        response = supabase.table("webrtc_notes").upsert({
            "room_id": room_id,
            "user_id": user_id,
            "content": content.strip(),
            "updated_at": datetime.utcnow().isoformat(),
        }).execute()
        
        logger.info(f"Notes saved for room {room_id} by {user_id}")
        return {"success": True}
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Notes save error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to save notes: {str(e)}")

@webrtc_router.get("/participants/{participant_id}")
async def get_participant(
    participant_id: str,
    authorization: Optional[str] = Header(None),
    supabase = Depends(get_supabase_client),
):
    """Get participant details"""
    try:
        user_id = extract_user_id_from_token(authorization)
        
        response = supabase.table("webrtc_participants").select("*").eq("id", participant_id).execute()
        
        participant = response.data[0] if response.data else None
        if not participant:
            raise HTTPException(status_code=404, detail="Participant not found")
        
        return participant
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Participant fetch error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch participant: {str(e)}")
