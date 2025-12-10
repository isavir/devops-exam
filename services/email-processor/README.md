# Email Processor Service

A Python microservice that polls SQS messages from the email validation service and uploads them to S3 for long-term storage and processing.

## Features

- **SQS Message Polling**: Continuously polls SQS queue for new email messages
- **S3 Upload**: Uploads processed messages to S3 with organized folder structure
- **Graceful Shutdown**: Handles SIGTERM and SIGINT signals for clean shutdown
- **Error Handling**: Comprehensive error handling with retry logic
- **Health Monitoring**: Built-in health checks and monitoring capabilities
- **Configurable Polling**: Adjustable polling intervals and batch sizes

## Architecture

```
SQS Queue → Email Processor → S3 Bucket
    ↑              ↓
Email Validation   Logs & Metrics
```

## Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `SQS_QUEUE_URL` | SQS queue URL to poll messages from | - | Yes |
| `S3_BUCKET_NAME` | S3 bucket name for storing emails | - | Yes |
| `AWS_REGION` | AWS region | `us-east-1` | No |
| `POLL_INTERVAL_SECONDS` | Seconds between polling cycles | `30` | No |
| `MAX_MESSAGES_PER_POLL` | Maximum messages per SQS poll | `10` | No |
| `VISIBILITY_TIMEOUT_SECONDS` | SQS message visibility timeout | `300` | No |

### AWS Permissions Required

The service requires the following AWS permissions:

**SQS Permissions:**
- `sqs:ReceiveMessage`
- `sqs:DeleteMessage`
- `sqs:GetQueueAttributes`

**S3 Permissions:**
- `s3:PutObject`
- `s3:GetObject`
- `s3:ListBucket`

**KMS Permissions (if using encrypted S3):**
- `kms:Decrypt`
- `kms:GenerateDataKey`

## S3 Storage Structure

Messages are stored in S3 with the following structure:

```
s3://bucket-name/
├── emails/
│   ├── 2024/
│   │   ├── 12/
│   │   │   ├── 10/
│   │   │   │   ├── john.doe/
│   │   │   │   │   ├── msg-123_143022.json
│   │   │   │   │   └── msg-124_143055.json
│   │   │   │   └── jane.smith/
│   │   │   │       └── msg-125_143100.json
```

Each JSON file contains:
```json
{
  "message_id": "sqs-message-id",
  "processed_at": "2024-12-10T14:30:22Z",
  "email_data": {
    "email_subject": "Subject",
    "email_sender": "sender@example.com",
    "email_timestream": "1693561101",
    "email_content": "Email content"
  },
  "metadata": {
    "processor_version": "1.0.0",
    "source": "email-validation-service"
  }
}
```

## Local Development

### Setup

1. Create virtual environment:
```bash
python3 -m venv venv
source venv/bin/activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Configure environment:
```bash
cp .env.example .env
# Edit .env with your AWS credentials and configuration
```

4. Run the service:
```bash
python app.py
```

### Testing

1. Send test messages to SQS:
```bash
python test_processor.py
```

2. Monitor processing:
```bash
tail -f processor.log
```

## Docker Deployment

### Build and Run

```bash
# Build image
docker build -t email-processor .

# Run container
docker run -d \
  --name email-processor \
  --env-file .env \
  email-processor
```

### Docker Compose

```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f email-processor

# Stop services
docker-compose down
```

## Kubernetes Deployment

The service is designed to run in Kubernetes with proper RBAC and service accounts.

### Prerequisites

- EKS cluster with OIDC provider
- IAM roles for service accounts (IRSA) configured
- SQS queue and S3 bucket created via Terraform

### Deploy

```bash
# Apply Kubernetes manifests
kubectl apply -f infra/kubernetes-manifests/email-processor-service/

# Check deployment status
kubectl get pods -l app=email-processor-service

# View logs
kubectl logs -l app=email-processor-service -f
```

## Monitoring

### Logs

The service provides structured logging with the following levels:
- `INFO`: Normal operation events
- `WARNING`: Non-critical issues
- `ERROR`: Error conditions
- `DEBUG`: Detailed debugging information

### Metrics

Key metrics to monitor:
- Messages processed per minute
- Processing errors
- S3 upload success rate
- Queue depth
- Processing latency

### Health Checks

The service includes:
- Kubernetes liveness/readiness probes
- Periodic health check CronJob
- AWS service connectivity validation

## Troubleshooting

### Common Issues

1. **No messages being processed**
   - Check SQS queue URL configuration
   - Verify AWS credentials and permissions
   - Check queue has messages

2. **S3 upload failures**
   - Verify S3 bucket exists and is accessible
   - Check IAM permissions for S3 operations
   - Verify KMS key permissions if using encryption

3. **High memory usage**
   - Reduce `MAX_MESSAGES_PER_POLL`
   - Increase `POLL_INTERVAL_SECONDS`
   - Check for memory leaks in logs

### Debug Commands

```bash
# Check AWS connectivity
aws sts get-caller-identity

# Test SQS access
aws sqs get-queue-attributes --queue-url $SQS_QUEUE_URL

# Test S3 access
aws s3 ls s3://$S3_BUCKET_NAME/

# View Kubernetes events
kubectl get events --sort-by=.metadata.creationTimestamp
```

## Performance Tuning

### Polling Configuration

- **High throughput**: Decrease `POLL_INTERVAL_SECONDS`, increase `MAX_MESSAGES_PER_POLL`
- **Low resource usage**: Increase `POLL_INTERVAL_SECONDS`, decrease `MAX_MESSAGES_PER_POLL`
- **Cost optimization**: Use longer polling intervals during low-traffic periods

### Resource Limits

Adjust Kubernetes resource limits based on workload:
- CPU: 100m-200m for normal workloads
- Memory: 128Mi-256Mi depending on message size and batch size

## Security

- Runs as non-root user (UID 1000)
- Read-only root filesystem
- Minimal capabilities
- Encrypted S3 storage with KMS
- IAM roles with least privilege access