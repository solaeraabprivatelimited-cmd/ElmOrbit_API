"""
Privacy-First Study Room Monitoring System
Core behavior detection engine using MediaPipe and OpenCV
"""

import cv2
import mediapipe as mp
import numpy as np
from dataclasses import dataclass
from typing import List, Dict, Tuple, Optional
from enum import Enum
import math
from collections import deque

class BehaviorType(Enum):
    NORMAL = "normal"
    IDLE_TOO_LONG = "idle_too_long"
    UNUSUAL_POSTURE = "unusual_posture"
    RAPID_MOVEMENT = "rapid_movement"
    FALL_DETECTED = "fall_detected"
    LOITERING = "loitering"
    MULTIPLE_PEOPLE = "multiple_people"

@dataclass
class SkeletalKeypoint:
    """Represents a single joint in the skeleton"""
    id: int
    x: float
    y: float
    z: float
    confidence: float
    
    def to_dict(self):
        return {
            'id': self.id,
            'x': self.x,
            'y': self.y,
            'z': self.z,
            'confidence': self.confidence
        }

@dataclass
class PersonSkeleton:
    """Complete skeleton data for one person"""
    person_id: int
    keypoints: List[SkeletalKeypoint]
    timestamp: float
    pose_angle: float
    velocity: float
    is_standing: bool
    is_idle: bool
    idle_duration: float
    detected_behaviors: List[BehaviorType]

class PoseDetector:
    """MediaPipe-based pose detector (privacy-first skeleton extraction)"""
    
    def __init__(self, model_complexity=1, min_detection_confidence=0.7):
        try:
            # Initialize MediaPipe with error handling
            if not hasattr(mp, 'solutions'):
                raise RuntimeError("MediaPipe 'solutions' module not accessible. Verify installation.")
            
            self.mp_pose = mp.solutions.pose
            self.pose = self.mp_pose.Pose(
                static_image_mode=False,
                model_complexity=model_complexity,
                enable_segmentation=False,  # Don't need segmentation for privacy
                min_detection_confidence=min_detection_confidence
            )
            self.mp_drawing = mp.solutions.drawing_utils
        except Exception as e:
            raise RuntimeError(
                f"Failed to initialize MediaPipe PoseDetector: {type(e).__name__}: {str(e)}\n"
                f"MediaPipe version: {mp.__version__ if hasattr(mp, '__version__') else 'unknown'}\n"
                f"MediaPipe attributes: {dir(mp)}"
            )
        
    def detect(self, frame: np.ndarray) -> List[PersonSkeleton]:
        """
        Detect skeletons in frame
        Returns only keypoints (no identity, no RGB)
        """
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = self.pose.process(frame_rgb)
        
        skeletons = []
        if results.pose_landmarks:
            keypoints = []
            for idx, landmark in enumerate(results.pose_landmarks.landmark):
                keypoint = SkeletalKeypoint(
                    id=idx,
                    x=landmark.x,
                    y=landmark.y,
                    z=landmark.z,
                    confidence=landmark.visibility
                )
                keypoints.append(keypoint)
            
            # Calculate pose properties
            pose_angle = self._calculate_pose_angle(keypoints)
            is_standing = self._is_standing(keypoints)
            
            skeleton = PersonSkeleton(
                person_id=0,  # Single person detection
                keypoints=keypoints,
                timestamp=0,
                pose_angle=pose_angle,
                velocity=0.0,
                is_standing=is_standing,
                is_idle=False,
                idle_duration=0.0,
                detected_behaviors=[]
            )
            skeletons.append(skeleton)
        
        return skeletons
    
    def _calculate_pose_angle(self, keypoints: List[SkeletalKeypoint]) -> float:
        """Calculate aggregate body posture angle"""
        if len(keypoints) < 15:
            return 0.0
        
        # Use shoulder to hip angle as reference
        left_shoulder = keypoints[11]  # Left shoulder
        right_shoulder = keypoints[12]  # Right shoulder
        left_hip = keypoints[23]  # Left hip
        right_hip = keypoints[24]  # Right hip
        
        shoulder_mid = ((left_shoulder.x + right_shoulder.x) / 2,
                        (left_shoulder.y + right_shoulder.y) / 2)
        hip_mid = ((left_hip.x + right_hip.x) / 2,
                   (left_hip.y + right_hip.y) / 2)
        
        angle = math.atan2(hip_mid[1] - shoulder_mid[1],
                          hip_mid[0] - shoulder_mid[0])
        return math.degrees(angle)
    
    def _is_standing(self, keypoints: List[SkeletalKeypoint]) -> bool:
        """Check if person is standing (vs sitting)"""
        if len(keypoints) < 26:
            return True
        
        # Hip and ankle positions
        left_hip = keypoints[23]
        right_hip = keypoints[24]
        left_ankle = keypoints[27]
        right_ankle = keypoints[28]
        
        hip_y = (left_hip.y + right_hip.y) / 2
        ankle_y = (left_ankle.y + right_ankle.y) / 2
        
        # If hip-to-ankle distance is large vertically, person is standing
        return (ankle_y - hip_y) > 0.15
    
    def draw_skeleton(self, frame: np.ndarray, skeletons: List[PersonSkeleton]) -> np.ndarray:
        """Draw stick figure (skeleton visualization only, privacy-friendly)"""
        h, w, _ = frame.shape
        output = frame.copy()
        
        try:
            for skeleton in skeletons:
                # Draw connections
                connections = mp.solutions.pose.POSE_CONNECTIONS
                for connection in connections:
                    start, end = connection
                    if start < len(skeleton.keypoints) and end < len(skeleton.keypoints):
                        start_kp = skeleton.keypoints[start]
                        end_kp = skeleton.keypoints[end]
                        
                        if start_kp.confidence > 0.5 and end_kp.confidence > 0.5:
                            start_pos = (int(start_kp.x * w), int(start_kp.y * h))
                            end_pos = (int(end_kp.x * w), int(end_kp.y * h))
                            cv2.line(output, start_pos, end_pos, (0, 255, 0), 2)
        except AttributeError as e:
            print(f"Warning: Could not draw skeleton connections: {e}")
        
        return output
            
            # Draw keypoints (small circles)
            for kp in skeleton.keypoints:
                if kp.confidence > 0.5:
                    pos = (int(kp.x * w), int(kp.y * h))
                    cv2.circle(output, pos, 5, (255, 0, 0), -1)
        
        return output

