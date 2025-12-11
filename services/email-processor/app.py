import json
import logging
import sys
import time
import os
from datetime import datetime, timezone
from typing import Dict, List, Optional
import boto3
from botocore.exceptions import ClientError, NoCredentialsError
import signal
import threading

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('processor.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class EmailProcessor:
    def __init__(self):
        self.running = True
        self.sqs_client = None
        self.s3_client = None
        self.ssm_client = None
        self.queue_url = None
        self.s3_bucket = os.getenv('S3_BUCKET_NAME')
        self.sqs_queue_url_parameter = os.getenv('SQS_QUEUE_URL_PARAMETER', '/email-service/sqs-queue-url')
        self.poll_interval = int(os.getenv('POLL_INTERVAL_SECONDS', '30'))
        self.max_messages = int(os.getenv('MAX_MESSAGES_PER_POLL', '10'))
        self.visibility_timeout = int(os.getenv('VISIBILITY_TIMEOUT_SECONDS', '300'))
        
        self._initialize_aws_clients()
        self._get_sqs_queue_url_from_ssm()
        self._validate_configuration()
        
        # Setup graceful shutdown
        signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)
    
    def _initialize_aws_clients(self):
        """Initialize AWS clients"""
        try:
            self.sqs_client = boto3.client('sqs')
            self.s3_client = boto3.client('s3')
            self.ssm_client = boto3.client('ssm')
            logger.info("AWS clients initialized successfully")
        except NoCredentialsError:
            logger.error("AWS credentials not found")
            raise
        except Exception as e:
            logger.error(f"Failed to initialize AWS clients: {str(e)}")
            raise
    
    def _get_sqs_queue_url_from_ssm(self):
        """Retrieve SQS Queue URL from SSM Parameter Store"""
        try:
            response = self.ssm_client.get_parameter(Name=self.sqs_queue_url_parameter)
            self.queue_url = response['Parameter']['Value']
            logger.info(f"Retrieved SQS Queue URL from SSM parameter: {self.sqs_queue_url_parameter}")
        except ClientError as e:
            error_code = e.response['Error']['Code']
            logger.error(f"Failed to retrieve SQS Queue URL from SSM parameter {self.sqs_queue_url_parameter} ({error_code}): {str(e)}")
            raise
        except Exception as e:
            logger.error(f"Unexpected error retrieving SQS Queue URL from SSM: {str(e)}")
            raise
    
    def _validate_configuration(self):
        """Validate required configuration"""
        if not self.queue_url:
            raise ValueError("SQS Queue URL could not be retrieved from SSM parameter")
        if not self.s3_bucket:
            raise ValueError("S3_BUCKET_NAME environment variable is required")
        
        logger.info(f"Configuration validated - Queue: {self.queue_url}, Bucket: {self.s3_bucket}")
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully"""
        logger.info(f"Received signal {signum}, initiating graceful shutdown...")
        self.running = False
    
    def _generate_s3_key(self, message_data: Dict, message_id: str) -> str:
        """Generate S3 key for the email data"""
        timestamp = datetime.now(timezone.utc)
        date_prefix = timestamp.strftime('%Y/%m/%d')
        
        # Extract email sender for better organization
        email_sender = message_data.get('email_sender', 'unknown')
        safe_sender = ''.join(c for c in email_sender if c.isalnum() or c in '-_.')
        
        return f"emails/{date_prefix}/{safe_sender}/{message_id}_{timestamp.strftime('%H%M%S')}.json"
    
    def _upload_to_s3(self, message_data: Dict, message_id: str) -> bool:
        """Upload message data to S3"""
        try:
            s3_key = self._generate_s3_key(message_data, message_id)
            
            # Prepare the data for S3 upload
            upload_data = {
                'message_id': message_id,
                'processed_at': datetime.now(timezone.utc).isoformat(),
                'email_data': message_data,
                'metadata': {
                    'processor_version': '1.0.0',
                    'source': 'email-validation-service'
                }
            }
            
            # Upload to S3
            self.s3_client.put_object(
                Bucket=self.s3_bucket,
                Key=s3_key,
                Body=json.dumps(upload_data, indent=2),
                ContentType='application/json',
                Metadata={
                    'message-id': message_id,
                    'email-sender': message_data.get('email_sender', 'unknown'),
                    'processed-at': datetime.now(timezone.utc).isoformat()
                }
            )
            
            logger.info(f"Successfully uploaded message {message_id} to S3: s3://{self.s3_bucket}/{s3_key}")
            return True
            
        except ClientError as e:
            error_code = e.response['Error']['Code']
            logger.error(f"S3 upload failed for message {message_id} ({error_code}): {str(e)}")
            return False
        except Exception as e:
            logger.error(f"Unexpected error uploading message {message_id} to S3: {str(e)}")
            return False
    
    def _process_message(self, message: Dict) -> bool:
        """Process a single SQS message"""
        try:
            message_id = message['MessageId']
            receipt_handle = message['ReceiptHandle']
            
            logger.debug(f"Processing message {message_id}")
            
            # Parse message body
            try:
                message_body = json.loads(message['Body'])
            except json.JSONDecodeError as e:
                logger.error(f"Invalid JSON in message {message_id}: {str(e)}")
                return False
            
            # Validate message structure
            if not isinstance(message_body, dict):
                logger.error(f"Message {message_id} body is not a valid object")
                return False
            
            # Upload to S3
            if self._upload_to_s3(message_body, message_id):
                # Delete message from SQS after successful upload
                self.sqs_client.delete_message(
                    QueueUrl=self.queue_url,
                    ReceiptHandle=receipt_handle
                )
                logger.info(f"Successfully processed and deleted message {message_id}")
                return True
            else:
                logger.error(f"Failed to upload message {message_id}, leaving in queue")
                return False
                
        except Exception as e:
            logger.error(f"Error processing message: {str(e)}", exc_info=True)
            return False
    
    def _poll_messages(self) -> List[Dict]:
        """Poll messages from SQS"""
        try:
            response = self.sqs_client.receive_message(
                QueueUrl=self.queue_url,
                MaxNumberOfMessages=self.max_messages,
                WaitTimeSeconds=20,  
                VisibilityTimeoutSeconds=self.visibility_timeout,
                MessageAttributeNames=['All']
            )
            
            messages = response.get('Messages', [])
            if messages:
                logger.info(f"Received {len(messages)} messages from SQS")
            else:
                logger.debug("No messages available in queue")
            
            return messages
            
        except ClientError as e:
            error_code = e.response['Error']['Code']
            logger.error(f"SQS polling failed ({error_code}): {str(e)}")
            return []
        except Exception as e:
            logger.error(f"Unexpected error polling SQS: {str(e)}")
            return []
    
    def _health_check(self) -> bool:
        """Perform health check on AWS services"""
        try:
            # Check SQS queue exists
            self.sqs_client.get_queue_attributes(
                QueueUrl=self.queue_url,
                AttributeNames=['QueueArn']
            )
            
            # Check S3 bucket access
            self.s3_client.head_bucket(Bucket=self.s3_bucket)
            
            return True
        except Exception as e:
            logger.error(f"Health check failed: {str(e)}")
            return False
    
    def run(self):
        """Main processing loop"""
        logger.info("Starting Email Processor service...")
        logger.info(f"Configuration: Queue={self.queue_url}, Bucket={self.s3_bucket}, Poll Interval={self.poll_interval}s")
        
        # Initial health check
        if not self._health_check():
            logger.error("Initial health check failed, exiting...")
            return
        
        processed_count = 0
        error_count = 0
        
        while self.running:
            try:
                # Poll for messages
                messages = self._poll_messages()
                
                if not messages:
                    # No messages, wait before next poll
                    time.sleep(self.poll_interval)
                    continue
                
                # Process messages
                batch_success = 0
                batch_errors = 0
                
                for message in messages:
                    if not self.running:
                        break
                    
                    if self._process_message(message):
                        batch_success += 1
                        processed_count += 1
                    else:
                        batch_errors += 1
                        error_count += 1
                
                logger.info(f"Batch processed: {batch_success} successful, {batch_errors} errors")
                logger.info(f"Total processed: {processed_count}, Total errors: {error_count}")
                
                # Brief pause between batches
                if self.running:
                    time.sleep(2)
                    
            except KeyboardInterrupt:
                logger.info("Received keyboard interrupt, shutting down...")
                break
            except Exception as e:
                logger.error(f"Unexpected error in main loop: {str(e)}", exc_info=True)
                error_count += 1
                time.sleep(10)  # Wait before retrying
        
        logger.info(f"Email Processor stopped. Final stats: {processed_count} processed, {error_count} errors")


def main():
    """Main entry point"""
    try:
        processor = EmailProcessor()
        processor.run()
    except Exception as e:
        logger.error(f"Failed to start Email Processor: {str(e)}", exc_info=True)
        sys.exit(1)

if __name__ == '__main__':
    main()