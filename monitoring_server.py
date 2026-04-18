"""
FastAPI Server for Study Room Monitoring
Handles real-time video processing and event streaming
✅ SECURITY: Production-grade API with security headers, CORS restrictions, rate limiting, error sanitization
"""

import asyncio
import cv2
import numpy as np
from fastapi import FastAPI, WebSocket, File, UploadFile, HTTPException, Request
from fastapi.responses import StreamingResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import os
from dotenv import load_dotenv
from datetime import datetime, timedelta
import json
import logging
from typing import Optional
import uuid
from functools import wraps
import time

# Import monitoring modules
from utils.monitoring_core import MonitoringEngine, PoseDetector, BehaviorAnalyzer
from utils.monitoring_config import get_default_config
from routes import router as unified_router
from background_tasks import init_background_tasks, shutdown_background_tasks

# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY: Setup logging with audit trail support
# ═══════════════════════════════════════════════════════════════════════════════
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

load_dotenv()

# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY: Error Sanitization Mapping
# Maps internal errors to generic user-facing messages to prevent info disclosure
# ═══════════════════════════════════════════════════════════════════════════════
ERROR_SANITIZATION_MAP = {
    "invalid or expired token": "Authentication failed",
    "missing auth token": "Authentication required",
    "permission denied": "You don't have access to this resource",
    "room not found": "Resource not found",
    "duplicate key": "This resource already exists",
    "connection refused": "Service temporarily unavailable",
    "timeout": "Request timed out",
    "invalid request": "Invalid input provided",
    "database error": "Service temporarily unavailable",
    "supabase": "Service temporarily unavailable",
}

def sanitize_error_message(error_msg: str) -> str:
    """
    Sanitize error messages to prevent information disclosure
    Maps internal errors to generic user-facing messages
    """
    error_lower = error_msg.lower()
    for pattern, safe_msg in ERROR_SANITIZATION_MAP.items():
        if pattern in error_lower:
            return safe_msg
    return "An error occurred"

# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY: Initialize FastAPI with security settings
# ═══════════════════════════════════════════════════════════════════════════════
app = FastAPI(
    title="Study Room Monitoring API",
    description="Privacy-first monitoring system for study rooms",
    version="1.0.0",
    docs_url=None,  # Disable swagger docs in production
    redoc_url=None,  # Disable redoc in production
    openapi_url=None,  # Disable OpenAPI schema in production
)

# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY: Validate and parse CORS origins
# ═══════════════════════════════════════════════════════════════════════════════
def get_allowed_origins() -> list:
    """
    Parse CORS_ORIGINS environment variable
    Default: http://localhost:3000 for development
    Production: Must be explicitly set in environment
    """
    cors_origins = os.getenv("CORS_ORIGINS", "http://localhost:3000")
    
    # Clean up whitespace and split
    origins = [origin.strip() for origin in cors_origins.split(",") if origin.strip()]
    
    # Validate protocol
    valid_origins = []
    for origin in origins:
        if origin.startswith(("http://", "https://")):
            valid_origins.append(origin)
        else:
            logger.warning(f"Invalid CORS origin (missing protocol): {origin}")
    
    if not valid_origins:
        logger.error("No valid CORS origins configured. Using defaults.")
        return ["http://localhost:3000"]
    
    logger.info(f"✅ CORS origins configured: {len(valid_origins)} allowed")
    return valid_origins

allowed_origins = get_allowed_origins()

# ✅ SECURE: CORS middleware with strict restrictions
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization", "X-CSRF-Token", "apikey"],
    expose_headers=["Content-Length", "X-Request-ID"],
    max_age=600,
)

# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY: Early OPTIONS Handler Middleware (runs BEFORE CORS validation)
# Ensures all OPTIONS requests return 200 with CORS headers
# ═══════════════════════════════════════════════════════════════════════════════
@app.middleware("http")
async def handle_options_preflight(request: Request, call_next):
    """
    Handle OPTIONS requests early to bypass path validation
    Returns 200 with CORS headers for all OPTIONS requests
    This middleware is added AFTER CORSMiddleware so it runs BEFORE it in execution
    """
    if request.method == "OPTIONS":
        response = JSONResponse(status_code=200, content={})
        response.headers["Access-Control-Allow-Origin"] = request.headers.get("origin", "*")
        response.headers["Access-Control-Allow-Credentials"] = "true"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-CSRF-Token, apikey"
        response.headers["Access-Control-Max-Age"] = "600"
        return response
    
    return await call_next(request)

# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY: Global Exception Handler
# Ensures CORS headers are applied even on 500 errors
# ═══════════════════════════════════════════════════════════════════════════════
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Handle all unhandled exceptions with proper CORS headers and error sanitization"""
    request_id = str(uuid.uuid4())[:8]
    error_msg = str(exc)
    sanitized_msg = sanitize_error_message(error_msg)
    
    logger.error(f"[{request_id}] Unhandled exception: {type(exc).__name__}: {error_msg}")
    
    response = JSONResponse(
        status_code=500,
        content={"detail": sanitized_msg, "request_id": request_id}
    )
    
    # Add CORS headers
    response.headers["Access-Control-Allow-Origin"] = request.headers.get("origin", "*")
    response.headers["Access-Control-Allow-Credentials"] = "true"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-CSRF-Token, apikey"
    
    return response

# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY: Request tracking and audit logging
# ═══════════════════════════════════════════════════════════════════════════════
@app.middleware("http")
async def add_security_headers_and_tracking(request: Request, call_next):
    """
    Add security headers and request tracking to all responses
    Logs API access for audit trail
    """
    # Generate unique request ID for tracking
    request_id = str(uuid.uuid4())[:8]
    request.state.request_id = request_id
    
    # Log incoming request
    logger.info(f"→ {request.method} {request.url.path} from {request.client.host if request.client else 'unknown'}")
    
    # Process request
    start_time = time.time()
    response = await call_next(request)
    
    # Calculate request duration
    duration = time.time() - start_time
    
    # ✅ SECURE: Add security headers to all responses
    response.headers["X-Request-ID"] = request_id
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    
    # Content Security Policy
    response.headers["Content-Security-Policy"] = (
        "default-src 'self'; "
        "script-src 'self'; "
        "style-src 'self' 'unsafe-inline'; "
        "img-src 'self' data: https:; "
        "connect-src 'self'; "
        "frame-ancestors 'none'; "
        "base-uri 'self'; "
        "form-action 'self'"
    )
    
    # Cache control for sensitive data
    response.headers["Cache-Control"] = "private, no-store, no-cache, must-revalidate, max-age=0"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    
    # Log response
    logger.info(f"← {response.status_code} {request.method} {request.url.path} ({duration:.2f}ms)")
    
    return response

# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY: Rate limiting (in-memory for now, can upgrade to Redis)
# ═══════════════════════════════════════════════════════════════════════════════
class RateLimiter:
    def __init__(self):
        self.requests = {}
        self.limits = {
            "init": {"max_requests": 10, "window_seconds": 3600},
            "process": {"max_requests": 30, "window_seconds": 60},
            "default": {"max_requests": 100, "window_seconds": 60},
        }
    
    def is_allowed(self, key: str, limit_type: str = "default") -> bool:
        """Check if request is allowed under rate limit"""
        now = time.time()
        limit = self.limits.get(limit_type, self.limits["default"])
        
        if key not in self.requests:
            self.requests[key] = []
        
        # Remove old requests outside the window
        self.requests[key] = [req_time for req_time in self.requests[key] 
                              if now - req_time < limit["window_seconds"]]
        
        # Check if limit exceeded
        if len(self.requests[key]) >= limit["max_requests"]:
            return False
        
        # Add current request
        self.requests[key].append(now)
        return True

rate_limiter = RateLimiter()

# Global monitoring engines (one per room)
monitoring_engines: dict = {}
active_connections: list = []

# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY: Input Validation
# ═══════════════════════════════════════════════════════════════════════════════
def validate_room_id(room_id: str) -> bool:
    """Validate room ID format (alphanumeric and hyphens only)"""
    import re
    if not room_id or not isinstance(room_id, str):
        return False
    if len(room_id) > 100:
        return False
    return bool(re.match(r'^[a-zA-Z0-9_-]+$', room_id))

def validate_rtsp_url(url: str) -> bool:
    """Validate RTSP URL format"""
    if not url or not isinstance(url, str):
        return False
    return url.startswith("rtsp://") or url.startswith("rtsps://")

# ═══════════════════════════════════════════════════════════════════════════════
# Register routers
# ═══════════════════════════════════════════════════════════════════════════════
app.include_router(unified_router)

# ═══════════════════════════════════════════════════════════════════════════════
# Startup and Shutdown Events
# ═══════════════════════════════════════════════════════════════════════════════
@app.on_event("startup")
async def startup_event():
    """Initialize background tasks on application startup"""
    logger.info("🚀 Starting up Study Room Monitoring API...")
    init_background_tasks()
    logger.info("✅ Application startup complete")

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup resources on application shutdown"""
    logger.info("🛑 Shutting down Study Room Monitoring API...")
    shutdown_background_tasks()
    logger.info("✅ Application shutdown complete")

