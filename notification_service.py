"""
Notification Service - Backend
Handles email, SMS, and webhook notifications for alerts

Requires environment variables:
- SENDGRID_API_KEY: SendGrid API key for email
- TWILIO_ACCOUNT_SID: Twilio account SID for SMS
- TWILIO_AUTH_TOKEN: Twilio auth token
- TWILIO_PHONE_NUMBER: Twilio phone number to send SMS from
"""

import os
import json
import httpx
import logging
from typing import Optional, List, Dict, Any
from enum import Enum
from datetime import datetime
from pydantic import BaseModel, EmailStr

logger = logging.getLogger(__name__)


class AlertSeverity(str, Enum):
    """Alert severity levels"""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class NotificationChannel(str, Enum):
    """Supported notification channels"""
    IN_APP = "in_app"
    EMAIL = "email"
    SMS = "sms"
    WEBHOOK = "webhook"
    MULTI = "multi"


class AlertPayload(BaseModel):
    """Alert payload structure"""
    room_id: str
    event_type: str
    severity: AlertSeverity
    description: Optional[str] = None
    timestamp: str = None
    
    def __init__(self, **data):
        super().__init__(**data)
        if self.timestamp is None:
            self.timestamp = datetime.utcnow().isoformat()


class NotificationResult(BaseModel):
    """Result of a notification attempt"""
    success: bool
    method: str
    recipient: Optional[str] = None
    error: Optional[str] = None
    message_id: Optional[str] = None


