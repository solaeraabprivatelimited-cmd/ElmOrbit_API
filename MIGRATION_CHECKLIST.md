# 🔄 Railway → Render Migration Action Plan

**Complete step-by-step to migrate from Railway to Render + UptimeRobot**

---

## 🎯 Phase 1: Pre-Deployment Setup (15 min)

### Step 1a: Run Pre-Deployment Checklist

```powershell
# Windows PowerShell
cd "c:\Users\AGNIBHA\OneDrive\Desktop\Website\Elm Orbit\Lernova_API"
.\pre-deploy-check.ps1
```

**Expected output:** ✅ All checks green

---

## 🚀 Phase 2: Deploy to Render (20-30 min)

### Step 2a: Go to Render Dashboard

Visit: https://render.com/dashboard

### Step 2b: Create New Web Service

1. Click **"New +"** → **"Web Service"**
2. Click **"Build and deploy from a Git repository"**

### Step 2c: Connect GitHub

1. Click **"Connect GitHub"** (authorize if needed)
2. Search for **"Lernova_API"**
3. Click **"Connect"**

### Step 2d: Configure Service

| Setting | Value         |
| ------- | ------------- |
| Name    | `lernova-api` |
| Runtime | Docker        |
| Region  | Oregon        |
| Branch  | main          |
| Plan    | Free          |

### Step 2e: Add Environment Variables

**Click "Advanced" → "Add Environment Variable"**

| Key                         | Value                                              | Type          |
| --------------------------- | -------------------------------------------------- | ------------- |
| `SUPABASE_URL`              | `https://your-project.supabase.co`                 | Standard      |
| `SUPABASE_SERVICE_ROLE_KEY` | (get from Supabase)                                | **Secret** ✅ |
| `SUPABASE_ANON_KEY`         | (get from Supabase)                                | **Secret** ✅ |
| `CORS_ORIGINS`              | `https://app.elmorbit.co.in,http://localhost:5173` | Standard      |
| `PORT`                      | `8000`                                             | Standard      |

**Finding Supabase Keys:**

1. Go to https://app.supabase.com
2. Project → **Settings** → **API**
3. Copy:
   - `Project URL` → paste in `SUPABASE_URL`
   - `service_role key` → paste in `SUPABASE_SERVICE_ROLE_KEY`
   - `anon public key` → paste in `SUPABASE_ANON_KEY`

### Step 2f: Deploy

Click **"Create Web Service"**

**⏳ Wait for:**

- Docker image build (2-3 min)
- Deployment (1-2 min)
- Health check to pass

**✅ Success indicator:** Service shows "Live" with green status

**Your API URL:** `https://lernova-api.onrender.com`

---

## 🤖 Phase 3: Set Up UptimeRobot (5 min)

### Step 3a: Create UptimeRobot Account

1. Go to https://uptimerobot.com
2. Sign up (free with email)
3. Verify email

### Step 3b: Create Health Check Monitor

1. Dashboard → **"Add New Monitor"**
2. Fill in:
   - **Monitor Type:** HTTP(s)
   - **Friendly Name:** `Lernova API Health`
   - **URL:** `https://lernova-api.onrender.com/health`
   - **Monitoring Interval:** 5 minutes
   - **Alert Contacts:** (add your email)

3. Click **"Create Monitor"**

### Step 3c: Verify Monitor is Active

- UptimeRobot should show: ✅ **Up**
- Should see 5-minute pings in Render logs

---

## 🔗 Phase 4: Update Frontend (10 min)

### Step 4a: Update Frontend API URL

**File:** `Lernova/.env` (or `.env.staging`)

```env
VITE_API_URL=https://lernova-api.onrender.com
```

### Step 4b: Commit and Deploy Frontend

```bash
cd Lernova
git add .env
git commit -m "Update API URL to Render deployment"
npm run build
# Deploy to Vercel (automatic if connected)
```

### Step 4c: Test Frontend

```bash
# In browser DevTools Console:
fetch('https://lernova-api.onrender.com/health')
  .then(r => r.json())
  .then(data => console.log('✅ API Connected!', data))
  .catch(e => console.error('❌ API Failed:', e))
```

---

## ✅ Phase 5: Verification Checklist

- [ ] Render service shows "Live" (green)
- [ ] Health endpoint responds: `https://lernova-api.onrender.com/health`
- [ ] UptimeRobot shows monitor as "Up"
- [ ] Frontend loads and makes API calls successfully
- [ ] Check Render logs for any errors
- [ ] Received UptimeRobot welcome email

---

## 🗑️ Phase 6: Cleanup (Optional)

### Remove Railway Service

1. Go to Railway dashboard
2. Find Lernova API service
3. **Project** → **Settings** → **Delete Project**

⚠️ **Note:** Only delete after confirming Render is fully working

### Update DNS (if using custom domain)

If you have `api.elmorbit.co.in`:

1. Your DNS provider → DNS Settings
2. Update CNAME to point to Render
3. Wait 5-10 minutes for propagation

---

## 📊 Monitoring Dashboard

### Daily Checks

```bash
# Terminal commands to verify deployment
# 1. Check if service is running
curl https://lernova-api.onrender.com/health

# 2. View logs
# → Go to Render Dashboard → Service → Logs
```

### UptimeRobot Dashboard

- Check daily for alerts
- Monitor uptime percentage
- Review response times

---

## ❌ Troubleshooting

| Problem                     | Solution                                                   |
| --------------------------- | ---------------------------------------------------------- |
| Service keeps spinning down | ✅ UptimeRobot pings should keep it alive (5 min interval) |
| CORS errors from frontend   | Update `CORS_ORIGINS` in Render env vars + redeploy        |
| Health check failing        | Verify endpoint in `monitoring_server.py` line 302         |
| Deployment stuck            | Check Render logs; rebuild by pushing to git               |
| API returns 502             | Service may need 30-60 sec after deploy; check logs        |

---

## 📞 Support Resources

| Issue                | Resource                                              |
| -------------------- | ----------------------------------------------------- |
| Render deployment    | https://render.com/docs                               |
| UptimeRobot setup    | https://uptimerobot.com/help/                         |
| FastAPI health check | https://fastapi.tiangolo.com/advanced/behind-a-proxy/ |
| Docker on Render     | https://render.com/docs/docker                        |

---

## 🎉 Success Criteria

✅ **You're done when:**

1. Service shows "Live" on Render
2. UptimeRobot shows "Up" for 24+ hours
3. Frontend loads without API errors
4. Health check responds with `{"status": "healthy", ...}`
5. Received zero alerts from UptimeRobot

---

## 📝 Final Notes

- **Free Tier Limitations:**
  - 0.5 CPU, 512 MB RAM
  - Spins down after 15 min inactivity
  - 100 GB bandwidth/month
  - ✅ UptimeRobot fixes the spin-down issue

- **Cost:** $0/month (free tier) + UptimeRobot free plan

- **Upgrade Path:** If you need more power, Render Starter plan is $7/month

---

**Good luck with your migration! 🚀**

Questions? Check RENDER_DEPLOYMENT.md for detailed information.
