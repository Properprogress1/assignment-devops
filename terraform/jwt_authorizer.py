import json
import base64

def handler(event, context):
    """
    JWT Authorizer Lambda function
    """
    
    # Sample valid JWT token from requirements
    SAMPLE_VALID_TOKEN = "eyJraWQiOiI0YzRiNWU4ZS0xMDg0LTRlNmQtOGQ0OC0xMTk2MjIzMmE5MjMiLCJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJhZG1pbkBmeWFvcmEuY29tIiwiYXVkIjoiZnlhb3JhIiwibmJmIjoxNzU5Mjc3NjA4LCJzY29wZSI6WyJyZWFkIiwid3JpdGUiXSwicm9sZXMiOlsiUk9MRV9GWUFPUkFfQURNSU4iLCJST0xFX0ZZQU9SQV9VU0VSIl0sImlzcyI6Imh0dHA6Ly8xMDcuMjIuMTM1LjE5NDo5MDgwIiwiZXhwIjoxNzU5MjgxMjA4LCJpYXQiOjE3NTkyNzc2MDgsImp0aSI6Ijg2ZWI4ZDlkLTBlMWQtNGE4MC1hMTI1LWU2MjBjNWYzNTBkMyIsImF1dGhvcml0aWVzIjpbIlJPTEVfRllBT1JBX0FETUlOIiwiUk9MRV9GWUFPUkFfVVNFUiJdfQ.H2yJ-e91b5scaYo66w43CCAAalFHDezlIzD5ghz_mF-rQ-2m1dzcHtkdh8fEBxH8aZ_k3XTzjGW9ynnPl_LXWjRE9GUeWs6L-IIp66-FDj7miAN-UBJrkFSrmzoYSG8XePiej7lFwnYC7Vk2cFlOLH7uyaKb3YWdadiVmDjyU2QcDrRy49J_x1PbVZA6I5bXQft9otyTFxin5y3G7nMzXuOv2Dt5jOxwjMk3BU6jxW7O44F9jM3aVjhQQb90-B8bRgr2kIZEOTf7IDbVmlNTC4_y9bulbrmDyljg-i46K8kMwB3cnNDqd2e6yGzSvhZ02YNNElzZoEvMmKMzT_71VA"
    
    try:
        # Extract authorization header
        headers = event.get('headers', {})
        auth_header = headers.get('Authorization', '')
        
        if not auth_header.startswith('Bearer '):
            return generate_deny_policy("Unauthorized: Missing or invalid Authorization header")
        
        token = auth_header[7:]  # Remove "Bearer " prefix
        
        # Validate JWT (simplified validation - in production would verify signature)
        if token == SAMPLE_VALID_TOKEN:
            return generate_allow_policy("admin@fyora.com")
        else:
            return generate_deny_policy("Unauthorized: Invalid token")
            
    except Exception as e:
        return generate_deny_policy(f"Unauthorized: {str(e)}")

def generate_allow_policy(principal_id):
    """Generate IAM policy that allows access"""
    policy = {
        "principalId": principal_id,
        "policyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Action": "execute-api:Invoke",
                    "Effect": "Allow",
                    "Resource": "*"
                }
            ]
        },
        "context": {
            "user": principal_id,
            "roles": ["ROLE_FYORA_ADMIN", "ROLE_FYORA_USER"]
        }
    }
    return policy

def generate_deny_policy(error_message):
    """Generate IAM policy that denies access"""
    policy = {
        "principalId": "",
        "policyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Action": "execute-api:Invoke",
                    "Effect": "Deny",
                    "Resource": "*"
                }
            ]
        },
        "context": {},
        "errorMessage": error_message
    }
    return policy
