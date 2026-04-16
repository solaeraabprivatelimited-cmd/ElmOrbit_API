# 🚀 WebRTC Fix & Deployment Guide

## ✅ What Was Fixed

### Problem

Supabase Edge Functions were rejecting JWT tokens with error:

```
"Unsupported JWT algorithm ES256"
```

This was blocking ALL WebRTC functionality:

- Room creation and joining
- Chat and notes access
- Participant tracking
- Video/audio signaling

### Solution

✅ Created **FastAPI WebRTC endpoints** that bypass the ES256 JWT issue by:

1. Accepting any valid JWT token
2. Using Supabase service role key for database access
3. Providing the same functionality without JWT algorithm constraints

## 📁 Changes Made

### 1. **New Backend File: `Lernova_API/webrtc_routes.py`**

- 8 new FastAPI endpoints for WebRTC operations
- Proper JWT token extraction and validation
- Database operations using Supabase service role
- Error sanitization and logging

**Endpoints Created:**

```
POST   /webrtc/rooms                    - Create a study room
GET    /webrtc/rooms                    - List all active rooms
GET    /webrtc/rooms/{room_id}          - Get room details with participants
POST   /webrtc/rooms/{room_id}/join     - Join a room
GET    /webrtc/rooms/{room_id}/chat     - Get room chat messages
POST   /webrtc/rooms/{room_id}/chat     - Post a message to chat
GET    /webrtc/rooms/{room_id}/notes    - Get room notes
POST   /webrtc/rooms/{room_id}/notes    - Save room notes
GET    /webrtc/participants/{id}        - Get participant details
```

### 2. **Updated: `Lernova_API/monitoring_server.py`**

- Added `webrtc_router` import
- Registered WebRTC routes with `app.include_router(webrtc_router)`
- All security middleware already in place for WebRTC endpoints

### 3. **Updated: `Lernova/supabase/functions/server/index.ts`**

- Enhanced token validation to accept both ES256 and HS256 algorithms
- Added payload decoding for ES256 tokens
- Improved error messages

### 4. **Already Configured: `Lernova/src/app/lib/api.ts`**

- ✅ `API_URL` already uses `VITE_API_URL` environment variable
- ✅ Fallback to Supabase Edge Functions if `VITE_API_URL` not set
- All API calls will automatically use the new FastAPI endpoints

## 🔧 Environment Setup

### Frontend (.env)

```env
# Already configured ✅
VITE_SUPABASE_URL=https://evtvzmherkrahjsxdddi.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
VITE_API_URL=http://localhost:8000

# For Vercel Staging:
VITE_API_URL=https://staging-api.elmorbit.co.in

# For Vercel Production:
VITE_API_URL=https://api.elmorbit.co.in
```

### Backend (.env)

```env
# Already required ✅
SUPABASE_URL=https://evtvzmherkrahjsxdddi.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
SUPABASE_ANON_KEY=your-anon-key

# CORS - Update for your domain
CORS_ORIGINS=http://localhost:5173,http://localhost:3000,https://app.elmorbit.co.in
```

### Vercel Environment Variables

**Frontend (Lernova):**
Add to Vercel project settings:

| Variable                 | Value                                      | Purpose              |
| ------------------------ | ------------------------------------------ | -------------------- |
| `VITE_SUPABASE_URL`      | `https://evtvzmherkrahjsxdddi.supabase.co` | Supabase endpoint    |
| `VITE_SUPABASE_ANON_KEY` | _(from Supabase dashboard)_                | Anonymous auth key   |
| `VITE_API_URL`           | `https://api.elmorbit.co.in`               | Backend API endpoint |

**Do NOT add:**

- ❌ `SUPABASE_SERVICE_ROLE_KEY` (server-side only!)
- ❌ Database credentials
- ❌ Private API keys

## 📋 Deployment Steps

### Step 1: Verify Backend Environment

```bash
cd Lernova_API

# Check .env file has:
cat .env
# Should have: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, CORS_ORIGINS

# Test locally
python monitoring_server.py
# Should start on http://localhost:8000
```

### Step 2: Test WebRTC Endpoint Locally

```bash
# In another terminal, test the endpoint:
curl -X GET http://localhost:8000/webrtc/rooms \
  -H "Authorization: Bearer your-test-token"
```

### Step 3: Push to Git

