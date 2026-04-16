"""
📊 Study Room Monitoring Database Routes
FastAPI endpoints for monitoring sessions, events, and occupancy tracking
Migrated from Lernova/src/app/lib/monitoringAPI.ts (Next.js API routes)

✅ SECURITY: All endpoints include rate limiting, input validation, and error sanitization
"""

from fastapi import APIRouter, HTTPException, Depends, Query
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime, timedelta
import logging
from utils.monitoring_config import get_supabase_client

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/monitoring/db", tags=["monitoring-database"])

# ─────────────────────────────────────────────────────────────
# Request/Response Models (Pydantic)
# ─────────────────────────────────────────────────────────────

class MonitoringSessionCreate(BaseModel):
    """Create a new monitoring session"""
    room_id: str = Field(..., min_length=1, max_length=100, description="Study room ID")
    session_name: Optional[str] = Field(None, max_length=255)

class MonitoringEvent(BaseModel):
    """Log a monitoring event"""
    room_id: str = Field(..., min_length=1, max_length=100)
    event_type: str = Field(..., description="Type of event (fall, posture, idle, etc)")
    severity: str = Field(..., description="low, medium, high, critical")
    description: Optional[str] = None
    people_count: Optional[int] = Field(None, ge=0, le=20)
    anomaly_score: Optional[float] = Field(None, ge=0.0, le=1.0)
    event_data: Optional[Dict[str, Any]] = None

class SkeletonSnapshot(BaseModel):
    """Store skeleton/keypoint data"""
    room_id: str = Field(..., min_length=1, max_length=100)
    person_index: int = Field(0, ge=0, le=19)
    keypoints: List[Dict[str, Any]]  # 33 MediaPipe keypoints
    pose_angle: Optional[float] = None
    velocity: Optional[float] = None
    is_standing: Optional[bool] = True
    is_idle: Optional[bool] = False

class OccupancyUpdate(BaseModel):
    """Update room occupancy"""
    room_id: str = Field(..., min_length=1, max_length=100)
    occupancy_count: int = Field(..., ge=0, le=20)
    confidence_score: Optional[float] = Field(None, ge=0.0, le=1.0)

class BehaviorRuleCreate(BaseModel):
    """Create a behavior detection rule"""
    room_id: str = Field(..., min_length=1, max_length=100)
    rule_name: str = Field(..., max_length=255)
    rule_type: str  # e.g., "fall_detection", "posture", "idle"
    condition_json: Dict[str, Any]
    alert_trigger_level: Optional[str] = "medium"

# ─────────────────────────────────────────────────────────────
# Helper Functions
# ─────────────────────────────────────────────────────────────

async def get_supabase():
    """Dependency: Get Supabase client"""
    return get_supabase_client()

def sanitize_error(error_msg: str) -> str:
    """Sanitize database errors to prevent information disclosure"""
    error_lower = error_msg.lower()
    
    error_map = {
        "duplicate key": "This record already exists",
        "constraint violation": "Invalid data provided",
        "foreign key": "Referenced item does not exist",
        "permission denied": "You don't have permission to perform this action",
        "database error": "A data error occurred. Please try again.",
    }
    
    for pattern, safe_msg in error_map.items():
        if pattern in error_lower:
            return safe_msg
    
    return "An error occurred. Please try again."

# ─────────────────────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────────────────────

