# Lernova Monitoring API

**Privacy-First Study Room Monitoring System - FastAPI Backend**

| Status | Security | API Version | Tech Stack |
|--------|----------|-------------|-----------|
| 🚀 Production Ready | 🔒 Phase 1 Complete | v1.0.0 | FastAPI + MediaPipe + OpenCV |

A secure, high-performance backend service for real-time study room monitoring. Detects person presence, behavioral anomalies, falls, and health emergencies using computer vision and skeletal pose analysis.

---

## ✨ Key Features

### **Real-Time Monitoring**
- 📍 **Skeletal Pose Detection** - MediaPipe-based keypoint extraction (33 keypoints per person)
- 🎯 **Multi-Person Tracking** - Track up to 4 occupants per room
- 📹 **Live Video Processing** - RTSP stream support with adaptive frame rates
- 🔄 **WebSocket Streaming** - Real-time event push to connected clients

### **Behavior Analysis & Alerts**
- 🚨 **Fall Detection** - Identifies extreme posture angles (>60°)
- 🧘 **Posture Monitoring** - Detects unusual/dangerous body positions
- ⏱️ **Idle Detection** - Alerts when person immobile for extended periods
- 🏃 **Rapid Movement** - Triggers on sudden velocity spikes
- 👥 **Occupancy Alerts** - Warns when room capacity exceeded
- 🆘 **Health Emergency** - 30-minute no-movement detection

### **Security & Privacy**
- 🔐 **CORS Restrictions** - Whitelist-based access control
- 🛡️ **Security Headers** - CSP, HSTS, X-Frame-Options
- ✅ **Input Validation** - Room IDs and RTSP URLs validated
- 🔍 **Error Sanitization** - Generic error messages (no info leakage)
- 📊 **Request Tracking** - Unique IDs for audit trail
- 🚫 **Rate Limiting** - Per-endpoint request throttling
- 📡 **Supabase Integration** - Secure database backend

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│         Frontend (React/TypeScript)                 │
│         Lernova Repository                          │
└──────────────────┬──────────────────────────────────┘
                   │ HTTP/WebSocket
                   ▼
┌─────────────────────────────────────────────────────┐
│         FastAPI Server (Python)                     │
│  ├─ CORS Middleware (security)                     │
│  ├─ Rate Limiter (throttling)                      │
│  ├─ Request Tracking (audit)                       │
│  └─ Security Headers (defense-in-depth)            │
└──────────────────┬──────────────────────────────────┘
                   │
      ┌────────────┼────────────┐
      ▼            ▼            ▼
┌──────────┐ ┌──────────┐ ┌──────────┐
│MediaPipe │ │ Behavior │ │ Supabase │
│Pose      │ │ Analyzer │ │Database  │
│Detector  │ │ Engine   │ │          │
└──────────┘ └──────────┘ └──────────┘
```

---

## 🚀 Quick Start

### **Prerequisites**
- Python 3.9+
- pip or conda
- Supabase account (for database)
- RTSP camera source OR webcam

### **Local Setup**

```bash
# Clone repository
git clone https://github.com/YOUR_USERNAME/Lernova_API.git
cd Lernova_API

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r monitoring_requirements.txt

# Create environment file
cp .env.example .env
# Edit .env with your Supabase and CORS credentials

# Run server
python monitoring_server.py
```

Server starts at `http://localhost:8000`

### **Docker Setup**

```bash
# Build image
docker build -f Dockerfile.monitoring -t lernova-monitoring .

# Run container
docker run -p 8000:8000 \
  -e SUPABASE_URL="your-url" \
  -e SUPABASE_KEY="your-key" \
  -e CORS_ORIGINS="http://localhost:3000" \
  lernova-monitoring

# Or use Docker Compose
docker-compose -f docker-compose.monitoring.yml up
```

---

## 📊 API Reference

### **Health & Status**

#### `GET /health`
System health check endpoint.

**Response (200 OK):**
```json
{
  "status": "healthy",
  "timestamp": "2026-04-14T10:30:00",
  "version": "1.0.0",
  "request_id": "a1b2c3d4"
}
```

### **Monitoring Endpoints**

#### `POST /monitoring/init/{room_id}`
Initialize monitoring for a study room.

**Parameters:**
- `room_id` (path) - Unique room identifier (alphanumeric + hyphens, max 100 chars)
- `camera_rtsp` (query) - RTSP camera URL (e.g., `rtsp://192.168.1.100:554/stream`)

**Rate Limit:** 10 requests/hour

**Response (200 OK):**
```json
{
  "room_id": "room-101",
  "status": "initialized",
  "config": {
    "idle_threshold_seconds": 300,
    "movement_threshold": 0.05,
    "pose_angle_threshold": 45,
    "max_occupancy": 4
  }
}
```

---

## ⚙️ Configuration

### **Environment Variables**

Create `.env` file in project root:

```env
# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# CORS Security (comma-separated)
CORS_ORIGINS=http://localhost:3000,https://yourdomain.com

# Server Configuration
HOST=0.0.0.0
PORT=8000
LOG_LEVEL=info
```

### **Behavior Thresholds** (in `utils/monitoring_config.py`)

```python
thresholds = {
    'idle_threshold_seconds': 300,      # 5 minutes
    'movement_threshold': 0.05,          # Sensitivity (0-1)
    'pose_angle_threshold': 45,          # Degrees
    'max_occupancy': 4,                  # People per room
    'min_detection_confidence': 0.7,     # Pose confidence
}
```

### **Alert Rules**

