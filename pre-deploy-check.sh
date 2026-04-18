#!/bin/bash
# 🚀 Render Deployment Checklist
# Run this before deploying to verify everything is ready

set -e

echo "═══════════════════════════════════════════════════════════"
echo "🚀 LERNOVA API - RENDER DEPLOYMENT CHECKLIST"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check 1: .env file
echo "✓ Checking .env security..."
if git ls-files | grep -q "^\.env$"; then
    echo "  ❌ ERROR: .env is committed! Remove it: git rm --cached .env"
    exit 1
else
    echo "  ✅ .env is properly ignored"
fi

# Check 2: .gitignore contains .env
echo ""
echo "✓ Checking .gitignore..."
if grep -q "^\.env" .gitignore; then
    echo "  ✅ .env is in .gitignore"
else
    echo "  ❌ ERROR: Add .env to .gitignore"
    exit 1
fi

# Check 3: .env.example exists
echo ""
echo "✓ Checking .env.example..."
if [ -f ".env.example" ]; then
    echo "  ✅ .env.example exists"
else
    echo "  ⚠️  WARNING: .env.example not found"
fi

# Check 4: Dockerfile exists
echo ""
echo "✓ Checking Dockerfile..."
if [ -f "Dockerfile" ]; then
    echo "  ✅ Dockerfile found"
    if grep -q "EXPOSE 8000" Dockerfile; then
        echo "  ✅ Correct port configured (8000)"
    fi
    if grep -q "HEALTHCHECK" Dockerfile; then
        echo "  ✅ Health check configured"
    fi
else
    echo "  ❌ ERROR: Dockerfile not found"
    exit 1
fi

# Check 5: render.yaml exists
echo ""
echo "✓ Checking render.yaml..."
if [ -f "render.yaml" ]; then
    echo "  ✅ render.yaml found"
    if grep -q "lernova-api" render.yaml; then
        echo "  ✅ Service name configured"
    fi
else
    echo "  ❌ ERROR: render.yaml not found"
    exit 1
fi

# Check 6: Python requirements
echo ""
echo "✓ Checking requirements..."
if [ -f "monitoring_requirements.txt" ]; then
    echo "  ✅ monitoring_requirements.txt found"
    if grep -q "fastapi" monitoring_requirements.txt; then
        echo "  ✅ FastAPI is installed"
    fi
    if grep -q "uvicorn" monitoring_requirements.txt; then
        echo "  ✅ Uvicorn is installed"
    fi
else
    echo "  ❌ ERROR: monitoring_requirements.txt not found"
    exit 1
fi

# Check 7: Main app file
echo ""
echo "✓ Checking app file..."
if [ -f "monitoring_server.py" ]; then
    echo "  ✅ monitoring_server.py found"
    if grep -q "FastAPI()" monitoring_server.py; then
        echo "  ✅ FastAPI app initialized"
    fi
    if grep -q "@app.get.*health" monitoring_server.py; then
        echo "  ✅ Health endpoint configured"
    fi
else
    echo "  ❌ ERROR: monitoring_server.py not found"
    exit 1
fi

# Check 8: Git status
echo ""
echo "✓ Checking git status..."
if [ -d ".git" ]; then
    echo "  ✅ Git repository initialized"
    UNCOMMITTED=$(git status -s | wc -l)
    if [ "$UNCOMMITTED" -gt 0 ]; then
        echo "  ⚠️  You have $UNCOMMITTED uncommitted changes"
        echo "     Consider committing before deploy:"
        echo "     git add . && git commit -m 'Prepare for Render deployment'"
    else
        echo "  ✅ All changes committed"
    fi
else
    echo "  ❌ ERROR: Not a git repository"
    exit 1
fi

# Check 9: Environment variables template
echo ""
echo "✓ Checking environment variables..."
echo "  📝 You need to set these in Render Dashboard:"
echo "     • SUPABASE_URL"
echo "     • SUPABASE_SERVICE_ROLE_KEY ⚠️  SECRET"
echo "     • SUPABASE_ANON_KEY ⚠️  SECRET"
echo "     • CORS_ORIGINS"
echo "     • PORT (already set to 8000)"

# Summary
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ DEPLOYMENT READY!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📋 Next steps:"
echo "   1. Go to https://render.com"
echo "   2. Create new Web Service"
echo "   3. Connect your GitHub repo (Lernova_API)"
echo "   4. Set environment variables in Render Dashboard"
echo "   5. Deploy!"
echo ""
echo "🤖 After deployment:"
echo "   1. Go to https://uptimerobot.com"
echo "   2. Create monitor: https://lernova-api.onrender.com/health"
echo "   3. Interval: 5 minutes"
echo ""
echo "📚 For detailed guide, see: RENDER_DEPLOYMENT.md"
echo ""