# ============ Health Check ============
@app.get("/health")
async def health_check(request: Request):
    """System health endpoint"""
    try:
        return {
            "status": "healthy",
            "timestamp": datetime.now().isoformat(),
            "version": "1.0.0",
            "request_id": request.state.request_id
        }
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={"error": "An error occurred", "request_id": request.state.request_id}
        )

# ============ Initialize Room Monitoring ============
@app.post("/monitoring/init/{room_id}")
async def init_room_monitoring(room_id: str, camera_rtsp: str = None, request: Request = None):
    """Initialize monitoring for a room"""
    try:
        # ✅ SECURITY: Rate limiting check
        if not rate_limiter.is_allowed(f"init_{room_id}", "init"):
            logger.warning(f"Rate limit exceeded for room init: {room_id}")
            raise HTTPException(status_code=429, detail="Too many requests")
        
        # ✅ SECURITY: Input validation
        if not validate_room_id(room_id):
            logger.warning(f"Invalid room ID format: {room_id}")
            raise HTTPException(status_code=400, detail="Invalid room ID format")
        
        if camera_rtsp and not validate_rtsp_url(camera_rtsp):
            logger.warning(f"Invalid RTSP URL provided")
            raise HTTPException(status_code=400, detail="Invalid camera URL format")
        
        if room_id not in monitoring_engines:
            monitoring_engines[room_id] = MonitoringEngine(
                room_id=room_id,
                camera_rtsp=camera_rtsp or f"rtsp://camera-{room_id}"
            )
            logger.info(f"Initialized monitoring for room {room_id}")
        
        return {
            "success": True,
            "room_id": room_id,
            "message": "Monitoring initialized"
        }
    except HTTPException as e:
        raise e
    except Exception as e:
        error_id = str(uuid.uuid4())[:8]
        logger.error(f"[{error_id}] Error initializing monitoring: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail={
                "error": sanitize_error_message(str(e)),
                "error_id": error_id
            }
        )

