# 🚀 Render Deployment Checklist (Windows PowerShell)
# Run this before deploying to verify everything is ready

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🚀 LERNOVA API - RENDER DEPLOYMENT CHECKLIST" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Check 1: .env file security
Write-Host "✓ Checking .env security..." -ForegroundColor Yellow
$gitFiles = git ls-files 2>$null | Select-String "\.env$"
if ($gitFiles) {
    Write-Host "  ❌ ERROR: .env is committed! Remove it: git rm --cached .env" -ForegroundColor Red
    exit 1
}
else {
    Write-Host "  ✅ .env is properly ignored" -ForegroundColor Green
}

# Check 2: .gitignore contains .env
Write-Host ""
Write-Host "✓ Checking .gitignore..." -ForegroundColor Yellow
if (Select-String -Path ".gitignore" -Pattern "^\.env" -Quiet) {
    Write-Host "  ✅ .env is in .gitignore" -ForegroundColor Green
}
else {
    Write-Host "  ❌ ERROR: Add .env to .gitignore" -ForegroundColor Red
    exit 1
}

# Check 3: .env.example exists
Write-Host ""
Write-Host "✓ Checking .env.example..." -ForegroundColor Yellow
if (Test-Path ".env.example") {
    Write-Host "  ✅ .env.example exists" -ForegroundColor Green
}
else {
    Write-Host "  ⚠️  WARNING: .env.example not found" -ForegroundColor Yellow
}

# Check 4: Dockerfile exists
Write-Host ""
Write-Host "✓ Checking Dockerfile..." -ForegroundColor Yellow
if (Test-Path "Dockerfile") {
    Write-Host "  ✅ Dockerfile found" -ForegroundColor Green
    if (Select-String -Path "Dockerfile" -Pattern "EXPOSE 8000" -Quiet) {
        Write-Host "  ✅ Correct port configured (8000)" -ForegroundColor Green
    }
    if (Select-String -Path "Dockerfile" -Pattern "HEALTHCHECK" -Quiet) {
        Write-Host "  ✅ Health check configured" -ForegroundColor Green
    }
}
else {
    Write-Host "  ❌ ERROR: Dockerfile not found" -ForegroundColor Red
    exit 1
}

# Check 5: render.yaml exists
Write-Host ""
Write-Host "✓ Checking render.yaml..." -ForegroundColor Yellow
if (Test-Path "render.yaml") {
    Write-Host "  ✅ render.yaml found" -ForegroundColor Green
    if (Select-String -Path "render.yaml" -Pattern "lernova-api" -Quiet) {
        Write-Host "  ✅ Service name configured" -ForegroundColor Green
    }
}
else {
    Write-Host "  ❌ ERROR: render.yaml not found" -ForegroundColor Red
    exit 1
}

# Check 6: Python requirements
Write-Host ""
Write-Host "✓ Checking requirements..." -ForegroundColor Yellow
if (Test-Path "monitoring_requirements.txt") {
    Write-Host "  ✅ monitoring_requirements.txt found" -ForegroundColor Green
    if (Select-String -Path "monitoring_requirements.txt" -Pattern "fastapi" -Quiet) {
        Write-Host "  ✅ FastAPI is installed" -ForegroundColor Green
    }
    if (Select-String -Path "monitoring_requirements.txt" -Pattern "uvicorn" -Quiet) {
        Write-Host "  ✅ Uvicorn is installed" -ForegroundColor Green
    }
}
else {
    Write-Host "  ❌ ERROR: monitoring_requirements.txt not found" -ForegroundColor Red
    exit 1
}

# Check 7: Main app file
Write-Host ""
Write-Host "✓ Checking app file..." -ForegroundColor Yellow
if (Test-Path "monitoring_server.py") {
    Write-Host "  ✅ monitoring_server.py found" -ForegroundColor Green
    if (Select-String -Path "monitoring_server.py" -Pattern "FastAPI\(\)" -Quiet) {
        Write-Host "  ✅ FastAPI app initialized" -ForegroundColor Green
    }
    if (Select-String -Path "monitoring_server.py" -Pattern "@app.get.*health" -Quiet) {
        Write-Host "  ✅ Health endpoint configured" -ForegroundColor Green
    }
}
else {
    Write-Host "  ❌ ERROR: monitoring_server.py not found" -ForegroundColor Red
    exit 1
}

# Check 8: Git status
Write-Host ""
Write-Host "✓ Checking git status..." -ForegroundColor Yellow
if (Test-Path ".git") {
    Write-Host "  ✅ Git repository initialized" -ForegroundColor Green
    $uncommitted = (git status -s 2>$null).Count
    if ($uncommitted -gt 0) {
        Write-Host "  ⚠️  You have $uncommitted uncommitted changes" -ForegroundColor Yellow
        Write-Host "     Consider committing before deploy:" -ForegroundColor Yellow
        Write-Host "     git add . && git commit -m 'Prepare for Render deployment'" -ForegroundColor Yellow
    }
    else {
        Write-Host "  ✅ All changes committed" -ForegroundColor Green
    }
}
else {
    Write-Host "  ❌ ERROR: Not a git repository" -ForegroundColor Red
    exit 1
}

# Check 9: Environment variables template
Write-Host ""
Write-Host "✓ Checking environment variables..." -ForegroundColor Yellow
Write-Host "  📝 You need to set these in Render Dashboard:" -ForegroundColor Cyan
Write-Host "     • SUPABASE_URL"
Write-Host "     • SUPABASE_SERVICE_ROLE_KEY ⚠️  SECRET" -ForegroundColor Yellow
Write-Host "     • SUPABASE_ANON_KEY ⚠️  SECRET" -ForegroundColor Yellow
Write-Host "     • CORS_ORIGINS"
Write-Host "     • PORT (already set to 8000)"

# Summary
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "✅ DEPLOYMENT READY!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next steps:" -ForegroundColor Cyan
Write-Host "   1. Go to https://render.com"
Write-Host "   2. Create new Web Service"
Write-Host "   3. Connect your GitHub repo (Lernova_API)"
Write-Host "   4. Set environment variables in Render Dashboard"
Write-Host "   5. Deploy!"
Write-Host ""
Write-Host "🤖 After deployment:" -ForegroundColor Cyan
Write-Host "   1. Go to https://uptimerobot.com"
Write-Host "   2. Create monitor: https://lernova-api.onrender.com/health"
Write-Host "   3. Interval: 5 minutes"
Write-Host ""
Write-Host "📚 For detailed guide, see: RENDER_DEPLOYMENT.md" -ForegroundColor Cyan
Write-Host ""
