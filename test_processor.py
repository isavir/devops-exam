import json
import boto3
import time
from datetime import datetime
import os

def create_test_message():
    """Create a test message for SQS"""
    return {
        "email_subject": "Test Email Processing",
        "email_sender": "test@example.com",
        "email_timestream": str(int(time.time())),
        "email_content": "This is a test email for processor validation"
    }

def send_test_message_to_sqs():
    """Send a test message to SQS queue"""
    queue_url = os.getenv('SQS_QUEUE_URL')
    if not queue_url:
        print("SQS_QUEUE_URL environment variable not set")
        return
    
    sqs_client = boto3.client('sqs')
    
    try:
        message = create_test_message()
        response = sqs_client.send_message(
            QueueUrl=queue_url,
            MessageBody=json.dumps(message),
            MessageAttributes={
                'test_message': {
                    'StringValue': 'true',
                    'DataType': 'String'
                },
                'timestamp': {
                    'StringValue': datetime.now().isoformat(),
                    'DataType': 'String'
                }
            }
        )
        
        print(f"Test message sent successfully. MessageId: {response['MessageId']}")
        print(f"Message content: {json.dumps(message, indent=2)}")
        
    except Exception as e:
        print(f"Failed to send test message: {str(e)}")

def check_s3_bucket():
    """Check if S3 bucket exists and list recent objects"""
    bucket_name = os.getenv('S3_BUCKET_NAME')
    if not bucket_name:
        print("S3_BUCKET_NAME environment variable not set")
        return
    
    s3_client = boto3.client('s3')
    
    try:
        # Check if bucket exists
        s3_client.head_bucket(Bucket=bucket_name)
        print(f"S3 bucket '{bucket_name}' exists and is accessible")
        
        # List recent objects
        response = s3_client.list_objects_v2(
            Bucket=bucket_name,
            Prefix='emails/',
            MaxKeys=10
        )
        
        if 'Contents' in response:
            print(f"\nRecent objects in bucket:")
            for obj in response['Contents']:
                print(f"  - {obj['Key']} (Size: {obj['Size']} bytes, Modified: {obj['LastModified']})")
        else:
            print("No objects found in bucket")
            
    except Exception as e:
        print(f"Failed to access S3 bucket: {str(e)}")

def monitor_queue_stats():
    """Monitor SQS queue statistics"""
    queue_url = os.getenv('SQS_QUEUE_URL')
    if not queue_url:
        print("SQS_QUEUE_URL environment variable not set")
        return
    
    sqs_client = boto3.client('sqs')
    
    try:
        response = sqs_client.get_queue_attributes(
            QueueUrl=queue_url,
            AttributeNames=[
                'ApproximateNumberOfMessages',
                'ApproximateNumberOfMessagesNotVisible',
                'ApproximateNumberOfMessagesDelayed'
            ]
        )
        
        attributes = response['Attributes']
        print(f"\nSQS Queue Statistics:")
        print(f"  Available Messages: {attributes.get('ApproximateNumberOfMessages', 0)}")
        print(f"  In Flight Messages: {attributes.get('ApproximateNumberOfMessagesNotVisible', 0)}")
        print(f"  Delayed Messages: {attributes.get('ApproximateNumberOfMessagesDelayed', 0)}")
        
    except Exception as e:
        print(f"Failed to get queue statistics: {str(e)}")

def main():
    """Main test function"""
    print("Email Processor Test Suite")
    print("=" * 40)
    
    print("\n1. Checking SQS Queue Statistics:")
    monitor_queue_stats()
    
    print("\n2. Checking S3 Bucket:")
    check_s3_bucket()
    
    print("\n3. Sending Test Message:")
    send_test_message_to_sqs()
    
    print("\n4. Updated Queue Statistics:")
    time.sleep(2)  # Brief delay
    monitor_queue_stats()
    
    print("\nTest completed. Monitor the processor logs to see message processing.")

if __name__ == "__main__":
    main()