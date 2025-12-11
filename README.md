# Email Processing Platform

email processing system using microservices on AWS, two Python apps that work together - one validates incoming emails via REST API, the other processes them in the background. Everything runs on Kubernetes (EKS) and gets deployed automatically through GitHub Actions.

## Description:

The project split into a few main pieces:

- An email validation API that checks if the email data looks right and tosses it into a queue
- A background processor that grabs messages from the queue and saves them to S3  
- All the AWS infrastructure (EKS cluster, networking, storage) built with Terraform modules
- CI/CD pipelines that handle building, testing, and deploying everything automatically

## How It's Organized

```
├── .github/workflows/          # The CI/CD 
│   ├── terraform-infrastructure.yml
│   ├── build-and-test.yml
│   └── deploy-to-eks.yml
├── infra/                      # All the Terraform stuff
│   ├── terraform/
│   │   ├── modules/           # modules
│   │   │   ├── eks/          # EKS cluster setup
│   │   │   ├── networking/   # VPC and networking
│   │   │   ├── storage/      # ECR and S3 bucket
│   │   │   └── messaging/    # SQS queues and config
│   │   └── environments/     # Different env configs
│   └── kubernetes-manifests/ # K8s deployment files
├── services/                  # The actual microservices
    ├── email-validation/     # REST API
    └── email-processor/      # Background worker
```

## The Infrastructure Modules

**Networking Module** - Sets up the basic AWS networking
- VPC with public and private subnets across 2 availability zones
- NAT Gateway so the private subnets can reach the internet
- All the subnet tags that EKS needs to work properly

**EKS Module** - The Kubernetes cluster and its needs
- EKS cluster with managed node groups 
- AWS Load Balancer Controller installed via Helm
- IAM Roles for Service Accounts (IRSA) so the pods can talk to AWS services securely
- Separate service accounts for each microservice with minimal permissions

**Storage Module** - Where we keep our stuff
- ECR repository for the Docker images
- S3 bucket with versioning turned on and proper encryption
- Bucket policies that only let the right services access it

**Messaging Module** - The communication layer
- SQS queue for passing messages between services
- Dead letter queue for when things go wrong
- SSM parameters to store configuration (like queue URLs and bucket names)
- Queue policies so only our services can use them

### Kubernetes Setup

K8s deployments as secure as possible:
- Containers run as non-root users with read-only filesystems
- Dropped all unnecessary Linux capabilities 
- Each service has its own service account that can only access what it needs
- Added proper health checks so K8s knows when things are working

## The Two Services

### Email Validation API

This is the front-door service that handles incoming requests:
- Takes email data and validates it using Marshmallow (great library btw)
- Checks the auth token against what's stored in SSM Parameter Store
- If everything looks good, drops the message into SQS for processing
- Has a `/health` endpoint so the load balancer knows it's alive

It gets the SQS queue URL from SSM at runtime.

### Email Processor Worker

Runs in the background and does the actual work:
- Polls the SQS queue for new messages (using long polling to be efficient)
- Processes the email data and saves it to S3
- Deletes the message from the queue when done, or sends it to the dead letter queue if something goes wrong
- Can handle multiple messages at once and has configurable polling intervals

Both services log everything with unique request IDs to trace a request all the way through the system.

## The CI/CD Setup

I set up three GitHub Actions workflows that work together:

### 1. Infrastructure Pipeline
This runs first and sets up all the AWS resources using Terraform. It gets triggered when there is changes`infra/terraform/` folder. After it's done, it exports outputs like the ECR URL and EKS cluster name for the other workflows to use.

### 2. Build & Test Pipeline  
This one runs the tests, builds Docker images, and pushes them to ECR. it automatically grabs the version from Git tags using:
```bash
git tag --sort=-version:refname | head -n 1
```
If there are no tags, it just uses `v0.1.0`. Images get tagged like `email-validation-v1.2.3-abc1234` (service-version-git-sha).

### 3. Deploy Pipeline
Takes the freshly built images and deploys them to the EKS cluster. It uses `envsubst` to inject the image URLs into the Kubernetes manifests, then applies them and waits for everything to be healthy.

### How Configuration Works
The services look up the SQS and S3 names from SSM Parameter Store when they start up. This means I can deploy the same image to different environments and it'll automatically use the right resources.

The Terraform outputs get passed between workflows as artifacts, so each stage knows what the previous one created.

## Using the API

### POST /validate
Send an email for processing. You need to include the auth token that's stored in SSM.

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

If everything's good, you'll get back:
```json
{
  "message": "Payload validation and processing successful",
  "request_id": "20241210_143022_123456",
  "status": "published_to_queue"
}
```

### GET /health
returns whether the service is alive and what it's configured to use.

## Testing It Out

Once everything's deployed, you can test the API with curl. First, get the public endpoint:

```bash
# Get the ALB endpoint URL
kubectl get ingress email-validation-ingress -n email-services -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Then test the health endpoint:
```bash
# Replace YOUR_ALB_URL with the actual URL from above
curl -X GET http://YOUR_ALB_URL/health
```

And test the validation endpoint:
```bash
curl -X POST http://YOUR_ALB_URL/validate \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "email_subject": "Test Email",
      "email_sender": "test@example.com",
      "email_timestream": "1693561101",
      "email_content": "This is a test email message"
    },
    "token": "$DJISA<$#45ex3RtYr"
  }'
```

If everything's working, you should get back a response with a request ID and "published_to_queue" status. The email processor will then pick up the message from SQS and save it to S3.

## Getting It Running

### What You Need
- An AWS account with enough permissions to create EKS clusters, VPCs, etc.
- GitHub repo secrets set up with your AWS credentials:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY` 
  - `AWS_REGION`

### The Automation
Just push to the `main` branch and watch the magic happen:
1. Infrastructure gets created/updated
2. Docker images get built and pushed to ECR  
3. Services get deployed to EKS
4. You get a public ALB endpoint to hit

## Configuration Strategy

The key SSM parameters are:
- `/email-service/auth-token` - The auth token (encrypted)
- `/email-service/sqs-queue-url` - SQS queue URL  
- `/email-service/s3-bucket-name` - S3 bucket name

This way the services figure out what resources to use at runtime.