class BehaviorAnalyzer:
    """Analyzes skeletal data for anomalies and unsafe behaviors"""
    
    def __init__(self, idle_threshold_sec=300, movement_threshold=0.05):
        self.idle_threshold = idle_threshold_sec
        self.movement_threshold = movement_threshold
        self.person_tracking = {}  # Track each person's history
        self.frame_count = 0
    
    def analyze(self, skeletons: List[PersonSkeleton]) -> List[Dict]:
        """Analyze frame for behaviors"""
        self.frame_count += 1
        events = []
        
        # Track people across frames
        for skeleton in skeletons:
            behaviors = self._detect_behaviors(skeleton)
            skeleton.detected_behaviors = behaviors
            
            for behavior in behaviors:
                events.append({
                    'type': behavior.value,
                    'person_id': skeleton.person_id,
                    'confidence': 0.85,
                    'timestamp': self.frame_count
                })
        
        # Room-level analysis
        if len(skeletons) > 2:
            events.append({
                'type': 'multiple_people',
                'count': len(skeletons),
                'confidence': 0.9
            })
        
        return events
    
    def _detect_behaviors(self, skeleton: PersonSkeleton) -> List[BehaviorType]:
        """Detect specific behaviors from skeleton"""
        behaviors = []
        
        # Fall detection: sudden drop in posture
        if skeleton.pose_angle > 60:
            behaviors.append(BehaviorType.FALL_DETECTED)
        
        # Unusual posture: extreme angles
        if abs(skeleton.pose_angle) > 45:
            behaviors.append(BehaviorType.UNUSUAL_POSTURE)
        
        # Rapid movement
        if skeleton.velocity > 0.3:
            behaviors.append(BehaviorType.RAPID_MOVEMENT)
        
        # Idle too long
        if skeleton.is_idle and skeleton.idle_duration > self.idle_threshold:
            behaviors.append(BehaviorType.IDLE_TOO_LONG)
        
        return behaviors

class MonitoringEngine:
    """Main orchestrator for room monitoring"""
    
    def __init__(self, room_id: str, camera_rtsp: str):
        self.room_id = room_id
        self.camera_rtsp = camera_rtsp
        self.pose_detector = PoseDetector()
        self.behavior_analyzer = BehaviorAnalyzer()
        self.frame_buffer = deque(maxlen=30)  # 30 frame history
        self.is_running = False
    
    def process_frame(self, frame: np.ndarray) -> Dict:
        """Process single frame and return monitoring data"""
        # Detect skeletons
        skeletons = self.pose_detector.detect(frame)
        
        # Analyze behaviors
        events = self.behavior_analyzer.analyze(skeletons)
        
        # Store frame data
        frame_data = {
            'room_id': self.room_id,
            'occupancy_count': len(skeletons),
            'skeletons': [
                {
                    'person_id': s.person_id,
                    'keypoints': [kp.to_dict() for kp in s.keypoints],
                    'pose_angle': s.pose_angle,
                    'velocity': s.velocity,
                    'is_standing': s.is_standing,
                    'behaviors': [b.value for b in s.detected_behaviors]
                } for s in skeletons
            ],
            'events': events,
            'timestamp': cv2.getTickCount()
        }
        
        self.frame_buffer.append(frame_data)
        return frame_data
    
    def get_room_status(self) -> Dict:
        """Get current room monitoring status"""
        if not self.frame_buffer:
            return {'occupancy': 0, 'events': []}
        
        latest = self.frame_buffer[-1]
        return {
            'occupancy': latest['occupancy_count'],
            'events': latest['events'],
            'frame_count': len(self.frame_buffer)
        }

# Export main class
__all__ = ['MonitoringEngine', 'PoseDetector', 'BehaviorAnalyzer', 'PersonSkeleton']
