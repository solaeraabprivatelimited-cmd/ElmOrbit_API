# Backend Code Migration Guide

**Date:** April 16, 2026  
**Status:** ✅ Complete

## Overview

Backend code has been migrated from the Lernova (frontend) folder to Lernova_API (dedicated backend) to establish proper separation of concerns.

---

## Migrated Components

### 1. ✅ Monitoring Database Routes

**Source:** `Lernova/src/app/lib/monitoringAPI.ts` (Next.js API routes)  
**Target:** `Lernova_API/monitoring_routes.py` (FastAPI endpoints)  
**Status:** ✅ Migrated & Integrated

#### Endpoint Mapping:

```
NextApiRoute                           FastAPI Endpoint
─────────────────────────────────────────────────────────
startMonitoringSession()              POST /monitoring/db/sessions
logMonitoringEvent()                  POST /monitoring/db/events
storeSkeletonData()                   POST /monitoring/db/skeleton
updateOccupancy()                     POST /monitoring/db/occupancy
getRoomStatus()                       GET /monitoring/db/rooms/{room_id}/status
getEventHistory()                     GET /monitoring/db/rooms/{room_id}/events
createBehaviorRule()                  POST /monitoring/db/rules
```

#### Database Tables:

- `monitoring_sessions`
- `monitoring_events`
- `room_skeleton_snapshots`
- `room_occupancy_history`
- `behavior_rules`
- `alerts`

### 2. ⏳ Supabase Edge Functions (Pending)

**Source:** `Lernova/supabase/functions/server/`  
**Target:** `Lernova_API/supabase_functions/` (or FastAPI endpoints)  
**Status:** 🔄 Planned

#### Functions to Migrate:

- `index.ts` - Hono API server with routing
- `webrtc.ts` - WebRTC room management
- `security-headers.ts` - Security middleware
- `error-handler.ts` - Error handling & sanitization
- `audit-logger.ts` - Audit logging
- `rate-limiter.ts` - Rate limiting

**Recommendation:** Convert Hono routes to FastAPI for consistency, or keep in Supabase Edge Functions and proxy through Lernova_API.

---

## Frontend API Configuration

### Environment Variables

Update `.env.local` with:

```env
# Backend API URL - Frontend calls this
VITE_API_URL=http://localhost:8000  # Dev
VITE_API_URL=https://api.elmorbit.co.in  # Prod
```

### Frontend API Client

The frontend API client (`src/app/lib/api.ts`) now uses `VITE_API_URL`:

```typescript
export const API_URL =
  import.meta.env.VITE_API_URL ||
  `https://${projectId}.supabase.co/functions/v1/server`;
export const BASE_URL = API_URL;
```

### Making API Calls

Frontend code should call:

```typescript
// ✅ OLD (Deprecated - using Supabase Edge Functions)
const response = await fetch(
  `https://${projectId}.supabase.co/functions/v1/server/monitoring/db/sessions`,
  {
    method: "POST",
    headers: { Authorization: `Bearer ${token}` },
    body: JSON.stringify(data),
  },
);

// ✅ NEW (Using API_URL)
const response = await fetch(`${API_URL}/monitoring/db/sessions`, {
  method: "POST",
  headers: { Authorization: `Bearer ${token}` },
  body: JSON.stringify(data),
});
```

---

## Backend Deployment

### Lernova_API Setup

```bash
# Install dependencies
pip install -r monitoring_requirements.txt

# Set environment variables
export SUPABASE_URL=https://your-project.supabase.co
export SUPABASE_SERVICE_ROLE_KEY=your-key
export CORS_ORIGINS=http://localhost:5173,https://elmorbit.co.in

# Run API
python monitoring_server.py
# Server runs on http://localhost:8000
```

### CORS Configuration

The backend is configured to accept requests from:

- Development: `http://localhost:5173` (Vite dev server)
- Production: `https://elmorbit.co.in`, `https://www.elmorbit.co.in`, `https://app.elmorbit.co.in`

Set via `CORS_ORIGINS` environment variable.

---

## API Endpoint Examples

### Create Monitoring Session

```bash
curl -X POST http://localhost:8000/monitoring/db/sessions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "room_id": "room-101",
    "session_name": "Study Session 1"
  }'
```

### Log Event

```bash
curl -X POST http://localhost:8000/monitoring/db/events \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "room_id": "room-101",
    "event_type": "fall_detected",
    "severity": "critical",
    "people_count": 1,
    "anomaly_score": 0.95
  }'
```

### Get Room Status

```bash
curl -X GET http://localhost:8000/monitoring/db/rooms/room-101/status \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

---

## Security

✅ All endpoints include:

- **Authentication:** Bearer token (JWT) required
- **CORS:** Strict whitelist configuration
- **Input Validation:** Pydantic models with Field constraints
- **Error Sanitization:** Generic error messages (no internal details exposed)
- **Rate Limiting:** Per-endpoint limits (integrated in monitoring_server.py)
- **Security Headers:** CSP, HSTS, X-Frame-Options, etc.

---

## Files to Archive/Delete

These files should be marked as deprecated in Lernova:

```
Lernova/
├── src/app/lib/monitoringAPI.ts (⚠️ Deprecated - see header comment)
└── supabase/functions/server/ (⏳ Planned for migration)
    ├── index.ts
    ├── webrtc.ts
    ├── security-headers.ts
    ├── error-handler.ts
    ├── audit-logger.ts
    └── rate-limiter.ts
```

---

## Next Steps

### Phase 1: ✅ Complete

- [x] Create FastAPI monitoring routes
- [x] Integrate routes into monitoring_server.py
- [x] Add Supabase client support
- [x] Configure API_URL environment variable
- [x] Create .env.example files
- [x] Mark monitoringAPI.ts as deprecated

### Phase 2: 🔄 In Progress

- [ ] Migrate Supabase Edge Functions to FastAPI (or keep and proxy)
- [ ] Update frontend components to use new API endpoints
- [ ] Test all monitoring endpoints
- [ ] Deploy to staging

### Phase 3: 📅 Planned

- [ ] Performance testing
- [ ] Load testing
- [ ] Security audit
- [ ] Production deployment
- [ ] Archive legacy code

---

## Troubleshooting

### API Connection Issues

**Error:** `CORS error when calling API`

- ✅ Ensure `CORS_ORIGINS` includes your frontend domain
- ✅ Check that `VITE_API_URL` is set correctly in frontend .env

**Error:** `401 Unauthorized`

- ✅ Verify JWT token is valid and not expired
- ✅ Check that `Authorization: Bearer <token>` header is included

**Error:** `502 Bad Gateway`

- ✅ Verify backend API is running (python monitoring_server.py)
- ✅ Check backend logs for errors

---

## Resources

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Supabase Python Client](https://github.com/supabase-community/supabase-py)
- [CORS Documentation](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)
- Security Guide: [SECURITY_MASTER.md](../Lernova/SECURITY_MASTER.md)
