# Render Backend - GROQ_API_KEY Setup (REQUIRED)

## Critical Issue

Your backend on Render is **missing the GROQ_API_KEY** environment variable. This prevents the AI Mentor endpoint from working.

**Evidence:**

- Frontend CORS: ✅ Working (verified with preflight tests)
- Backend response: ❌ Failing (no Groq API key to call LLM)
- Error in browser: `"Cannot read properties of undefined (reading 'payload')"`

## Immediate Fix (2 minutes)

### Step 1: Get Your Groq API Key

Your local `.env` file contains:

```
GROQ_API_KEY=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
```

Copy this key (or get a new one from https://console.groq.com).

### Step 2: Set on Render Dashboard

1. **Go to:** https://dashboard.render.com
2. **Click:** Your project `lernova-api`
3. **Click:** Settings tab
4. **Scroll to:** Environment Variables section
5. **Click:** Add Environment Variable
6. **Fill in:**
   - Name: `GROQ_API_KEY`
   - Value: `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`
7. **Click:** Save
8. **Wait:** Service auto-redeploys (~1-2 minutes)

### Step 3: Verify Deployment

Check Render dashboard:

- Green checkmark ✅ = Ready to serve requests
- If still deploying, wait for completion

### Step 4: Test the API

After Render finishes deploying:

```bash
# Test if Groq API key is working
curl -X POST "https://elmorbit-api.onrender.com/api/ai-mentor/chat" \
  -H "Content-Type: application/json" \
  -H "Origin: https://lernova-alpha.vercel.app" \
  -d '{
    "message": "Hello, can you help me with physics?",
    "history": [],
    "type": "explanation"
  }'

# Expected response (200 OK):
# {"response": "Of course! I'd be happy to help with physics....", "timestamp": "2026-04-20T..."}
```

### Step 5: Clear Browser Cache & Test

1. **Hard refresh browser:** `Ctrl+Shift+R`
2. **Go to:** https://lernova-alpha.vercel.app
3. **Click:** AI Mentor chat
4. **Send message:** "Hello"
5. **Expected:** AI responds within 3-5 seconds ✅

## Troubleshooting

### Issue: Still getting "Cannot read properties of undefined"

**Solution:**

- Verify Render deployment completed (check dashboard status)
- Wait 30-60 seconds after deployment shows "Ready"
- Hard refresh browser cache again

### Issue: "AI mentor service unavailable"

**Solution:**

- Check Render logs: Dashboard → Logs
- Look for error message about Groq API
- Verify the API key was entered correctly (no extra spaces)

### Issue: Render keeps redeploying

**Solution:**

- This is normal after setting env variable
- Wait for status to show "Ready" (green checkmark)
- Stop redeploys in Settings if needed

## Why This Happened

1. `.env` file is `.gitignore`d (correct for security)
2. Render can't access local `.env` files
3. Environment variables must be set manually in Render dashboard
4. VITE_API_URL was set on Vercel ✅, but GROQ_API_KEY wasn't set on Render ❌

## Summary

**Status After GROQ_API_KEY is set:**

- Frontend: `https://lernova-alpha.vercel.app` → ✅ Makes API calls
- Backend: `https://elmorbit-api.onrender.com` → ✅ Has Groq key
- CORS: ✅ Already configured
- AI Mentor: ✅ Should work!

**Estimated Time to Resolution:** 3 minutes