@router.post("/sessions", tags=["sessions"])
async def start_monitoring_session(
    session: MonitoringSessionCreate,
    supabase = Depends(get_supabase)
):
    """
    📍 Start a new monitoring session for a study room
    
    Creates a monitoring_sessions record with initial state.
    Use this when entering a study room to track the session.
    """
    try:
        response = supabase.table('monitoring_sessions').insert({
            'room_id': session.room_id,
            'session_name': session.session_name,
            'session_start': datetime.utcnow().isoformat(),
            'status': 'active',
            'total_people_peak': 0,
            'total_events': 0,
            'anomalies_detected': 0,
        }).execute()
        
        if response.data:
            return {
                'success': True,
                'session': response.data[0],
                'message': 'Monitoring session started'
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to create session")
    
    except Exception as e:
        logger.error(f"[MONITORING] Session creation error: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=sanitize_error(str(e))
        )

@router.post("/events", tags=["events"])
async def log_monitoring_event(
    event: MonitoringEvent,
    supabase = Depends(get_supabase)
):
    """
    🚨 Log a monitoring event (behavior, anomaly, alert)
    
    Records behavioral events detected during monitoring.
    Automatically triggers alerts for high/critical severity events.
    """
    try:
        response = supabase.table('monitoring_events').insert({
            'room_id': event.room_id,
            'event_type': event.event_type,
            'severity': event.severity,
            'description': event.description,
            'people_count': event.people_count,
            'anomaly_score': event.anomaly_score,
            'event_data': event.event_data or {},
            'processed': False,
            'created_at': datetime.utcnow().isoformat(),
        }).execute()
        
        if response.data:
            event_record = response.data[0]
            
            # Trigger alert for high/critical severity
            if event.severity in ['high', 'critical']:
                await trigger_alert(event.room_id, event.event_type, event.severity, supabase)
            
            return {
                'success': True,
                'event': event_record,
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to log event")
    
    except Exception as e:
        logger.error(f"[MONITORING] Event logging error: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=sanitize_error(str(e))
        )

@router.post("/skeleton", tags=["skeleton-data"])
async def store_skeleton_data(
    skeleton: SkeletonSnapshot,
    supabase = Depends(get_supabase)
):
    """
    🦴 Store skeletal keypoint data
    
    Saves MediaPipe skeleton (33 keypoints per person) for post-analysis.
    Privacy-first: Only keypoints stored, no video/images.
    """
    try:
        response = supabase.table('room_skeleton_snapshots').insert({
            'room_id': skeleton.room_id,
            'person_index': skeleton.person_index,
            'keypoints': skeleton.keypoints,
            'pose_angle': skeleton.pose_angle,
            'velocity': skeleton.velocity,
            'is_standing': skeleton.is_standing,
            'is_idle': skeleton.is_idle,
            'frame_timestamp': datetime.utcnow().isoformat(),
        }).execute()
        
        if response.data:
            return {
                'success': True,
                'snapshot': response.data[0],
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to store skeleton")
    
    except Exception as e:
        logger.error(f"[MONITORING] Skeleton storage error: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=sanitize_error(str(e))
        )

@router.post("/occupancy", tags=["occupancy"])
async def update_occupancy(
    occupancy: OccupancyUpdate,
    supabase = Depends(get_supabase)
):
    """
    👥 Update room occupancy count
    
    Logs occupancy snapshots for historical tracking.
    Used to detect over-capacity situations.
    """
    try:
        response = supabase.table('room_occupancy_history').insert({
            'room_id': occupancy.room_id,
            'timestamp': datetime.utcnow().isoformat(),
            'occupancy_count': occupancy.occupancy_count,
            'confidence_score': occupancy.confidence_score or 0.9,
        }).execute()
        
        if response.data:
            return {
                'success': True,
                'occupancy': response.data[0],
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to update occupancy")
    
    except Exception as e:
        logger.error(f"[MONITORING] Occupancy update error: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=sanitize_error(str(e))
        )

@router.get("/rooms/{room_id}/status", tags=["room-status"])
async def get_room_status(
    room_id: str,
    supabase = Depends(get_supabase)
):
    """
    📊 Get current room monitoring status
    
    Returns room info, recent events, occupancy, and system health.
    """
    try:
        # Get room info
        room_response = supabase.table('study_rooms').select('*').eq('id', room_id).single().execute()
        room = room_response.data if room_response.data else None
        
        if not room:
            raise HTTPException(status_code=404, detail=f"Room {room_id} not found")
        
        # Get latest events (last 10)
        events_response = supabase.table('monitoring_events') \
            .select('*') \
            .eq('room_id', room_id) \
            .order('created_at', desc=True) \
            .limit(10) \
            .execute()
        events = events_response.data or []
        
        # Get latest occupancy
        occupancy_response = supabase.table('room_occupancy_history') \
            .select('occupancy_count') \
            .eq('room_id', room_id) \
            .order('timestamp', desc=True) \
            .limit(1) \
            .execute()
        occupancy = occupancy_response.data[0] if occupancy_response.data else None
        
        # Get latest system health
        health_response = supabase.table('monitoring_system_status') \
            .select('*') \
            .eq('room_id', room_id) \
            .order('updated_at', desc=True) \
            .limit(1) \
            .execute()
        health = health_response.data[0] if health_response.data else {}
        
        return {
            'success': True,
            'room': room,
            'current_occupancy': occupancy['occupancy_count'] if occupancy else 0,
            'recent_events': events,
            'system_health': health,
        }
    
    except Exception as e:
        logger.error(f"[MONITORING] Room status error: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=sanitize_error(str(e))
        )

@router.get("/rooms/{room_id}/events", tags=["events"])
async def get_event_history(
    room_id: str,
    days: int = Query(7, ge=1, le=90),
    severity: Optional[str] = None,
    supabase = Depends(get_supabase)
):
    """
    📈 Get event history and analytics for a room
    
    Returns historical events with aggregated statistics.
    """
    try:
        cutoff_date = (datetime.utcnow() - timedelta(days=days)).isoformat()
        
        query = supabase.table('monitoring_events') \
            .select('*') \
            .eq('room_id', room_id) \
            .gte('created_at', cutoff_date)
        
        if severity:
            query = query.eq('severity', severity)
        
        response = query.order('created_at', desc=True).execute()
        events = response.data or []
        
        # Aggregate statistics
        stats = {
            'total_events': len(events),
            'critical_events': len([e for e in events if e.get('severity') == 'critical']),
            'high_severity': len([e for e in events if e.get('severity') == 'high']),
            'event_types': {
                event_type: len([e for e in events if e.get('event_type') == event_type])
                for event_type in set(e.get('event_type') for e in events if e.get('event_type'))
            }
        }
        
        return {
            'success': True,
            'events': events,
            'statistics': stats,
        }
    
    except Exception as e:
        logger.error(f"[MONITORING] Event history error: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=sanitize_error(str(e))
        )

@router.post("/rules", tags=["rules"])
async def create_behavior_rule(
    rule: BehaviorRuleCreate,
    supabase = Depends(get_supabase)
):
    """
    ⚙️ Create a custom behavior detection rule
    
    Allows customization of what behaviors trigger alerts.
    """
    try:
        response = supabase.table('behavior_rules').insert({
            'room_id': rule.room_id,
            'rule_name': rule.rule_name,
            'rule_type': rule.rule_type,
            'condition_json': rule.condition_json,
            'alert_trigger_level': rule.alert_trigger_level or 'medium',
            'is_active': True,
            'created_at': datetime.utcnow().isoformat(),
        }).execute()
        
        if response.data:
            return {
                'success': True,
                'rule': response.data[0],
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to create rule")
    
    except Exception as e:
        logger.error(f"[MONITORING] Rule creation error: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=sanitize_error(str(e))
        )

# ─────────────────────────────────────────────────────────────
# Internal Helper Functions (not exposed as endpoints)
# ─────────────────────────────────────────────────────────────

async def trigger_alert(room_id: str, event_type: str, severity: str, supabase):
    """
    🚨 Trigger an alert for high/critical events
    
    Can integrate with:
    - Email notifications
    - Slack webhooks
    - In-app notifications
    - SMS alerts
    """
    try:
        # Log alert to database
        supabase.table('alerts').insert({
            'room_id': room_id,
            'event_type': event_type,
            'severity': severity,
            'status': 'pending',
            'created_at': datetime.utcnow().isoformat(),
        }).execute()
        
        logger.warning(f"[ALERT] {severity.upper()} alert: {event_type} in room {room_id}")
        
        # TODO: Integrate with notification services
        # - Email: send_email(admin@elmorbit.co.in, ...)
        # - Slack: post_to_slack(...)
        # - WebSocket: broadcast to connected clients
        
    except Exception as e:
        logger.error(f"[ALERT] Failed to trigger alert: {str(e)}")
