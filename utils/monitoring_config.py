"""
Study Room Monitoring System - Configuration
Define behavior rules, thresholds, and alerts
"""

import json
from enum import Enum

class RoomConfiguration:
    """Configuration for study room monitoring"""

    def __init__(self, room_id: str):
        self.room_id = room_id
        self.thresholds = {
            'idle_threshold_seconds': 300,      # Alert if person idle for 5+ min
            'movement_threshold': 0.05,          # Significant movement
            'pose_angle_threshold': 45,          # Extreme posture alert
            'max_occupancy': 4,                  # Fire alert if exceeded
            'min_detection_confidence': 0.7,     # Pose detection confidence
        }

        self.behavior_rules = {
            'fall_detection': {
                'enabled': True,
                'pose_angle_min': 60,
                'alert_level': 'critical',
                'description': 'Person appears to have fallen'
            },
            'unusual_posture': {
                'enabled': True,
                'angle_threshold': 45,
                'duration_seconds': 10,
                'alert_level': 'medium',
                'description': 'Unusual body posture detected'
            },
            'rapid_movement': {
                'enabled': True,
                'velocity_threshold': 0.3,
                'alert_level': 'medium',
                'description': 'Rapid movement detected'
            },
            'occupancy_exceeded': {
                'enabled': True,
                'max_people': 4,
                'alert_level': 'high',
                'description': 'Room occupancy exceeded'
            },
            'loitering': {
                'enabled': True,
                'idle_threshold_seconds': 600,  # 10 minutes
                'alert_level': 'medium',
                'description': 'Person idle for too long'
            },
            'no_movement': {
                'enabled': True,
                'no_activity_threshold_seconds': 1800,  # 30 minutes
                'alert_level': 'high',
                'description': 'No movement detected for extended period (possible health emergency)'
            }
        }

        self.alert_config = {
            'critical': {
                'notification_channels': ['email', 'sms', 'webhook'],
                'alert_delay_seconds': 0,
                'cooldown_minutes': 60
            },
            'high': {
                'notification_channels': ['email', 'webhook'],
                'alert_delay_seconds': 30,
                'cooldown_minutes': 30
            },
            'medium': {
                'notification_channels': ['webhook'],
                'alert_delay_seconds': 60,
                'cooldown_minutes': 15
            },
            'low': {
                'notification_channels': [],
                'alert_delay_seconds': 300,
                'cooldown_minutes': 5
            }
        }

        self.privacy_settings = {
            'store_raw_video': False,           # Never store raw video
            'store_skeleton_only': True,        # Store only keypoints
            'skeleton_retention_days': 7,       # Auto-delete after 7 days
            'blur_faces_if_needed': False,      # Not needed with skeleton-only
            'anonymize_person_ids': True,       # Use only person index, not identity
            'event_retention_days': 30,         # Auto-delete old events
        }

        self.processing_config = {
            'fps_target': 15,                   # Process at 15 FPS
            'frame_resize_width': 640,          # Resize for faster processing
            'frame_resize_height': 480,
            'batch_processing': False,          # Process frames individually
            'gpu_enabled': True,                # Use GPU if available
            'model_complexity': 1,              # 0=lite, 1=full, 2=heavy
        }

    def to_dict(self):
        """Export configuration as dictionary"""
        return {
            'room_id': self.room_id,
            'thresholds': self.thresholds,
            'behavior_rules': self.behavior_rules,
            'alert_config': self.alert_config,
            'privacy_settings': self.privacy_settings,
            'processing_config': self.processing_config,
        }

    def to_json(self):
        """Export configuration as JSON"""
        return json.dumps(self.to_dict(), indent=2, default=str)


# Predefined event types
EVENT_TYPES = {
    'occupancy_change': 'Room occupancy changed',
    'unusual_behavior': 'Unusual behavior detected',
    'intrusion_alert': 'Unauthorized entry detected',
    'fall_detected': 'Person appears to have fallen',
    'loitering': 'Person idle in room',
    'overcapacity': 'Room exceeds maximum occupancy',
    'camera_offline': 'Camera connection lost',
    'processing_error': 'Monitoring system error',
}

# Alert severity mapping
SEVERITY_LEVELS = {
    'low': 0,
    'medium': 1,
    'high': 2,
    'critical': 3,
}

# System status states
SYSTEM_STATES = {
    'healthy': 'System operating normally',
    'degraded': 'High resource usage or processing lag',
    'offline': 'Camera offline or connection lost',
    'error': 'System error occurred',
}


def get_default_config(room_id: str) -> RoomConfiguration:
    """Get default configuration for a room"""
    return RoomConfiguration(room_id)


# ═══════════════════════════════════════════════════════════════════════════════
# Supabase Client
# ═══════════════════════════════════════════════════════════════════════════════

def get_supabase_client():
    """
    ✅ SECURE: Get Supabase client for database operations
    Uses environment variables for credentials
    """
    import os
    from supabase import create_client
    from dotenv import load_dotenv
    
    load_dotenv()
    
    supabase_url = os.getenv("SUPABASE_URL", "")
    supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    
    if not supabase_url or not supabase_key:
        raise ValueError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables required")
    
    return create_client(supabase_url, supabase_key)


def merge_configs(base_config: dict, override_config: dict) -> dict:
    """Merge custom config with base config"""
    result = base_config.copy()
    for key, value in override_config.items():
        if isinstance(value, dict) and key in result:
            result[key].update(value)
        else:
            result[key] = value
    return result


# Example usage
if __name__ == '__main__':
    config = get_default_config('room-001')
    print(config.to_json())
