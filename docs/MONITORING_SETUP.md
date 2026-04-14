# Privacy-First Study Room Monitoring System - Setup Guide

**See VERCEL_CLOUD_DEPLOYMENT.md for complete Vercel + Cloud hosting instructions.**

This guide covers local testing and development setup for the monitoring system.

---

## Architecture (Cloud-Only)

```
┌─────────────────────────────────────────────┐
│  Your Website - Vercel                      │
│  https://yourapp.vercel.app                 │
│  React Dashboard + Next.js API Routes       │
└─────────────────────────┬───────────────────┘
                          │ HTTP/WebSocket
                          │
┌─────────────────────────▼───────────────────┐
│  Monitoring API Server - VPS                │
│  https://monitoring.yourserver.com          │
│  Python FastAPI (Docker)                    │
│  - MediaPipe pose detection                 │
│  - Behavior analysis                        │
│  - Event processing                         │
│  - Camera stream handling                   │
└─────────────────────────┬───────────────────┘
                          │ SQL
┌─────────────────────────▼───────────────────┐
│  Supabase Database (Managed)                │
│  PostgreSQL + Row-level security            │
│  https://your-project.supabase.co           │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│  IP Cameras / RTSP Streams                  │
│  (Connected to monitoring server)           │
└─────────────────────────────────────────────┘
```

---

## Installation Steps

### 1. Database Setup (Supabase)

```bash
# Run migration
supabase migration up

# Or manually execute:
# supabase/migrations/20260414_002_study_room_monitoring.sql
```

Tables created:

- `study_rooms` - Room metadata
- `monitoring_events` - Event logs (7-day retention)
- `room_skeleton_snapshots` - Skeleton data (auto-purge)
- `monitoring_sessions` - Session history
- `behavior_rules` - Custom rules
- `alert_configurations` - Notification settings

### 2. Local Development (Testing Only)

```bash
# Install Python dependencies
pip install -r monitoring_requirements.txt

# Run monitoring server
python monitoring_server.py

# Server will be at http://localhost:8000
```

### 3. Docker Deployment (Production)

```bash
# Build Docker image
docker build -f Dockerfile.monitoring -t lernova-monitoring .

# Run with docker-compose
docker-compose -f docker-compose.monitoring.yml up -d

# View logs
docker logs lernova-monitoring
```

---

## Testing & Validation

### 1. Test API Server

```bash
# Health check
curl http://localhost:8000/health

# Should return: {"status": "healthy", ...}
```

### 2. Test Database Connection

```bash
curl -X POST http://localhost:8000/monitoring/init/test-room \
  -H "Content-Type: application/json"
```

### 3. Test Dashboard

Open browser: `http://localhost:3000/admin/monitoring/room-001`

---

## Environment Variables

Create `.env` file:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
CAMERA_RTSP=rtsp://camera-ip:554/stream
CORS_ORIGINS=http://localhost:3000,https://yourapp.vercel.app
PORT=8000
```

---

## API Endpoints

### Health Check

```bash
GET /health
```

### Initialize Monitoring

```bash
POST /monitoring/init/{room_id}
Body: { "camera_rtsp": "rtsp://..." }
```

### Get Status

```bash
GET /monitoring/status/{room_id}
```

### WebSocket

```javascript
const ws = new WebSocket("ws://localhost:8000/ws/monitoring/room-001");

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log("Occupancy:", data.occupancy);
  console.log("Events:", data.events);
};
```

---

## Deployment

**For complete Vercel + Cloud setup, see VERCEL_CLOUD_DEPLOYMENT.md**

To deploy:

1. Push code to GitHub
2. Deploy frontend to Vercel
3. Deploy API to Railway/Render
4. Configure environment variables
5. Test with real cameras

---

## Troubleshooting

### Module Import Error

```bash
# Make sure you're in the right directory
cd Lernova_API

# Reinstall dependencies
pip install -r monitoring_requirements.txt
```

### Camera Not Detected

Check RTSP URL or USB camera connection:

```bash
# Test camera
ffmpeg -rtsp_transport tcp -i rtsp://camera-ip/stream -t 5 output.mp4
```

### Database Connection Error

```bash
# Verify Supabase credentials in .env
# Test connection
curl -H "Authorization: Bearer YOUR_KEY" https://your-url.supabase.co/rest/v1/
```

---

**For complete setup instructions, refer to VERCEL_CLOUD_DEPLOYMENT.md**
