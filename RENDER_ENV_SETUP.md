# ✅ RENDER ENVIRONMENT VARIABLES - SETUP GUIDE

# These variables MUST be manually added to Render Dashboard

## Location: https://dashboard.render.com → lernova-api → Settings → Environment Variables

## CRITICAL VARIABLES (Must be set for production):

| Variable Name               | Value                                                                               | Notes                                                                                |
| --------------------------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `GROQ_API_KEY`              | `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`                          | **REQUIRED** - Get from https://console.groq.com - AI Mentor won't work without this |
| `SUPABASE_SERVICE_ROLE_KEY` | From `.env` (git-ignored)                                                           | **REQUIRED** - Keep secret, backend-only                                             |
| `CORS_ORIGINS`              | `https://lernova-alpha.vercel.app,https://app.elmorbit.co.in,http://localhost:5173` | Already configured ✅                                                                |
| `PORT`                      | `8000`                                                                              | Already configured ✅                                                                |

## Quick Setup:

1. Go to: https://dashboard.render.com
2. Click on `lernova-api` service
3. Click **Settings** tab
4. Scroll to **Environment Variables**
5. Click **Add Environment Variable**
6. For each variable above:
   - Enter Name
   - Enter Value
   - Click Save
7. Service auto-redeploys after each save

## Verification:

After setting GROQ_API_KEY:

- Check dashboard - service should show green "Ready" checkmark
- Wait 1-2 minutes for deployment
- Test by making request to: `https://elmorbit-api.onrender.com/api/ai-mentor/chat`

## Why These Are Needed:

- **GROQ_API_KEY**: Backend needs this to call Groq LLM API for AI responses
- **SUPABASE_SERVICE_ROLE_KEY**: Backend needs this for authenticated database operations
- **CORS_ORIGINS**: Already set to allow requests from frontend
- **PORT**: Already set to run on 8000

---

**Priority: ⚠️ GROQ_API_KEY is BLOCKING AI Mentor functionality**
