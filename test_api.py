import requests
import json
import os

# Test the API with valid payload
def test_valid_payload():
    url = "http://localhost:8080/validate"
    
    valid_payload = {
        "data": {
            "email_subject": "Happy new year!",
            "email_sender": "John doe",
            "email_timestream": "1693561101",
            "email_content": "Just want to say... Happy new year!!!"
        },
        "token": "$DJISA<$#45ex3RtYr"
    }
    
    response = requests.post(url, json=valid_payload)
    print(f"Valid payload response: {response.status_code}")
    print(f"Response: {response.json()}")

# Test with invalid payload (missing field)
def test_invalid_payload():
    url = "http://localhost:8080/validate"
    
    invalid_payload = {
        "data": {
            "email_subject": "Happy new year!",
            "email_sender": "John doe",
            # Missing email_timestream
            "email_content": "Just want to say... Happy new year!!!"
        },
        "token": "$DJISA<$#45ex3RtYr"
    }
    
    response = requests.post(url, json=invalid_payload)
    print(f"Invalid payload response: {response.status_code}")
    print(f"Response: {response.json()}")

if __name__ == "__main__":
    print("Testing API...")
    test_valid_payload()
    print("\n" + "="*50 + "\n")
    test_invalid_payload()

# Test with invalid token
def test_invalid_token():
    url = "http://localhost:8080/validate"
    
    invalid_token_payload = {
        "data": {
            "email_subject": "Happy new year!",
            "email_sender": "John doe",
            "email_timestream": "1693561101",
            "email_content": "Just want to say... Happy new year!!!"
        },
        "token": "invalid_token_123"
    }
    
    response = requests.post(url, json=invalid_token_payload)
    print(f"Invalid token response: {response.status_code}")
    print(f"Response: {response.json()}")

# Test health endpoint
def test_health():
    url = "http://localhost:8080/health"
    response = requests.get(url)
    print(f"Health check response: {response.status_code}")
    print(f"Response: {response.json()}")

if __name__ == "__main__":
    print("Testing Email Validation API with AWS Integration...")
    print("="*60)
    
    print("\n1. Testing health endpoint:")
    test_health()
    
    print("\n2. Testing valid payload:")
    test_valid_payload()
    
    print("\n3. Testing invalid payload (missing field):")
    test_invalid_payload()
    
    print("\n4. Testing invalid token:")
    test_invalid_token()
    
    print("\n" + "="*60)
    print("Note: For full testing, ensure AWS credentials and environment variables are set")