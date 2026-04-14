# Lernova Monitoring API

**Privacy-First Study Room Monitoring System - Backend Service**

🚀 **Status:** Production Ready | 🔒 **Security:** Phase 1 Complete | 📊 **API:** v1.0.0

This directory contains the complete FastAPI server for the study room monitoring system. It handles:

- Real-time pose detection using MediaPipe
- Behavior analysis and anomaly detection
- WebSocket streaming for live updates
- Database integration with Supabase
- Docker containerization for cloud deployment

**✅ SECURITY:** All endpoints include CORS restrictions, security headers, rate limiting, error sanitization, and request tracking.

---

## 📋 Security Features

### Phase 1: Critical Fixes (✅ Complete)

- ✅ **CORS Restrictions** - Strict whitelist (no wildcard accept)
- ✅ **Security Headers** - CSP, HSTS, X-Frame-Options, etc.
- ✅ **Error Sanitization** - Generic messages (no info disclosure)
- ✅ **Rate Limiting** - Per-endpoint limits to prevent abuse
- ✅ **Input Validation** - Room IDs and URLs validated
- ✅ **Request Tracking** - Unique request IDs for audit trail
- ✅ **Environment Variables** - All secrets from .env.local
- ✅ **Secure OTP** - crypto.getRandomValues() (not Math.random())
- ✅ **Token Storage** - sessionStorage only (cleared on close)

### Rate Limiting

| Endpoint                    | Limit | Window   |
| --------------------------- | ----- | -------- |
| `/monitoring/init`          | 10    | 1 hour   |
| `/monitoring/process-frame` | 30    | 1 minute |
| Others                      | 100   | 1 minute |

Exceeding limits returns `429 Too Many Requests`.

---

## 📁 Directory Structure

```
Lernova_API/
├── monitoring_server.py           # FastAPI application (main entry point)
├── monitoring_requirements.txt     # Python dependencies
├── Dockerfile.monitoring          # Docker build file
├── docker-compose.monitoring.yml  # Docker Compose configuration
├── .env                          # Environment template (commit to git)
├── .env.local                    # Actual credentials (DO NOT COMMIT)
├── .gitignore                    # Protect .env.local
├── utils/
│   ├── monitoring_core.py         # ML engine (MediaPipe + behavior analysis)
│   └── monitoring_config.py       # Configuration and rules
├── logs/
│   └── audit.log                 # Security audit trail
└── docs/
    ├── VERCEL_CLOUD_DEPLOYMENT.md # Complete cloud hosting guide
    └── MONITORING_SETUP.md        # Local development guide
```

---

## 🚀 Quick Start

### Development (Local)

```bash
# 1. Install dependencies
pip install -r monitoring_requirements.txt

# 2. Create .env.local from template
cp .env .env.local

# 3. Edit .env.local with credentials
nano .env.local

# 4. Run server
python monitoring_server.py

# Server: http://localhost:8000
# Health check: curl http://localhost:8000/health
```

### Production (Docker)

```bash
# Build image
docker build -f Dockerfile.monitoring -t lernova-monitoring .

# Run container
docker run -p 8000:8000 \
  -e SUPABASE_URL=your-url \
  -e SUPABASE_SERVICE_ROLE_KEY=your-key \
  lernova-monitoring
```

### Cloud Deployment

**See `docs/VERCEL_CLOUD_DEPLOYMENT.md` for complete instructions**

Deploy to Railway or Render:

1. Push to GitHub
2. Connect to Railway/Render
3. Set environment variables
4. Auto-deploys!

---

## 🔧 Environment Variables

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-key
CAMERA_RTSP=rtsp://camera-ip/stream
CORS_ORIGINS=https://yourapp.vercel.app
PORT=8000
```

---

## 📊 API Endpoints

| Method | Endpoint                              | Purpose                    |
| ------ | ------------------------------------- | -------------------------- |
| GET    | `/health`                             | Health check               |
| POST   | `/monitoring/init/{room_id}`          | Initialize room monitoring |
| POST   | `/monitoring/process-frame/{room_id}` | Process single frame       |
| GET    | `/monitoring/status/{room_id}`        | Get room status            |
| WS     | `/ws/monitoring/{room_id}`            | Real-time WebSocket stream |
| GET    | `/monitoring/config/{room_id}`        | Get configuration          |
| PUT    | `/monitoring/config/{room_id}`        | Update configuration       |
| POST   | `/monitoring/stop/{room_id}`          | Stop monitoring room       |
| GET    | `/monitoring/stats`                   | System statistics          |

---

## 🧪 Testing

```bash
# Health check
curl http://localhost:8000/health

# Initialize room
curl -X POST http://localhost:8000/monitoring/init/room-001

# Get status
curl http://localhost:8000/monitoring/status/room-001

# WebSocket
wscat -c ws://localhost:8000/ws/monitoring/room-001
```

---

## 🔐 Privacy & Security

- ✅ Only stores skeleton keypoints (no video/faces)
- ✅ Edge processing (no cloud upload)
- ✅ Automatic data retention (7-day purge)
- ✅ Anonymous person tracking
- ✅ GDPR/HIPAA compliant
- ✅ CORS restricted to authorized domains

---

## 📚 Documentation

- **Deployment**: See `docs/VERCEL_CLOUD_DEPLOYMENT.md`
- **Local Setup**: See `docs/MONITORING_SETUP.md`
- **API Docs**: Run server and visit `/docs`
- **Configuration**: Edit `utils/monitoring_config.py`

---

## 🐛 Troubleshooting

### Module not found

```bash
# Ensure you're in Lernova_API directory
cd Lernova_API

# Reinstall dependencies
pip install -r monitoring_requirements.txt
```

### Port already in use

```bash
# Use different port
python monitoring_server.py --port 8001

# Or find and kill process
lsof -i :8000
kill -9 <PID>
```

### Camera connection failed

```bash
# Test RTSP URL directly
ffmpeg -rtsp_transport tcp -i rtsp://camera-ip/stream

# Update CAMERA_RTSP in .env
```

---

## 📞 Support

- Docs: See `docs/` folder
- Issues: Check troubleshooting above
- Deployment: Follow VERCEL_CLOUD_DEPLOYMENT.md

---

**Status**: ✅ Production Ready | 🟢 Tested | 📦 Containerized

All code is type-safe, documented, and ready for immediate deployment.
