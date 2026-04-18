# 🚀 Render Deployment Guide (Railway → Render Migration)

**Migrate from Railway to Render.com Free Tier with UptimeRobot Monitoring**

---

## 📋 Prerequisites

- GitHub account with Lernova_API repository
- Render.com account (free tier available)
- UptimeRobot account (free with up to 50 monitors)
- Supabase credentials (already have)

---

## ✅ Step 1: Prepare Your Repository

### 1.1 Ensure `.env` is NOT committed (critical)

```bash
# Check .gitignore contains:
cat .gitignore | grep "^\.env"

# Should output: .env
```

### 1.2 Create `.env.example` (for reference)

```bash
# Already exists - verify it contains:
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
SUPABASE_ANON_KEY=your-anon-key
CORS_ORIGINS=https://app.elmorbit.co.in,https://staging.elmorbit.co.in
PORT=8000
```

### 1.3 Update `render.yaml` (complete configuration)

Replace your current `render.yaml` with:

```yaml
services:
  - type: web
    name: lernova-api
    runtime: docker
    region: oregon # Free tier supports: oregon, frankfurt
    plan: free

    # GitHub Integration
    repo: https://github.com/your-username/Lernova_API.git
    branch: main # Deploy from main branch

    # Docker Settings
    dockerfilePath: ./Dockerfile
    dockerContext: .

    # Environment Variables (set in Render dashboard)
    envVars:
      - key: SUPABASE_URL
        fromDatabase:
          name: your-db
          property: url
      - key: SUPABASE_SERVICE_ROLE_KEY
        sync: false # Manually set in dashboard
      - key: SUPABASE_ANON_KEY
        sync: false
      - key: CORS_ORIGINS
        value: https://app.elmorbit.co.in,https://staging.elmorbit.co.in,http://localhost:5173
      - key: PORT
        value: "8000"

    # Health Check (UptimeRobot will call this)
    healthCheckPath: /health
    healthCheckInterval: 30

    # Auto-Deploy from GitHub
    autoDeploy: true

    # Restart Policy (important for free tier)
    restartPolicy: always
```

### 1.4 Update `Dockerfile` (Render optimization)

No changes needed - your Dockerfile is already Render-compatible.

**Verify it has:**

```dockerfile
# Health check endpoint for monitoring
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health').read()"

# Expose port
EXPOSE 8000

# Run command
CMD ["uvicorn", "monitoring_server:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

## 🔧 Step 2: Deploy to Render

### 2.1 Create New Service

1. Go to **[render.com](https://render.com)** and sign in
2. Click **"New +"** → **"Web Service"**
3. Select **"Build and deploy from a Git repository"**

### 2.2 Connect GitHub Repository

1. Click **"Connect GitHub"** (if not already connected)
2. Authorize Render to access your GitHub account
3. Search for **"Lernova_API"** repository
4. Click **"Connect"**

### 2.3 Configure Service

Fill in these fields:

| Field             | Value                             |
| ----------------- | --------------------------------- |
| **Name**          | `lernova-api`                     |
| **Region**        | Oregon (free) or Frankfurt (free) |
| **Branch**        | `main`                            |
| **Build Command** | (leave empty - using Docker)      |
| **Start Command** | (leave empty - using Docker)      |
| **Instance Type** | Free                              |
| **Auto-Deploy**   | ✅ Yes (deploy on git push)       |

### 2.4 Set Environment Variables

Click **"Advanced"** → **"Add Environment Variable"**

| Key                         | Value                                              | Secret? |
| --------------------------- | -------------------------------------------------- | ------- |
| `SUPABASE_URL`              | `https://your-project.supabase.co`                 | No      |
| `SUPABASE_SERVICE_ROLE_KEY` | (Paste from Supabase)                              | ✅ Yes  |
| `SUPABASE_ANON_KEY`         | (Paste from Supabase)                              | ✅ Yes  |
| `CORS_ORIGINS`              | `https://app.elmorbit.co.in,http://localhost:5173` | No      |
| `PORT`                      | `8000`                                             | No      |

### 2.5 Deploy

Click **"Create Web Service"**

**Wait for:**

- ✅ Image build (2-3 min)
- ✅ Deployment (1-2 min)
- ✅ Health check pass

Your service will be available at: **`https://lernova-api.onrender.com`**

---

## 📊 Step 3: Update Frontend API Endpoint

### 3.1 Update `.env` in Lernova/ folder

**Development:**

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
VITE_API_URL=http://localhost:8000
```

**Staging:**

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
VITE_API_URL=https://lernova-api.onrender.com
```

**Production:**

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key
VITE_API_URL=https://api.elmorbit.co.in
# (use custom domain after setting up)
```

### 3.2 Deploy Frontend

```bash
cd Lernova
npm run build
# Deploy to Vercel as usual
```

---

## 🤖 Step 4: Set Up UptimeRobot Monitoring

**Why UptimeRobot?**

- Render free tier spins down after 15 min of inactivity
- UptimeRobot pings your service every 5 min (keeps it alive)
- Get alerts if service goes down

### 4.1 Create UptimeRobot Account

1. Go to **[uptimerobot.com](https://uptimerobot.com)**
2. Sign up (free plan includes 50 monitors)
3. Verify email

### 4.2 Create Monitor

1. Dashboard → **"Add New Monitor"**
2. Fill in:

| Field                   | Value                                     |
| ----------------------- | ----------------------------------------- |
| **Monitor Type**        | HTTP(s)                                   |
| **Friendly Name**       | `Lernova API Health`                      |
| **URL**                 | `https://lernova-api.onrender.com/health` |
| **Monitoring Interval** | 5 minutes                                 |
| **Alert Contacts**      | (set up email)                            |

