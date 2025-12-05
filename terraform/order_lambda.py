import json

def handler(event, context):
    body = {
        "orderId": "ORD-LOCAL-1",
        "customerId": "CUST-LOCAL",
        "totalAmount": 123.45,
        "status": "PENDING",
    }

    # Minimal API Gateway proxy-compatible response
    return {
        "statusCode": 200,
        "body": json.dumps(body),
        "isBase64Encoded": False,
        "headers": {"Content-Type": "application/json"},
    }