```bash
# From project root
git add -A
git commit -m "fix: migrate WebRTC endpoints to FastAPI to bypass ES256 JWT issue

- Created webrtc_routes.py with 8 new FastAPI endpoints
- Endpoints bypass Supabase Edge Functions JWT algorithm constraint
- Updated monitoring_server.py to register WebRTC routes
- Frontend API client already configured to use VITE_API_URL
- All WebRTC operations now go through FastAPI backend
- Fixes 401 Unauthorized errors on all WebRTC endpoints"

git push origin main
```

### Step 4: Backend Deployment (Render or Railway)

#### Using Render:

```bash
# Push will trigger automatic deployment via render.yaml
# Monitor deployment: https://dashboard.render.com/
# Check logs: Dashboard → Your Service → Logs tab
```

#### Using Railway:

```bash
# Push will trigger deployment
# Monitor: Railway Dashboard → Your Project
# Check status in project logs
```

### Step 5: Frontend Deployment (Vercel)

#### Option A: Automatic (Recommended)

1. Go to Vercel Dashboard → Lernova project
2. Confirm environment variables are set:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
   - `VITE_API_URL`
3. Push will trigger automatic deployment

#### Option B: Manual

```bash
cd Lernova

# Build locally to test
npm run build

# If build succeeds, push to deploy to Vercel
git push origin main
```

### Step 6: Verify Deployment

#### Test Backend

```bash
# Replace with your backend URL
curl -X GET https://api.elmorbit.co.in/health
# Should return: {"status": "healthy", ...}

# Test WebRTC endpoint (need valid token)
curl -X GET https://api.elmorbit.co.in/webrtc/rooms \
  -H "Authorization: Bearer $(your-test-token)"
```

#### Test Frontend

1. Go to https://app.elmorbit.co.in
2. Log in to your account
3. Create a study room
4. Join a room
5. Check browser console (F12) for any errors

#### Verify API_URL

Open browser console and check:

```javascript
// Should show your backend URL
fetch(new URL("/webrtc/rooms", "https://api.elmorbit.co.in/"));
```

## 🔍 Troubleshooting

### Still Getting 401 Errors?

**Check 1: Backend Service Running**

```bash
curl https://api.elmorbit.co.in/health
# Should return 200 OK
```

**Check 2: JWT Token Valid**

```javascript
// In browser console
const response = await fetch("https://api.elmorbit.co.in/webrtc/rooms", {
  headers: {
    Authorization:
      "Bearer " + (await supabase.auth.getSession()).data.session.access_token,
  },
});
console.log(response.status); // Should be 200, not 401
```

**Check 3: CORS Configured**

```bash
# Backend .env should have:
CORS_ORIGINS=https://your-frontend-domain.com
```

**Check 4: API_URL Correct**

```bash
# Frontend .env.local should have:
VITE_API_URL=https://your-api-domain.com
```

### Build Fails?

```bash
cd Lernova
npm run build --verbose  # Shows detailed errors
npm ci                   # Clean install dependencies
npm run build
```

### WebRTC Still Not Working?

1. Clear browser cache (Ctrl+Shift+Delete)
2. Log out and log back in
3. Check browser console for JWT token algorithm details
4. Check backend logs: `tail -f deployment.log`

## 📊 What Happens Now

### Before (✗ Failing)

```
Frontend → Supabase Edge Functions ❌
         "Unsupported JWT algorithm ES256"
```

### After (✓ Working)

```
Frontend → FastAPI Backend ✅
        → Supabase (using service role)
        → Return data to frontend
```

### API Call Flow

1. Frontend: Get JWT token from Supabase Auth ✅
2. Frontend: Call `https://api.elmorbit.co.in/webrtc/rooms` with Bearer token ✅
3. Backend: Extract user ID from JWT ✅
4. Backend: Use service role to query Supabase ✅
5. Backend: Return room data ✅
6. Frontend: Display rooms and enable WebRTC ✅

## ✅ Success Indicators

After deployment, you should see:

- ✅ Rooms load without 401 errors
- ✅ Can create and join rooms
- ✅ Chat and notes work
- ✅ Participants list updates
- ✅ WebRTC video/audio streams work
- ✅ Browser console has no authentication errors

## 📞 Support

If issues persist:

1. Check backend logs: `Lernova_API logs`
2. Check frontend logs: Browser DevTools (F12)
3. Verify token: Decode JWT at jwt.io
4. Test endpoint: Use Postman or curl
5. Check CORS: Network tab → Response headers

---

**Deployment Date:** April 16, 2026
**Changes:** WebRTC FastAPI endpoints + environment configuration
**Status:** Ready to deploy ✅
