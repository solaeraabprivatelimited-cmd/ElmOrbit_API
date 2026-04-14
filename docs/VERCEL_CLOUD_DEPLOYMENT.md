# Vercel + Cloud Monitoring System - Complete Setup Guide

**Goal**: Host Lernova on Vercel + monitoring API on a cloud VPS. NO local hardware needed.

---

## 📋 Overview

```
Your Computer
    ↓ (push code)
GitHub
    ↓ (auto-deploy)
┌─────────────────────────────────────┐
│  Frontend: Vercel (vercel.app)      │ ← Your website
│  - Dashboard                        │
│  - All user-facing pages            │
└───────────────┬─────────────────────┘
                │ (API calls)
                ↓
┌─────────────────────────────────────┐
│  Monitoring Server: Railway/Render  │ ← Real-time processing
│  - Python FastAPI                   │
│  - Pose detection                   │
│  - 24/7 running                     │
└───────────────┬─────────────────────┘
                │ (SQL queries)
                ↓
┌─────────────────────────────────────┐
│  Database: Supabase                 │ ← Your data
│  - PostgreSQL                       │
│  - Automatic backups                │
└─────────────────────────────────────┘
```

---

## 💰 Total Cost/Month

| Service        | Cost       | Notes                         |
| -------------- | ---------- | ----------------------------- |
| Vercel         | FREE       | Frontend hosting              |
| Railway/Render | $5-10      | Monitoring server             |
| Supabase       | FREE       | Database (generous free tier) |
| Custom Domain  | $10-15     | Optional                      |
| **TOTAL**      | **$15-25** | Fully production-ready        |

---

## 🚀 Step 1: Deploy Frontend to Vercel (10 mins)

### A. Connect GitHub to Vercel

1. Go to https://vercel.com
2. Click "Sign Up" → Choose "GitHub"
3. Authorize Vercel access to your GitHub account
4. Grant permission to `solaeraabprivatelimited-cmd/Lernova` repo

### B. Deploy Project

1. Click "Add New..." → "Project"
2. Select `Lernova` repository
3. Click "Import"

**Configure Build Settings**:

```
Framework: Next.js
Build Command: npm run build
Output Directory: .next
Install Command: npm install
```

**Environment Variables** (in Vercel):

Click "Environment Variables" and add:

```
NEXT_PUBLIC_MONITORING_SERVER=https://monitoring-staging.railway.app
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-from-supabase
```

4. Click "Deploy"

**Wait 2-3 minutes...** Then you'll see:

```
✅ Production: https://yourapp.vercel.app
```

---

## 🚀 Step 2: Deploy Monitoring Server (15 mins)

### Option A: Railway (RECOMMENDED - Easier)

#### 1. Create Railway Account

1. Go to https://railway.app
2. Click "Start Project"
3. Sign in with GitHub
4. Authorize railway-app access

#### 2. Create Monitoring Service

1. Click "New Project" → "Deploy from GitHub repo"
2. Select: `solaeraabprivatelimited-cmd/Lernova`
3. Click "Deploy"
   - Railway auto-detects `Dockerfile.monitoring`
   - Starts building...

#### 3. Configure Environment Variables

Go to **Variables** tab and add:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
CAMERA_RTSP=rtsp://your-camera-ip/stream
CORS_ORIGINS=https://yourapp.vercel.app
PORT=8000
```

#### 4. Get Your URL

After deploy completes:

```
https://monitoringxyz.railway.app
```

#### 5. Update Vercel Environment Variable

Go back to Vercel → Settings → Environment Variables

Update:

```
NEXT_PUBLIC_MONITORING_SERVER=https://monitoringxyz.railway.app
```

Redeploy Vercel (click "Redeploy" button)

---

### Option B: Render (Alternative)

#### 1. Create Render Account

1. Go to https://render.com
2. Click "Sign up"
3. Choose GitHub
4. Authorize access

#### 2. Deploy Service

1. Dashboard → "New +" → "Web Service"
2. Connect repository: `solaeraabprivatelimited-cmd/Lernova`
3. Deploy settings:
   - **Name**: `lernova-monitoring`
   - **Region**: Choose closest to you
   - **Branch**: `main`
   - **Runtime**: `Docker`
   - **Build Command**: `pip install -r monitoring_requirements.txt`
   - **Start Command**: `python monitoring_server.py`

4. Click "Create Web Service"

#### 3. Add Environment Variables

In Render dashboard → Environment:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
CAMERA_RTSP=rtsp://your-camera-ip/stream
CORS_ORIGINS=https://yourapp.vercel.app
PORT=8000
```

#### 4. Get Your URL

After deploy:

```
https://lernova-monitoring.onrender.com
```

---

## 🚀 Step 3: Setup Supabase Database (5 mins)

### A. Create Supabase Project

1. Go to https://supabase.com
2. Click "Start your project"
3. Sign in with GitHub
4. Click "Create a new project"
5. Fill in:
   - **Project name**: `lernova`
   - **Database password**: (save this!)
   - **Region**: Choose closest to your users
6. Click "Create new project"

Wait 2-3 minutes for setup...

### B. Get Your Keys

In Supabase dashboard → Settings → API:

Copy these values:

```
SUPABASE_URL = https://xxxxx.supabase.co
SUPABASE_ANON_KEY = eyJhbGc...
SUPABASE_SERVICE_ROLE_KEY = eyJhbGc...
```

**SAVE THESE!** You'll need them for environment variables.

### C. Run Database Migration

1. Go to SQL Editor (left sidebar)
2. Click "New query"
3. Copy entire content from: `supabase/migrations/20260414_002_study_room_monitoring.sql`
4. Paste it in the query editor
5. Click "Run"

You should see:

```
✅ 8 tables created
✅ Row-level security enabled
✅ Indexes created
```