class NotificationService:
    """Handles multi-channel notifications"""
    
    SENDGRID_API_KEY = os.getenv("SENDGRID_API_KEY")
    TWILIO_ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID")
    TWILIO_AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN")
    TWILIO_PHONE_NUMBER = os.getenv("TWILIO_PHONE_NUMBER")
    
    @classmethod
    async def send_email_alert(
        cls,
        alert: AlertPayload,
        recipient_email: str
    ) -> NotificationResult:
        """Send email alert via SendGrid"""
        
        if not cls.SENDGRID_API_KEY:
            logger.warning("⚠️ SendGrid API key not configured. Email notifications disabled.")
            return NotificationResult(success=False, method="email", error="API key not configured")
        
        try:
            subject = f"🚨 {alert.severity.upper()} Alert: {alert.event_type} in Room {alert.room_id}"
            
            email_content = f"""
            <h2>🚨 Study Room Alert</h2>
            <p><strong>Room ID:</strong> {alert.room_id}</p>
            <p><strong>Event Type:</strong> {alert.event_type}</p>
            <p><strong>Severity:</strong> <span style="color: {cls._get_severity_color(alert.severity)}">{alert.severity.upper()}</span></p>
            <p><strong>Description:</strong> {alert.description or 'N/A'}</p>
            <p><strong>Time:</strong> {datetime.fromisoformat(alert.timestamp).strftime('%Y-%m-%d %H:%M:%S UTC')}</p>
            <hr>
            <p><small>This is an automated alert from Lernova Study Room Monitoring</small></p>
            """
            
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    "https://api.sendgrid.com/v3/mail/send",
                    headers={
                        "Authorization": f"Bearer {cls.SENDGRID_API_KEY}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "personalizations": [
                            {
                                "to": [{"email": recipient_email}],
                                "subject": subject,
                            }
                        ],
                        "from": {
                            "email": "alerts@lernova.app",
                            "name": "Lernova Alerts",
                        },
                        "content": [
                            {
                                "type": "text/html",
                                "value": email_content,
                            }
                        ],
                    }
                )
            
            if response.status_code not in (200, 202):
                raise Exception(f"SendGrid API error: {response.text}")
            
            logger.info(f"✅ Email alert sent successfully to: {recipient_email}")
            return NotificationResult(success=True, method="email", recipient=recipient_email)
            
        except Exception as error:
            logger.error(f"❌ Failed to send email alert: {error}")
            return NotificationResult(success=False, method="email", error=str(error))
    
    @classmethod
    async def send_sms_alert(
        cls,
        alert: AlertPayload,
        recipient_phone: str
    ) -> NotificationResult:
        """Send SMS alert via Twilio"""
        
        if not all([cls.TWILIO_ACCOUNT_SID, cls.TWILIO_AUTH_TOKEN, cls.TWILIO_PHONE_NUMBER]):
            logger.warning("⚠️ Twilio credentials not configured. SMS notifications disabled.")
            return NotificationResult(success=False, method="sms", error="Credentials not configured")
        
        try:
            import base64
            
            message_body = f"🚨 ALERT: {alert.severity.upper()} - {alert.event_type} in Room {alert.room_id}. {alert.description or ''} Check Lernova for details."
            
            auth_string = base64.b64encode(
                f"{cls.TWILIO_ACCOUNT_SID}:{cls.TWILIO_AUTH_TOKEN}".encode()
            ).decode()
            
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"https://api.twilio.com/2010-04-01/Accounts/{cls.TWILIO_ACCOUNT_SID}/Messages.json",
                    auth=(cls.TWILIO_ACCOUNT_SID, cls.TWILIO_AUTH_TOKEN),
                    data={
                        "From": cls.TWILIO_PHONE_NUMBER,
                        "To": recipient_phone,
                        "Body": message_body,
                    }
                )
            
            if response.status_code not in (200, 201):
                raise Exception(f"Twilio API error: {response.text}")
            
            result_data = response.json()
            logger.info(f"✅ SMS alert sent successfully to: {recipient_phone}")
            return NotificationResult(
                success=True,
                method="sms",
                recipient=recipient_phone,
                message_id=result_data.get("sid")
            )
            
        except Exception as error:
            logger.error(f"❌ Failed to send SMS alert: {error}")
            return NotificationResult(success=False, method="sms", error=str(error))
    
    @classmethod
    async def send_webhook_alert(
        cls,
        alert: AlertPayload,
        webhook_url: str
    ) -> NotificationResult:
        """Send webhook alert"""
        
        if not webhook_url:
            logger.warning("⚠️ Webhook URL not provided. Webhook notification skipped.")
            return NotificationResult(success=False, method="webhook", error="URL not provided")
        
        try:
            payload = {
                "source": "lernova-monitoring",
                "alert": {
                    "room_id": alert.room_id,
                    "event_type": alert.event_type,
                    "severity": alert.severity,
                    "description": alert.description,
                    "timestamp": alert.timestamp,
                },
                "metadata": {
                    "sent_at": datetime.utcnow().isoformat(),
                    "version": "1.0",
                },
            }
            
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.post(
                    webhook_url,
                    json=payload,
                    headers={
                        "Content-Type": "application/json",
                        "User-Agent": "Lernova-Monitoring/1.0",
                    }
                )
            
            if response.status_code < 300:
                logger.info(f"✅ Webhook alert sent successfully to: {webhook_url}")
                return NotificationResult(success=True, method="webhook", recipient=webhook_url)
            else:
                raise Exception(f"Webhook returned {response.status_code}: {response.text}")
                
        except Exception as error:
            logger.error(f"❌ Failed to send webhook alert: {error}")
            return NotificationResult(success=False, method="webhook", error=str(error))
    
    @classmethod
    async def send_multi_channel_alert(
        cls,
        alert: AlertPayload,
        channels: List[NotificationChannel],
        contacts: Dict[str, Optional[str]]
    ) -> List[NotificationResult]:
        """Send alert to multiple channels simultaneously"""
        
        results = []
        
        for channel in channels:
            if channel == NotificationChannel.EMAIL:
                if contacts.get("email"):
                    result = await cls.send_email_alert(alert, contacts["email"])
                    results.append(result)
            
            elif channel == NotificationChannel.SMS:
                if contacts.get("phone"):
                    result = await cls.send_sms_alert(alert, contacts["phone"])
                    results.append(result)
            
            elif channel == NotificationChannel.WEBHOOK:
                if contacts.get("webhook"):
                    result = await cls.send_webhook_alert(alert, contacts["webhook"])
                    results.append(result)
            
            elif channel == NotificationChannel.IN_APP:
                logger.info("✅ In-app notification sent")
                results.append(NotificationResult(success=True, method="in_app"))
        
        success_count = sum(1 for r in results if r.success)
        logger.info(f"📊 Multi-channel alert: {success_count}/{len(results)} channels successful")
        
        return results
    
    @staticmethod
    def _get_severity_color(severity: AlertSeverity) -> str:
        """Get color for severity level"""
        colors = {
            AlertSeverity.CRITICAL: "#DC2626",
            AlertSeverity.HIGH: "#F97316",
            AlertSeverity.MEDIUM: "#EAB308",
            AlertSeverity.LOW: "#3B82F6",
        }
        return colors.get(severity, "#6B7280")
    
    @staticmethod
    def format_alert_summary(alert: AlertPayload) -> str:
        """Format alert for logging"""
        return f"[{alert.severity.upper()}] {alert.event_type} - Room {alert.room_id}"


# Convenience function
async def trigger_alert(
    room_id: str,
    event_type: str,
    severity: AlertSeverity,
    description: Optional[str] = None,
    channels: Optional[List[NotificationChannel]] = None,
    contacts: Optional[Dict[str, Optional[str]]] = None,
) -> List[NotificationResult]:
    """Convenience function to trigger an alert"""
    
    alert = AlertPayload(
        room_id=room_id,
        event_type=event_type,
        severity=severity,
        description=description,
    )
    
    if not channels:
        channels = [NotificationChannel.IN_APP]
    
    if not contacts:
        contacts = {}
    
    logger.info(f"🚨 {NotificationService.format_alert_summary(alert)}")
    
    results = await NotificationService.send_multi_channel_alert(alert, channels, contacts)
    return results
