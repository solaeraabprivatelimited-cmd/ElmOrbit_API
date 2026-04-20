#!/usr/bin/env python3
"""
Test script to verify AI mentor endpoint works
Run this to test the backend /api/ai-mentor/chat endpoint
"""

import requests
import json
import os
from dotenv import load_dotenv

load_dotenv()

BASE_URL = os.getenv("API_URL", "http://localhost:8000")

def test_ai_mentor_endpoint():
    """Test the AI mentor chat endpoint"""
    print("Testing AI Mentor Chat Endpoint")
    print(f"Target: {BASE_URL}/api/ai-mentor/chat")
    print("-" * 50)
    
    # Test payload matching what frontend sends
    payload = {
        "message": "Explain photosynthesis in simple terms",
        "history": [],
        "type": "explanation"
    }
    
    try:
        print(f"Sending request: {json.dumps(payload, indent=2)}")
        response = requests.post(
            f"{BASE_URL}/api/ai-mentor/chat",
            json=payload,
            timeout=30
        )
        
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"Response: {json.dumps(data, indent=2)}")
            print("\n✅ AI Mentor endpoint is working!")
            return True
        elif response.status_code == 503:
            print("⚠️  Groq API not configured (set GROQ_API_KEY environment variable)")
            print(f"Response: {response.json()}")
            return True  # Endpoint exists, just API key not set
        else:
            print(f"❌ Error: {response.status_code}")
            print(f"Response: {response.text}")
            return False
    
    except requests.exceptions.ConnectionError:
        print("❌ Connection failed - is the backend running?")
        print(f"   Try: python main.py or uvicorn main:app --reload")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False


def test_health_endpoint():
    """Test the health endpoint"""
    print("Testing Health Endpoint")
    print(f"Target: {BASE_URL}/health")
    print("-" * 50)
    
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=10)
        print(f"Status Code: {response.status_code}")
        if response.status_code == 200:
            print(f"Response: {json.dumps(response.json(), indent=2)}")
            print("✅ Health endpoint is working!")
            return True
        else:
            print(f"❌ Error: {response.status_code}")
            return False
    except requests.exceptions.ConnectionError:
        print("❌ Connection failed - is the backend running?")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False


if __name__ == "__main__":
    print("=" * 50)
    print("AI MENTOR BACKEND INTEGRATION TEST")
    print("=" * 50)
    print()
    
    # Test health first
    health_ok = test_health_endpoint()
    print()
    
    if health_ok:
        # Test AI mentor endpoint
        test_ai_mentor_endpoint()
    else:
        print("Health check failed - cannot proceed")
