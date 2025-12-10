# Email Validation REST API

A Python Flask REST API service that validates email request payloads, validates tokens against AWS SSM Parameter Store, and publishes validated data to AWS SQS.

## Features

- **Payload Validation**: Validates email data structure using Marshmallow schemas
- **Token Authentication**: Validates tokens against AWS SSM Parameter Store
- **SQS Integration**: Publishes validated data to AWS SQS queue
- **Comprehensive Logging**: Detailed logging for debugging and monitoring
- **Health Checks**: Built-in health check endpoint
- **Docker Support**: Containerized deployment with Docker Compose

## Prerequisites

- Python 3.12+
- AWS Account with SQS and SSM access
- AWS credentials configured

## Setup

### Local Development

1. Create and activate virtual environment:
```bash
python3 -m venv venv
source venv/bin/activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Set environment variables:
```bash
export SSM_PARAMETER_NAME="/email-service/auth-token"
export SQS_QUEUE_URL="https://sqs.us-east-1.amazonaws.com/123456789012/email-processing-queue"
export AWS_REGION="us-east-1"
```

4. Run the server:
```bash
python app.py
```

### Docker Deployment

1. Copy environment file:
```bash
cp .env.example .env
# Edit .env with your AWS credentials and configuration
```

2. Run with Docker Compose:
```bash
docker-compose up -d
```

The API will be available at `http://localhost:8080`

## API Endpoints

### POST /validate
Validates email payload structure, authenticates token, and publishes to SQS.

**Expected payload structure:**
```json
{
  "data": {
    "email_subject": "Happy new year!",
    "email_sender": "John doe", 
    "email_timestream": "1693561101",
    "email_content": "Just want to say... Happy new year!!!"
  },
  "token": "$DJISA<$#45ex3RtYr"
}
```

**Response (Success):**
```json
{
  "message": "Payload validation and processing successful",
  "request_id": "20241210_143022_123456",
  "status": "published_to_queue"
}
```

**Response (Validation Error):**
```json
{
  "error": "Validation failed",
  "details": { "data": { "email_timestream": ["Missing data for required field."] } },
  "request_id": "20241210_143022_123456"
}
```

**Response (Authentication Error):**
```json
{
  "error": "Invalid token",
  "request_id": "20241210_143022_123456"
}
```

### GET /health
Health check endpoint with service status.

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `SSM_PARAMETER_NAME` | SSM parameter path for auth token | `/email-service/auth-token` |
| `SQS_QUEUE_URL` | SQS queue URL for publishing messages | `https://sqs.us-east-1.amazonaws.com/123456789012/email-queue` |
| `AWS_REGION` | AWS region | `us-east-1` |
| `AWS_ACCESS_KEY_ID` | AWS access key | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | Your AWS secret key |

## AWS Setup

### 1. Create SSM Parameter
```bash
aws ssm put-parameter \
    --name "/email-service/auth-token" \
    --value "$DJISA<$#45ex3RtYr" \
    --type "SecureString" \
    --description "Authentication token for email validation service"
```

### 2. Create SQS Queue
```bash
aws sqs create-queue \
    --queue-name email-processing-queue \
    --attributes VisibilityTimeoutSeconds=300,MessageRetentionPeriod=1209600
```

## Testing

Run the comprehensive test script:
```bash
python test_api.py
```

## Logging

The service provides detailed logging including:
- Request/response tracking with unique request IDs
- Token validation attempts
- SQS publishing status
- Error details with stack traces
- Client IP addresses

Logs are written to both console and `api.log` file.