3. Click **"Create Monitor"**

### 4.3 Verify Health Check

The health check endpoint should return:

```json
{
  "status": "healthy",
  "timestamp": "2026-04-18T12:34:56Z"
}
```

---

## ⚙️ Step 5: Configure CORS for Production

Your backend (`Lernova_API/monitoring_server.py`) already has CORS middleware. Update environment variable:

```env
CORS_ORIGINS=https://app.elmorbit.co.in,https://staging.elmorbit.co.in,http://localhost:5173
```

Render will pass this to your FastAPI:

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins.split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

---

## 🔒 Step 6: Set Up Custom Domain (Optional)

If you have `api.elmorbit.co.in`:

1. **Render Dashboard:**
   - Service → **Settings** → **Custom Domains**
   - Add domain: `api.elmorbit.co.in`
   - Copy CNAME value: `cname.onrender.com`

2. **Your Domain Registrar (Namecheap/GoDaddy):**
   - DNS Settings
   - Add CNAME record:
     ```
     Name: api
     Type: CNAME
     Value: cname.onrender.com
     TTL: 3600
     ```

3. **Verify (wait 5-10 min):**
   ```bash
   nslookup api.elmorbit.co.in
   # Should resolve to onrender.com
   ```

---

## 📝 Deployment Checklist

- [ ] Repository has `Dockerfile` (configured correctly)
- [ ] `render.yaml` is in root of `Lernova_API`
- [ ] `.env` is in `.gitignore` (not committed)
- [ ] `.env.example` exists with template
- [ ] GitHub repo is public or Render has access
- [ ] Created Render account and connected GitHub
- [ ] Set all environment variables in Render dashboard
- [ ] Deployment completed successfully
- [ ] Health check endpoint responds
- [ ] UptimeRobot monitor created and active
- [ ] Frontend `.env` updated with new API URL
- [ ] CORS_ORIGINS includes your frontend domain
- [ ] Tested API call from frontend

---

## 🧪 Testing Your Deployment

### Test Health Endpoint

```bash
curl https://lernova-api.onrender.com/health
# Should return: {"status": "healthy", "timestamp": "..."}
```

### Test API Endpoint

```bash
# From your frontend, test a simple API call:
fetch('https://lernova-api.onrender.com/health')
  .then(r => r.json())
  .then(data => console.log('API works!', data))
  .catch(e => console.error('API failed:', e))
```

### Check Logs

In Render dashboard:

- Service → **Logs**
- Should show successful deployments and health checks

### Monitor UptimeRobot

In UptimeRobot:

- Dashboard → Your monitor
- Should show "Up" status
- Pings every 5 minutes

---

## ❌ Troubleshooting

### Service Spins Down / "Application Error"

**Cause:** Render free tier stops inactive services  
**Solution:** UptimeRobot should keep it alive with 5-min pings

### CORS Error from Frontend

**Cause:** Frontend domain not in `CORS_ORIGINS`  
**Solution:**

```bash
# In Render dashboard:
1. Service → Settings → Environment
2. Edit CORS_ORIGINS
3. Add your frontend domain
4. Redeploy (automatic)
```

### Health Check Failing

**Cause:** `/health` endpoint not implemented  
**Solution:** Verify `monitoring_server.py` has:

```python
@app.get("/health")
def health_check():
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}
```

### Build Fails: "No such file or directory"

**Cause:** File paths in Dockerfile wrong for Windows  
**Solution:** Use forward slashes (`/`), not backslashes (`\`)

### Deployment Takes >10 Min

**Cause:** Large Docker image being built  
**Solution:** Normal for first deploy; subsequent deploys are faster (cached layers)

---

## 📊 Monitoring Dashboard

### Render Dashboard Metrics

- Service page shows: CPU, Memory, Requests, Status
- Logs available in real-time
- Auto-redeploy on git push (if enabled)

### UptimeRobot Dashboard

- Uptime percentage (SLA)
- Response time trends
- Alert history
- Email notifications

---

## 🔄 Backup Migration Steps

If migrating FROM Railway:

### 1. Export Railway Logs

```bash
# From Railway dashboard:
# Deployments → Export logs
```

### 2. Update DNS

**Old:** `api.railway.app` → **New:** `api.onrender.com`

### 3. Redeploy Frontend

```bash
cd Lernova
npm run build
# Deploy to Vercel with new API_URL
```

### 4. Verify All Services

- [ ] Frontend loads
- [ ] API calls succeed
- [ ] WebRTC works
- [ ] UptimeRobot shows "Up"

---

## 💡 Pro Tips

1. **Free Tier Limits:**
   - 0.5 CPU cores
   - 512 MB RAM
   - 100 GB bandwidth/month
   - Service spins down after 15 min inactivity

2. **Keep Service Alive:**
   - UptimeRobot pings every 5 min
   - Prevents spin-down

3. **Upgrade if Needed:**
   - Starter plan: $7/month
   - Pro plan: $12/month
   - Includes always-on, 2 CPU cores, 2GB RAM

4. **Monitor Regularly:**
   - Check UptimeRobot alerts daily
   - Review Render logs weekly
   - Track API performance

---

## 📞 Support

- **Render Docs:** https://render.com/docs
- **Render Status:** https://status.render.com
- **UptimeRobot Docs:** https://uptimerobot.com/help/
- **FastAPI Docs:** https://fastapi.tiangolo.com/

---

**Last Updated:** April 18, 2026  
**Status:** ✅ Ready for Production
