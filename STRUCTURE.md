# Lernova API Directory Structure

This is the separate API directory for the monitoring system.

## Contents

```
.
├── README.md                       # API documentation
├── monitoring_server.py            # Main FastAPI app
├── monitoring_requirements.txt     # Python dependencies
├── Dockerfile.monitoring           # Docker build
├── docker-compose.monitoring.yml   # Docker Compose
├── utils/
│   ├── __init__.py                # Package initialization
│   ├── monitoring_core.py          # ML engine
│   └── monitoring_config.py        # Configuration
└── docs/
    ├── VERCEL_CLOUD_DEPLOYMENT.md  # Cloud setup
    └── MONITORING_SETUP.md         # Local setup
```

## Quick Commands

### Local Development

```bash
pip install -r monitoring_requirements.txt
python monitoring_server.py
```

### Docker

```bash
docker build -f Dockerfile.monitoring -t lernova-monitoring .
docker run -p 8000:8000 lernova-monitoring
```

### Cloud Deployment

See `docs/VERCEL_CLOUD_DEPLOYMENT.md`

---

**Frontend code** remains in: `C:\Users\AGNIBHA\OneDrive\Desktop\Website\Lernova`
**Backend code** is now in: `C:\Users\AGNIBHA\OneDrive\Desktop\Website\Lernova_API`
