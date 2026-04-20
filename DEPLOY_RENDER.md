# 🚀 Render Deployment Guide (Free Tier)

**Deploy Lernova API to Render.com for FREE with Automatic Keep-Alive**

---

## 📋 Quick Requirements

- ✅ GitHub account (repo already exists)
- ✅ Render.com account (free tier)
- ✅ Supabase credentials (you have these)
- ✅ UptimeRobot account (free tier - to prevent spin-down)

---

## ✅ STEP-BY-STEP DEPLOYMENT

### 🔧 STEP 1: Update Your GitHub Repository

Push all changes (new file structure) to GitHub:

```bash
cd "c:\Users\AGNIBHA\OneDrive\Desktop\Website\Elm Orbit\Lernova_API"
git add .
git commit -m "Consolidate backend: rename to main.py, security.py"
git push origin main
```

**What's being deployed:**

- `main.py` (2,500+ lines - complete application)
- `security.py` (1,200+ lines - security layer)
- `Dockerfile` (configured for Python 3.11 + OpenCV)
- `monitoring_requirements.txt` (dependencies)

---

### 🌐 STEP 2: Create Render Account & Connect GitHub

1. **Go to** https://render.com
2. **Sign up** with GitHub (easiest)
3. **Click "New"** → **"Web Service"**
4. **Connect GitHub** repository:
   - Select: `Lernova_API` repo
   - Branch: `main`
   - ✅ Auto-deploy on push: YES

---

### ⚙️ STEP 3: Configure Web Service on Render

| Setting         | Value                |
| --------------- | -------------------- |
| **Name**        | `lernova-api`        |
| **Environment** | `Docker`             |
| **Region**      | `Oregon` (free tier) |
| **Plan**        | `Free`               |
| **Auto-Deploy** | ✅ On                |

**Dockerfile path:** Leave empty (uses root Dockerfile)

---

### 🔐 STEP 4: Add Environment Variables

In Render Dashboard → Your Service → **Environment**:

| Key                         | Value                                              | Type   |
| --------------------------- | -------------------------------------------------- | ------ |
| `SUPABASE_URL`              | `https://your-project.supabase.co`                 | Secret |
| `SUPABASE_SERVICE_ROLE_KEY` | `sbp_xxx...` (from Supabase)                       | Secret |
| `SUPABASE_ANON_KEY`         | `eyJhbG...` (from Supabase)                        | Secret |
| `CORS_ORIGINS`              | `https://app.elmorbit.co.in,http://localhost:5173` | Public |
| `PORT`                      | `8000`                                             | Public |

**How to find Supabase credentials:**

1. Go to https://supabase.com → Your Project
2. Settings → API
3. Copy `Project URL` → paste in `SUPABASE_URL`
4. Copy `Service Role Secret` → paste in `SUPABASE_SERVICE_ROLE_KEY`
5. Copy `anon public` → paste in `SUPABASE_ANON_KEY`

---

### 🚀 STEP 5: Deploy

1. Click **"Create Web Service"**
2. Wait for build (5-10 minutes)
3. Once deployed, you get a URL: `https://lernova-api-xxxx.onrender.com`

---

## ⏰ STEP 6: Prevent Spin-Down (Free Tier Issue)

**Problem:** Render free tier spins down after 15 minutes of inactivity

**Solution:** Use UptimeRobot to ping every 10 minutes

### Setup UptimeRobot:

1. Go to https://uptimerobot.com
2. Sign up (free)
3. Click **"Add New Monitor"**
   - **Monitor Type:** HTTP(s)
   - **Friendly Name:** Lernova API
   - **URL:** `https://lernova-api-xxxx.onrender.com/health`
   - **Monitoring Interval:** 10 minutes
   - **Click Save**

✅ Done! Your service will stay active 24/7

---

## 📊 Test Deployment

```bash
# Test health endpoint (from your terminal)
curl https://lernova-api-xxxx.onrender.com/health

# Expected response:
# {"status":"healthy","timestamp":"2026-04-20T...","version":"1.0.0"}

# Test API endpoint
curl -X GET https://lernova-api-xxxx.onrender.com/monitoring/stats
```

---

## 🔄 Auto-Deploy from GitHub

Every time you push to `main` branch, Render automatically:

1. Pulls latest code
2. Rebuilds Docker image
3. Deploys new version
4. Restarts service

No manual action needed!

```bash
# Deploy new changes automatically:
git add .
git commit -m "Your changes"
git push origin main  # Auto-triggers Render deploy
```

---

## 📝 Environment Setup Checklist

- [ ] GitHub repo updated with new file names
- [ ] GitHub push completed
- [ ] Render account created
- [ ] Web Service created and connected to GitHub
- [ ] All 5 environment variables added
- [ ] Service deployed successfully (blue "Live" status)
- [ ] Health check endpoint responds
- [ ] UptimeRobot monitor configured
- [ ] Frontend `.env` updated with new API URL

---

## 🆘 Troubleshooting

### Service stuck building?

- Go to Render Dashboard → Logs
- Look for error messages
- Common issues:
  - Missing environment variables → Add them
  - Docker build failed → Check requirements.txt

### Health check failing?

```bash
# SSH into container (Render Dashboard → Shell)
curl http://localhost:8000/health
```

### Still getting spin-down?

- Verify UptimeRobot monitor is active (green checkmark)
- Increase ping frequency to 5 minutes
- Check UptimeRobot logs

---

## 💰 Free Tier Limits

| Feature       | Limit                       |
| ------------- | --------------------------- |
| Web Services  | 1 free                      |
| Build Minutes | 100/month                   |
| RAM           | 512 MB                      |
| Spin-down     | After 15 min inactivity     |
| Database      | Not included (use Supabase) |

**For better performance:** Upgrade to paid tier ($7/month)

---

## 🎯 Final API URL

Once deployed, your API is live at:

```
https://lernova-api-xxxx.onrender.com
```

**Update your frontend** to use this URL in `.env`:

```
VITE_API_URL=https://lernova-api-xxxx.onrender.com
```

---

## 📚 Useful Links

- Render Docs: https://render.com/docs
- UptimeRobot: https://uptimerobot.com
- Supabase Console: https://supabase.com/dashboard
- GitHub: https://github.com

---

**🎉 Congratulations! Your Lernova API is now deployed to the cloud!**
