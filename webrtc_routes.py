"""
WebRTC API Routes - FastAPI implementation
Provides room management, participant tracking, and signaling
Bypasses Supabase Edge Functions ES256 JWT algorithm issues
"""

from fastapi import APIRouter, Depends, HTTPException, Header, Query, Request
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
import json
import logging
from utils.monitoring_config import get_supabase_client
from background_tasks import background_tasks

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

class PostChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=2000)

class SaveNotesRequest(BaseModel):
    content: str = Field(default="", max_length=10000)

class SignalMessage(BaseModel):
    type: str = Field(..., pattern="^(offer|answer|candidate)$")
    data: dict = Field(default_factory=dict)

class UpdateParticipantRequest(BaseModel):
    connection_state: Optional[str] = None
    is_audio_enabled: Optional[bool] = None
    is_video_enabled: Optional[bool] = None
    is_screen_sharing: Optional[bool] = None
    is_muted: Optional[bool] = None

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
                permissions=p.get("permissions", "member"),
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
        room_response = supabase.table("webrtc_rooms").select("id,is_active,emptied_at").eq("id", room_id).execute()
        room = room_response.data[0] if room_response.data else None
        
        if not room:
            room_response = supabase.table("webrtc_rooms").select("id,is_active,emptied_at").eq("code", room_id.upper()).execute()
            room = room_response.data[0] if room_response.data else None
        
        if not room:
            raise HTTPException(status_code=404, detail="Room not found")
        
        if not room["is_active"]:
            raise HTTPException(status_code=410, detail="Room is closed")
        
        # Upsert participant - handles both new joins and rejoins
        response = supabase.table("webrtc_participants").upsert({
            "room_id": room["id"],
            "user_id": user_id,
            "permissions": "member",
            "connection_state": "connecting",
            "disconnected_at": None,
            "last_heartbeat": datetime.utcnow().isoformat(),
        }, on_conflict="room_id,user_id").execute()
        
        # If room was marked as empty, unmark it now that someone joined
        if room.get("emptied_at") is not None:
            await background_tasks.unmark_room_empty(room["id"])
            logger.info(f"Room {room['id']} unmarked as empty after participant joined")
        
        logger.info(f"User {user_id} joined room {room['id']}")
        return {"success": True, "room_id": room["id"]}
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Join room error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to join room: {str(e)}")