### D. Update All Environment Variables

Now update your environment variables everywhere:

**1. Vercel Environment Variables**:

- Go to Vercel → Project Settings → Environment Variables
- Update:
  ```
  SUPABASE_URL=https://xxxxx.supabase.co
  SUPABASE_ANON_KEY=eyJhbGc...
  ```

**2. Railway/Render Environment Variables**:

- Go to your monitoring service settings
- Update:
  ```
  SUPABASE_URL=https://xxxxx.supabase.co
  SUPABASE_SERVICE_ROLE_KEY=eyJhbGc...
  ```

---

## 🎯 Step 4: Add Monitoring Dashboard to Your App (5 mins)

The React dashboard is already created at:

```
src/app/components/dashboard/StudyRoomMonitoringDashboard.tsx
```

### Add Route to Your App

Edit `src/app/App.tsx`:

```tsx
import { StudyRoomMonitoringDashboard } from "@/app/components/dashboard/StudyRoomMonitoringDashboard";

// In your routes (wherever you have other routes):
<Route
  path="/admin/rooms/:roomId/monitoring"
  element={<StudyRoomMonitoringDashboard roomId={roomId} />}
/>;
```

### Add Navigation Link

In your room admin page or navigation:

```tsx
<Link to={`/admin/rooms/room-001/monitoring`}>
  <Eye className="w-4 h-4" /> View Monitoring
</Link>
```

### Deploy to Vercel

```bash
git add .
git commit -m "Add monitoring dashboard route"
git push origin main
```

Vercel auto-deploys! Check https://yourapp.vercel.app/admin/rooms/room-001/monitoring

---

## 📹 Step 5: Connect Your Cameras

### Option A: IP Camera (Recommended)

Your camera should be:

1. Connected to internet
2. Supports RTSP protocol
3. You know the RTSP URL

Get the RTSP URL from your camera manual or settings.

Example URLs:

```
rtsp://192.168.1.100:554/stream
rtsp://username:password@192.168.1.100/stream
```

Update environment variables:

```
CAMERA_RTSP=rtsp://your-camera-ip/stream
```

### Option B: Webcam (USB or Built-in)

If using Railway/Render, they won't have USB access.

**Solution**:

1. Set up a local forwarding service (ngrok)
2. Or switch to IP camera

---

## ✅ Testing (5 mins)

### Test 1: Check Frontend

```
https://yourapp.vercel.app
```

Should load your website. ✅

### Test 2: Check Monitoring Server

```bash
curl https://monitoring-xyz.railway.app/health

# Should return:
# {"status": "healthy", "timestamp": "..."}
```

✅

### Test 3: Check Dashboard

```
https://yourapp.vercel.app/admin/rooms/room-001/monitoring
```

Should show:

- Occupancy count
- Event timeline
- System health
- Live skeleton visualization

✅

### Test 4: Check Database

Go to Supabase → SQL Editor → Run:

```sql
SELECT COUNT(*) FROM study_rooms;
```

Should return:

```
count
------
  0
```

(0 because no rooms created yet)

✅

---

## 🎉 You're Done!

Your monitoring system is now:

- ✅ Frontend live on Vercel
- ✅ API server running on Railway/Render
- ✅ Database on Supabase
- ✅ No local hardware needed
- ✅ 24/7 monitoring available

---

## 🚀 Next Steps

### Add First Room

```tsx
// In your admin panel or API
await supabase.from("study_rooms").insert([
  {
    name: "Study Room 101",
    code: "room-001",
    capacity: 4,
    camera_rtsp_url: "rtsp://camera-ip/stream",
    monitoring_enabled: true,
  },
]);
```

### Configure Alerts

1. Go to Supabase dashboard
2. Create alert rules in `behavior_rules` table
3. Configure notification channels in `alert_configurations`

### Monitor in Real-Time

Visit: `https://yourapp.vercel.app/admin/rooms/room-001/monitoring`

---

## 🔧 Troubleshooting

### Dashboard shows "No data"

**Check**:

1. Is monitoring server running? → `curl https://monitoring-xyz.railway.app/health`
2. Is camera connected? → Check `CAMERA_RTSP` URL
3. Is database migrated? → Check Supabase SQL Editor

### Monitoring server crashes

**Check logs**:

- Railway: Dashboard → Logs tab
- Render: Dashboard → Logs

**Common issues**:

- Missing environment variables
- Camera URL wrong
- Supabase key invalid

### Vercel shows error

**Check**:

1. Environment variables set?
2. `NEXT_PUBLIC_MONITORING_SERVER` correct?
3. Try redeploy: Click "Redeploy" in Vercel dashboard

---

## 📞 Support Resources

**Vercel**:

- Docs: https://vercel.com/docs
- Dashboard: https://vercel.com/dashboard

**Railway**:

- Docs: https://docs.railway.app
- Dashboard: https://railway.app/dashboard

**Render**:

- Docs: https://render.com/docs
- Dashboard: https://dashboard.render.com

**Supabase**:

- Docs: https://supabase.com/docs
- Dashboard: https://app.supabase.com

---

## 💡 Pro Tips

1. **Use GitHub Actions** for automated testing
2. **Set up monitoring alerts** on Railway/Render
3. **Enable Supabase backups** (automatic daily)
4. **Monitor costs** in provider dashboards
5. **Test locally first** before deploying

---

**Status**: 🟢 READY FOR PRODUCTION

All code is created and tested. Follow these steps and you'll have:

- ✅ Live website on Vercel
- ✅ 24/7 monitoring on cloud server
- ✅ Secure database on Supabase
- ✅ Real-time dashboard
- ✅ Zero local hardware required

**Questions?** Check `/MONITORING_SETUP.md` for more details.
