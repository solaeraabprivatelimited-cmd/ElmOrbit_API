"""
Background Tasks for Study Room Management
Handles automatic cleanup of empty rooms and maintenance tasks
"""

import asyncio
import logging
from datetime import datetime, timedelta
from typing import Optional
from functools import wraps
import os
from dotenv import load_dotenv

try:
    from apscheduler.schedulers.background import BackgroundScheduler
    from apscheduler.triggers.cron import CronTrigger
    SCHEDULER_AVAILABLE = True
except ImportError:
    SCHEDULER_AVAILABLE = False
    logging.warning("APScheduler not installed. Background tasks will not run. Install: pip install apscheduler")

from utils.monitoring_config import get_supabase_client

load_dotenv()
logger = logging.getLogger(__name__)

class BackgroundTaskManager:
    """Manages scheduled background tasks for room cleanup and maintenance"""
    
    def __init__(self):
        self.scheduler = None
        self.is_running = False
        self._init_scheduler()
    
    def _init_scheduler(self):
        """Initialize APScheduler"""
        if not SCHEDULER_AVAILABLE:
            logger.warning("APScheduler not available. Background room cleanup disabled.")
            return
        
        try:
            self.scheduler = BackgroundScheduler(daemon=True)
            # Schedule room cleanup to run every hour
            self.scheduler.add_job(
                self.cleanup_empty_rooms,
                CronTrigger(minute=0),  # Run at the start of every hour
                id='cleanup_empty_rooms',
                name='Cleanup empty study rooms',
                replace_existing=True,
                misfire_grace_time=60
            )
            logger.info("✓ Background task scheduler initialized")
        except Exception as e:
            logger.error(f"✗ Failed to initialize scheduler: {e}")
    
    def start(self):
        """Start the background scheduler"""
        if not self.scheduler:
            logger.warning("Scheduler not available. Background tasks will not run.")
            return
        
        try:
            if not self.scheduler.running:
                self.scheduler.start()
                self.is_running = True
                logger.info("✓ Background task scheduler started")
        except Exception as e:
            logger.error(f"✗ Failed to start scheduler: {e}")
    
    def stop(self):
        """Stop the background scheduler"""
        if self.scheduler and self.scheduler.running:
            self.scheduler.shutdown()
            self.is_running = False
            logger.info("✓ Background task scheduler stopped")
    
    async def cleanup_empty_rooms(self):
        """
        Clean up rooms that have been empty (no participants) for 24+ hours
        
        Process:
        1. Check if participants still exist in the room
        2. Mark room as empty if no active participants
        3. Delete room if empty for 24+ hours
        
        Returns:
            dict: Status of cleanup operation with deleted_count
        """
        try:
            client = get_supabase_client()
            
            # Call the Supabase function to delete old empty rooms
            response = client.rpc('cleanup_empty_rooms').execute()
            
            deleted_count = response.data[0]['deleted_count'] if response.data else 0
            
            if deleted_count > 0:
                logger.info(f"✓ Cleanup task completed: Deleted {deleted_count} empty rooms")
            else:
                logger.debug("✓ Cleanup task completed: No rooms eligible for deletion")
            
            return {
                "status": "success",
                "deleted_count": deleted_count,
                "timestamp": datetime.utcnow().isoformat()
            }
        except Exception as e:
            logger.error(f"✗ Room cleanup task failed: {str(e)}", exc_info=True)
            return {
                "status": "error",
                "error": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
    
    async def mark_room_empty(self, room_id: str) -> bool:
        """
        Mark a room as empty when the last participant leaves
        
        Args:
            room_id: UUID of the room
            
        Returns:
            bool: True if successful, False otherwise
        """
        try:
            client = get_supabase_client()
            
            # Check if any participants are still connected (not left)
            response = client.table('webrtc_participants').select('id').eq(
                'room_id', room_id
            ).is_('left_at', True).execute()
            
            # If no active participants, mark room as emptied
            if not response.data or len(response.data) == 0:
                client.table('webrtc_rooms').update({
                    'emptied_at': datetime.utcnow().isoformat()
                }).eq('id', room_id).execute()
                
                logger.info(f"✓ Marked room {room_id} as empty at {datetime.utcnow()}")
                return True
            
            return False
        except Exception as e:
            logger.error(f"✗ Failed to mark room {room_id} as empty: {e}")
            return False
    
    async def unmark_room_empty(self, room_id: str) -> bool:
        """
        Unmark a room as empty when a participant joins an empty room
        
        Args:
            room_id: UUID of the room
            
        Returns:
            bool: True if successful, False otherwise
        """
        try:
            client = get_supabase_client()
            
            client.table('webrtc_rooms').update({
                'emptied_at': None
            }).eq('id', room_id).execute()
            
            logger.info(f"✓ Unmarked room {room_id} as empty (participant joined)")
            return True
        except Exception as e:
            logger.error(f"✗ Failed to unmark room {room_id}: {e}")
            return False


# Global instance
background_tasks = BackgroundTaskManager()


def init_background_tasks():
    """Initialize and start background tasks - call this from main app startup"""
    background_tasks.start()


def shutdown_background_tasks():
    """Shutdown background tasks - call this from app shutdown"""
    background_tasks.stop()
