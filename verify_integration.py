#!/usr/bin/env python3
"""
Minimal integration verification test
This script verifies that the frontend-backend integration is correctly configured
"""

import sys
import json

def verify_backend_endpoint():
    """Verify the backend endpoint exists"""
    print("Checking backend endpoint implementation...")
    
    try:
        with open('main.py', 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
            
        if '@app.post("/api/ai-mentor/chat"' in content:
            print("✓ /api/ai-mentor/chat endpoint found")
            return True
        else:
            print("✗ /api/ai-mentor/chat endpoint NOT found")
            return False
    except Exception as e:
        print(f"Error checking backend: {e}")
        return False


def verify_frontend_config():
    """Verify frontend .env.local has API URL"""
    print("Checking frontend configuration...")
    
    try:
        import sys
        sys.path.insert(0, '../Lernova')
        
        with open('../Lernova/.env.local', 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
            
        if 'VITE_API_URL=' in content:
            for line in content.split('\n'):
                if 'VITE_API_URL=' in line:
                    api_url = line.split('=')[1].strip()
                    print(f"✓ Frontend API URL configured: {api_url}")
                    return True
        else:
            print("✗ VITE_API_URL NOT configured")
            return False
    except Exception as e:
        print(f"Error checking frontend config: {e}")
        return False


def verify_groq_refactored():
    """Verify groq.ts uses backend endpoint"""
    print("Checking groq.ts refactoring...")
    
    try:
        with open('../Lernova/src/app/lib/groq.ts', 'r') as f:
            content = f.read()
            
        if 'BACKEND_AI_MENTOR_ENDPOINT' in content and 'getBackendEndpoint' in content:
            count = content.count('BACKEND_AI_MENTOR_ENDPOINT')
            print(f"✓ groq.ts uses BACKEND_AI_MENTOR_ENDPOINT ({count} references)")
            return True
        else:
            print("✗ groq.ts NOT refactored for backend")
            return False
    except Exception as e:
        print(f"Error checking groq.ts: {e}")
        return False


def verify_deleted_files():
    """Verify backend files deleted from frontend"""
    print("Checking deleted backend files...")
    
    import os
    
    files_to_check = [
        '../Lernova/src/app/lib/monitoringAPI.ts',
        '../Lernova/supabase/functions/server'
    ]
    
    all_deleted = True
    for filepath in files_to_check:
        if os.path.exists(filepath):
            print(f"✗ {filepath} still EXISTS")
            all_deleted = False
        else:
            print(f"✓ {filepath} deleted")
    
    return all_deleted


if __name__ == '__main__':
    print("=" * 60)
    print("INTEGRATION VERIFICATION")
    print("=" * 60)
    print()
    
    results = []
    
    print("1. Backend Endpoint Check:")
    results.append(verify_backend_endpoint())
    print()
    
    print("2. Frontend Configuration Check:")
    results.append(verify_frontend_config())
    print()
    
    print("3. Frontend Refactoring Check:")
    results.append(verify_groq_refactored())
    print()
    
    print("4. Deleted Files Check:")
    results.append(verify_deleted_files())
    print()
    
    print("=" * 60)
    if all(results):
        print("✓ ALL CHECKS PASSED - INTEGRATION COMPLETE")
        sys.exit(0)
    else:
        print("✗ SOME CHECKS FAILED")
        sys.exit(1)