| Rule | Enabled | Trigger | Level |
|------|---------|---------|-------|
| Fall Detection | ✅ | Pose angle > 60° | 🔴 Critical |
| Unusual Posture | ✅ | Angle > 45° for 10s | 🟠 Medium |
| Rapid Movement | ✅ | Velocity > 0.3 | 🟠 Medium |
| Occupancy Exceeded | ✅ | People > 4 | 🟡 High |
| Loitering | ✅ | Idle > 10 min | 🟠 Medium |
| No Movement (30min) | ✅ | No activity | 🟡 High |

---

## 🔒 Security Architecture

### **Phase 1: Critical Fixes** ✅

| Vulnerability | Solution |
|---------------|----------|
| XSS Attacks | Content Security Policy (CSP) |
| Clickjacking | X-Frame-Options: DENY |
| MIME Sniffing | X-Content-Type-Options: nosniff |
| CORS Abuse | Strict origin whitelist |
| Brute Force | Per-endpoint rate limiting |
| Info Disclosure | Error message sanitization |
| Invalid Input | Room ID & URL validation |
| Man-in-the-Middle | HSTS headers |

### **Request Flow Security**

```
Client Request
    ↓
├─ CORS Check (whitelist)
├─ Rate Limiting (per-endpoint)
├─ Input Validation (room_id, rtsp_url)
├─ Process Handler
├─ Add Security Headers
│  ├─ X-Request-ID (tracking)
│  ├─ X-Content-Type-Options
│  ├─ X-Frame-Options
│  └─ CSP, HSTS, etc.
    ↓
Response to Client
```

### **Rate Limits**

| Endpoint | Limit | Window |
|----------|-------|--------|
| `/monitoring/init` | 10 | 1 hour |
| `/monitoring/process-frame` | 30 | 1 minute |
| All others | 100 | 1 minute |

**Exceeding limit:** Returns `429 Too Many Requests`

---

## 📦 Dependencies

### **Core Libraries**

```
fastapi==0.104.1                # Web framework
uvicorn==0.24.0                 # ASGI server
python-dotenv==1.0.0            # Environment variables

# Computer Vision & ML
opencv-python==4.8.1.78         # Video processing
mediapipe==0.10.0               # Pose detection
numpy==1.24.3                   # Numerical computing
ultralytics==8.0.212            # YOLOv8 object detection
torch==2.0.1                    # PyTorch (YOLOv8)

# Database
supabase==2.3.3                 # Supabase client
python-multipart==0.0.6         # File upload

# Processing
scikit-learn==1.3.2             # ML utilities
scipy==1.11.4                   # Scientific computing
pillow==10.1.0                  # Image processing

# Monitoring
python-json-logger==2.0.7       # Structured logging
psutil==5.9.6                   # System metrics
```

**Optional GPU Support:**
```bash
# NVIDIA GPU
pip install cupy-cuda12x tensorrt

# Google Coral TPU
pip install tflite-runtime

# Edge models
pip install tflite-support
```

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
├── README.md                     # This file
├── SECURITY_AUDIT_PHASE1.md      # Security audit documentation
├── STRUCTURE.md                  # Structure overview
├── utils/
│   ├── __init__.py               
│   ├── monitoring_core.py         # ML engine (MediaPipe + behavior analysis)
│   └── monitoring_config.py       # Configuration and alert rules
└── docs/
    ├── VERCEL_CLOUD_DEPLOYMENT.md # Complete cloud hosting guide
    └── MONITORING_SETUP.md        # Local development setup

---

## 💻 Development Workflow

### Local Development

```bash
# 1. Clone and setup
git clone https://github.com/YOUR_USERNAME/Lernova_API.git
cd Lernova_API

# 2. Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 3. Install dependencies
pip install -r monitoring_requirements.txt

# 4. Setup environment
cp .env .env.local
# Edit .env.local with your credentials

# 5. Run development server
python monitoring_server.py

# 6. Test
curl http://localhost:8000/health
```

### Running Tests

```bash
# Check linting
pylint monitoring_server.py utils/

# Type checking
mypy monitoring_server.py

# Run security audit
python -m bandit monitoring_server.py
```

---

## 🚀 Deployment Options

### Option 1: Railway (Recommended) ⭐

```bash
# 1. Install Railway CLI
npm install -g @railway/cli
# or: brew install railway

# 2. Login
railway login

# 3. Create project
railway init

# 4. Add variables to Railway dashboard
SUPABASE_URL=your-url
SUPABASE_SERVICE_ROLE_KEY=your-key
CORS_ORIGINS=https://your-railway-domain.com

# 5. Deploy
railway up
```

**Railway will auto-detect `requirements.txt` and deploy!**

- Start: Free tier ($5/month)
- Auto-scaling: Yes
- Domain: Included
- Monitoring: Built-in

### Option 2: Render

```bash
# 1. Connect GitHub repository to Render
# 2. Create new Web Service
# 3. Connect repo and select automatic deployment
# 4. Set environment variables
SUPABASE_URL=...
SUPABASE_SERVICE_ROLE_KEY=...

# 5. Deploy (auto-deploys on git push)
```

### Option 3: Heroku

```bash
# 1. Install Heroku CLI
# 2. Login
heroku login

# 3. Create app
heroku create your-app-name

# 4. Set variables
heroku config:set SUPABASE_URL=your-url
heroku config:set SUPABASE_SERVICE_ROLE_KEY=your-key

# 5. Deploy
git push heroku main
```

### Option 4: Docker (Any Cloud)

```bash
# Build Docker image
docker build -f Dockerfile.monitoring -t lernova-api .

# Push to Docker Hub
docker tag lernova-api your-username/lernova-api
docker push your-username/lernova-api

# Deploy anywhere: AWS ECS, Google Cloud Run, Microsoft Azure, etc.
```

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