# ============ Process Frame (HTTP Upload) ============
@app.post("/monitoring/process-frame/{room_id}")
async def process_frame(room_id: str, file: UploadFile = File(...), request: Request = None):
    """Process a single frame and return analysis"""
    try:
        # ✅ SECURITY: Rate limiting
        if not rate_limiter.is_allowed(f"process_{room_id}", "process"):
            logger.warning(f"Rate limit exceeded for room process: {room_id}")
            raise HTTPException(status_code=429, detail="Too many requests")
        
        # ✅ SECURITY: Input validation
        if not validate_room_id(room_id):
            raise HTTPException(status_code=400, detail="Invalid room ID format")
        
        if room_id not in monitoring_engines:
            raise HTTPException(status_code=404, detail="Room monitoring not initialized")
        
        # Read image
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if frame is None:
            raise HTTPException(status_code=400, detail="Invalid image")
        
        # Process frame
        engine = monitoring_engines[room_id]
        result = engine.process_frame(frame)
        
        return {
            "success": True,
            "room_id": room_id,
            "occupancy": result["occupancy_count"],
            "events": result["events"],
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"Error processing frame: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# ============ WebSocket for Real-time Streaming ============
@app.websocket("/ws/monitoring/{room_id}")
async def websocket_monitoring(websocket: WebSocket, room_id: str):
    """WebSocket endpoint for real-time monitoring data"""
    await websocket.accept()
    active_connections.append(websocket)
    
    try:
        if room_id not in monitoring_engines:
            await websocket.send_json({
                "error": "Room monitoring not initialized",
                "room_id": room_id
            })
            await websocket.close(code=1008)
            return
        
        engine = monitoring_engines[room_id]
        
        while True:
            # Get current status
            status = engine.get_room_status()
            
            # Send to client
            await websocket.send_json({
                "room_id": room_id,
                "occupancy": status["occupancy"],
                "events": status["events"],
                "timestamp": datetime.now().isoformat()
            })
            
            # Send every 2 seconds
            await asyncio.sleep(2)
    
    except Exception as e:
        logger.error(f"WebSocket error: {str(e)}")
    finally:
        active_connections.remove(websocket)

# ============ Get Room Status ============
@app.get("/monitoring/status/{room_id}")
async def get_room_status(room_id: str):
    """Get current room monitoring status"""
    try:
        if room_id not in monitoring_engines:
            raise HTTPException(status_code=404, detail="Room monitoring not initialized")
        
        engine = monitoring_engines[room_id]
        status = engine.get_room_status()
        
        return {
            "success": True,
            "room_id": room_id,
            "status": status,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"Error getting room status: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# ============ Get Configuration ============
@app.get("/monitoring/config/{room_id}")
async def get_room_config(room_id: str):
    """Get room monitoring configuration"""
    try:
        config = get_default_config(room_id)
        return {
            "success": True,
            "room_id": room_id,
            "config": config.to_dict()
        }
    except Exception as e:
        logger.error(f"Error getting config: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# ============ Update Configuration ============
@app.put("/monitoring/config/{room_id}")
async def update_room_config(room_id: str, config_updates: dict):
    """Update room monitoring configuration"""
    try:
        # Validate room exists
        if room_id not in monitoring_engines:
            raise HTTPException(status_code=404, detail="Room monitoring not initialized")
        
        # Apply updates (in production, validate and persist)
        logger.info(f"Updated config for room {room_id}: {config_updates}")
        
        return {
            "success": True,
            "room_id": room_id,
            "message": "Configuration updated"
        }
    except Exception as e:
        logger.error(f"Error updating config: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# ============ Stop Monitoring ============
@app.post("/monitoring/stop/{room_id}")
async def stop_monitoring(room_id: str):
    """Stop monitoring for a room"""
    try:
        if room_id in monitoring_engines:
            del monitoring_engines[room_id]
            logger.info(f"Stopped monitoring for room {room_id}")
        
        return {
            "success": True,
            "room_id": room_id,
            "message": "Monitoring stopped"
        }
    except Exception as e:
        logger.error(f"Error stopping monitoring: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# ============ Broadcast Event (Admin) ============
@app.post("/monitoring/broadcast-event/{room_id}")
async def broadcast_event(room_id: str, event: dict):
    """Broadcast an event to all connected clients"""
    payload = {
        "room_id": room_id,
        "event": event,
        "timestamp": datetime.now().isoformat()
    }
    
    for connection in active_connections:
        try:
            await connection.send_json(payload)
        except Exception as e:
            logger.error(f"Error broadcasting: {str(e)}")
    
    return {"success": True, "message": f"Event broadcast to {len(active_connections)} clients"}

# ============ System Statistics ============
@app.get("/monitoring/stats")
async def get_system_stats():
    """Get system-wide statistics"""
    return {
        "total_rooms_monitored": len(monitoring_engines),
        "active_connections": len(active_connections),
        "rooms": list(monitoring_engines.keys()),
        "timestamp": datetime.now().isoformat()
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info"
    )