@webrtc_router.post("/rooms/{room_id}/leave")
async def leave_room(
    room_id: str,
    authorization: Optional[str] = Header(None),
    supabase = Depends(get_supabase_client),
):
    """Leave a room as a participant"""
    try:
        user_id = extract_user_id_from_token(authorization)
        
        # Find participant
        response = supabase.table("webrtc_participants").select("id").eq(
            "room_id", room_id
        ).eq("user_id", user_id).is_("disconnected_at", "null").execute()
        
        if not response.data:
            raise HTTPException(status_code=404, detail="Participant not found")
        
        # Mark as disconnected
        supabase.table("webrtc_participants").update({
            "disconnected_at": datetime.utcnow().isoformat(),
            "connection_state": "disconnected",
        }).eq("id", response.data[0]["id"]).execute()
        
        # Check if any active participants remain in the room
        active_response = supabase.table("webrtc_participants").select("id").eq(
            "room_id", room_id
        ).is_("disconnected_at", "null").is_("left_at", "null").execute()
        
        # If no active participants remain, mark room as empty for cleanup
        if not active_response.data or len(active_response.data) == 0:
            await background_tasks.mark_room_empty(room_id)
            logger.info(f"Room {room_id} marked empty after last participant left")
        
        logger.info(f"User {user_id} left room {room_id}")
        return {"success": True}
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Leave room error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to leave room: {str(e)}")

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
        
        # Query messages without JOIN - Supabase FK relationship may not be configured
        response = supabase.table("webrtc_room_messages").select(
            "id, room_id, sender_user_id, message, created_at"
        ).eq("room_id", room_id).order("created_at", desc=True).limit(limit).execute()
        
        messages = response.data or []
        result = []
        for msg in messages:
            # Construct ChatMessage - sender info will show sender_user_id on frontend
            chat_msg = ChatMessage(
                id=msg.get('id'),
                room_id=msg.get('room_id'),
                sender_user_id=msg.get('sender_user_id'),
                message=msg.get('message'),
                created_at=msg.get('created_at'),
                sender=None  # Will be populated by frontend fallback
            )
            result.append(chat_msg)
        return result
    
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
        
        response = supabase.table("webrtc_room_notes").select(
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
    request: PostChatRequest,
    authorization: Optional[str] = Header(None),
    supabase = Depends(get_supabase_client),
):
    """Post a message to room chat"""
    try:
        user_id = extract_user_id_from_token(authorization)
        
        response = supabase.table("webrtc_room_messages").insert({
            "room_id": room_id,
            "sender_user_id": user_id,
            "message": request.message.strip(),
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
    request: SaveNotesRequest,
    authorization: Optional[str] = Header(None),
    supabase = Depends(get_supabase_client),
):
    """Save room notes"""
    try:
        user_id = extract_user_id_from_token(authorization)
        
        response = supabase.table("webrtc_room_notes").upsert({
            "room_id": room_id,
            "user_id": user_id,
            "content": request.content.strip(),
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

@webrtc_router.options("/signal/{user_id}")
async def options_signal_handler(user_id: str):
    """Handle OPTIONS preflight for signal endpoint - no dependencies to avoid 400 errors"""
    return {}

@webrtc_router.get("/signal/{user_id}")
async def get_signal(
    user_id: str,
    request: Request,
    supabase = Depends(get_supabase_client),
):
    """Poll for WebRTC signaling messages (offer, answer, candidates)"""
    try:
        # Extract room_id from query params manually to avoid validation issues with OPTIONS
        room_id = request.query_params.get("roomId") or request.query_params.get("room_id")
        if not room_id:
            raise HTTPException(status_code=400, detail="roomId query parameter required")
        
        # Get pending signals for this user in the room
        response = supabase.table("webrtc_signaling").select("*").eq(
            "to_user_id", user_id
        ).eq("room_id", room_id).is_("was_processed", "false").order("created_at", desc=True).limit(50).execute()
        
        signals = response.data or []
        
        # Mark signals as processed
        if signals:
            signal_ids = [s["id"] for s in signals]
            supabase.table("webrtc_signaling").update({
                "was_processed": True,
                "processed_at": datetime.utcnow().isoformat(),
            }).in_("id", signal_ids).execute()
        
        logger.debug(f"Returned {len(signals)} signals for user {user_id} in room {room_id}")
        return signals
    
    except Exception as e:
        logger.error(f"Signal polling error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to poll signals: {str(e)}")

@webrtc_router.post("/signal/{user_id}")
async def post_signal(
    user_id: str,
    request: Request,
    signal: SignalMessage = None,
    authorization: Optional[str] = Header(None),
    supabase = Depends(get_supabase_client),
):
    """Send a WebRTC signaling message to a recipient"""
    try:
        # Extract room_id from query params manually to avoid validation issues with OPTIONS
        room_id = request.query_params.get("roomId") or request.query_params.get("room_id")
        if not room_id:
            raise HTTPException(status_code=400, detail="roomId query parameter required")
        
        sender_id = extract_user_id_from_token(authorization)
        
        # Store signal in database
        response = supabase.table("webrtc_signaling").insert({
            "room_id": room_id,
            "from_user_id": sender_id,
            "to_user_id": user_id,
            "signal_type": signal.type,
            "payload": signal.data,
            "was_processed": False,
        }).execute()
        
        logger.debug(f"Signal sent from {sender_id} to {user_id} in room {room_id}")
        return {"success": True, "signal_id": response.data[0].get("id") if response.data else None}
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Signal send error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to send signal: {str(e)}")

@webrtc_router.put("/participants/{participant_id}")
async def update_participant(
    participant_id: str,
    request: UpdateParticipantRequest,
    authorization: Optional[str] = Header(None),
    supabase = Depends(get_supabase_client),
):
    """Update participant status (heartbeat, media state, etc)"""
    try:
        user_id = extract_user_id_from_token(authorization)
        
        # Build update payload
        update_data = {
            "last_heartbeat": datetime.utcnow().isoformat(),
        }
        
        if request.connection_state:
            update_data["connection_state"] = request.connection_state
        if request.is_audio_enabled is not None:
            update_data["is_audio_enabled"] = request.is_audio_enabled
        if request.is_video_enabled is not None:
            update_data["is_video_enabled"] = request.is_video_enabled
        if request.is_screen_sharing is not None:
            update_data["is_screen_sharing"] = request.is_screen_sharing
        if request.is_muted is not None:
            update_data["is_muted"] = request.is_muted
        
        response = supabase.table("webrtc_participants").update(update_data).eq(
            "id", participant_id
        ).execute()
        
        logger.debug(f"Participant {participant_id} updated by {user_id}")
        return {"success": True, "participant_id": participant_id}
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Participant update error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to update participant: {str(e)}")
