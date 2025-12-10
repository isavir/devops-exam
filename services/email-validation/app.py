from flask import Flask, request, jsonify
from marshmallow import Schema, fields, ValidationError
import logging
import sys
from datetime import datetime
import json
import os
import boto3
from botocore.exceptions import ClientError, NoCredentialsError

app = Flask(__name__)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('api.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# AWS clients
try:
    ssm_client = boto3.client('ssm')
    sqs_client = boto3.client('sqs')
    logger.info("AWS clients initialized successfully")
except NoCredentialsError:
    logger.error("AWS credentials not found")
    ssm_client = None
    sqs_client = None

# Environment variables
SSM_PARAMETER_NAME = os.getenv('SSM_PARAMETER_NAME', '/email-service/auth-token')
SQS_QUEUE_URL_PARAMETER = os.getenv('SQS_QUEUE_URL_PARAMETER', '/email-service/sqs-queue-url')

# Get SQS Queue URL from SSM
SQS_QUEUE_URL = None
if ssm_client:
    try:
        response = ssm_client.get_parameter(Name=SQS_QUEUE_URL_PARAMETER)
        SQS_QUEUE_URL = response['Parameter']['Value']
        logger.info(f"Retrieved SQS Queue URL from SSM parameter: {SQS_QUEUE_URL_PARAMETER}")
    except ClientError as e:
        logger.error(f"Failed to retrieve SQS Queue URL from SSM parameter {SQS_QUEUE_URL_PARAMETER}: {str(e)}")
    except Exception as e:
        logger.error(f"Unexpected error retrieving SQS Queue URL from SSM: {str(e)}")

if not SSM_PARAMETER_NAME:
    logger.error("SSM_PARAMETER_NAME environment variable not set")
if not SQS_QUEUE_URL:
    logger.error("SQS_QUEUE_URL could not be retrieved from SSM parameter")

def validate_token(provided_token, request_id):
    """Validate token against SSM parameter store"""
    if not ssm_client or not SSM_PARAMETER_NAME:
        logger.error(f"[{request_id}] SSM client or parameter name not configured")
        return False
    
    try:
        logger.debug(f"[{request_id}] Retrieving token from SSM parameter: {SSM_PARAMETER_NAME}")
        response = ssm_client.get_parameter(
            Name=SSM_PARAMETER_NAME,
            WithDecryption=True
        )
        stored_token = response['Parameter']['Value']
        
        is_valid = provided_token == stored_token
        logger.info(f"[{request_id}] Token validation result: {'VALID' if is_valid else 'INVALID'}")
        return is_valid
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        logger.error(f"[{request_id}] SSM error ({error_code}): {str(e)}")
        return False
    except Exception as e:
        logger.error(f"[{request_id}] Unexpected error during token validation: {str(e)}")
        return False

def publish_to_sqs(data, request_id):
    """Publish validated data to SQS queue"""
    if not sqs_client or not SQS_QUEUE_URL:
        logger.error(f"[{request_id}] SQS client or queue URL not configured")
        return False
    
    try:
        message_body = json.dumps(data)
        logger.debug(f"[{request_id}] Publishing message to SQS: {SQS_QUEUE_URL}")
        
        response = sqs_client.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=message_body,
            MessageAttributes={
                'request_id': {
                    'StringValue': request_id,
                    'DataType': 'String'
                },
                'email_sender': {
                    'StringValue': data.get('email_sender', 'unknown'),
                    'DataType': 'String'
                },
                'timestamp': {
                    'StringValue': datetime.now().isoformat(),
                    'DataType': 'String'
                }
            }
        )
        
        message_id = response['MessageId']
        logger.info(f"[{request_id}] Message published to SQS successfully. MessageId: {message_id}")
        return True
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        logger.error(f"[{request_id}] SQS error ({error_code}): {str(e)}")
        return False
    except Exception as e:
        logger.error(f"[{request_id}] Unexpected error during SQS publish: {str(e)}")
        return False

class EmailDataSchema(Schema):
    email_subject = fields.Str(required=True, allow_none=False)
    email_sender = fields.Str(required=True, allow_none=False)
    email_timestream = fields.Str(required=True, allow_none=False)
    email_content = fields.Str(required=True, allow_none=False)

class RequestSchema(Schema):
    data = fields.Nested(EmailDataSchema, required=True)
    token = fields.Str(required=True, allow_none=False)

@app.route('/validate-email', methods=['POST'])
def validate_email():
    request_id = datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    client_ip = request.environ.get('HTTP_X_FORWARDED_FOR', request.remote_addr)
    
    logger.info(f"[{request_id}] New validation request from {client_ip}")
    
    try:
        # Log request headers
        logger.debug(f"[{request_id}] Request headers: {dict(request.headers)}")
        
        # Parse JSON payload
        if not request.is_json:
            logger.warning(f"[{request_id}] Invalid content type: {request.content_type}")
            return jsonify({
                'error': 'Content-Type must be application/json'
            }), 400
        
        payload = request.get_json()
        logger.info(f"[{request_id}] Received payload with keys: {list(payload.keys()) if payload else 'None'}")
        
        # Log payload structure (without sensitive data)
        if payload and 'data' in payload:
            data_keys = list(payload['data'].keys()) if isinstance(payload['data'], dict) else 'Invalid'
            logger.info(f"[{request_id}] Data section keys: {data_keys}")
            logger.info(f"[{request_id}] Token present: {'token' in payload}")
        
        # Validate payload structure
        logger.debug(f"[{request_id}] Starting schema validation")
        schema = RequestSchema()
        result = schema.load(payload)
        logger.info(f"[{request_id}] Schema validation passed")
        
        # Additional validation for timestream (should be numeric)
        timestream = result['data']['email_timestream']
        logger.debug(f"[{request_id}] Validating timestream: {timestream}")
        
        if not timestream.isdigit():
            logger.warning(f"[{request_id}] Invalid timestream format: {timestream}")
            return jsonify({
                'error': 'email_timestream must be a numeric string'
            }), 400
        
        # Validate token against SSM parameter store
        logger.debug(f"[{request_id}] Starting token validation")
        if not validate_token(result['token'], request_id):
            logger.warning(f"[{request_id}] Token validation failed")
            return jsonify({
                'error': 'Invalid token',
                'request_id': request_id
            }), 401
        
        logger.info(f"[{request_id}] Token validation successful")
        
        # Publish data to SQS
        logger.debug(f"[{request_id}] Publishing data to SQS")
        if not publish_to_sqs(result['data'], request_id):
            logger.error(f"[{request_id}] Failed to publish message to SQS")
            return jsonify({
                'error': 'Failed to process message',
                'request_id': request_id
            }), 500
        
        logger.info(f"[{request_id}] Validation and processing successful for email from: {result['data']['email_sender']}")
        
        return jsonify({
            'message': 'Payload validation and processing successful',
            'request_id': request_id,
            'status': 'published_to_queue'
        }), 200
        
    except ValidationError as err:
        logger.error(f"[{request_id}] Validation error: {err.messages}")
        return jsonify({
            'error': 'Validation failed',
            'details': err.messages,
            'request_id': request_id
        }), 400
    except json.JSONDecodeError as e:
        logger.error(f"[{request_id}] JSON decode error: {str(e)}")
        return jsonify({
            'error': 'Invalid JSON format',
            'details': str(e),
            'request_id': request_id
        }), 400
    except Exception as e:
        logger.error(f"[{request_id}] Unexpected error: {str(e)}", exc_info=True)
        return jsonify({
            'error': 'Internal server error',
            'details': str(e),
            'request_id': request_id
        }), 500

@app.route('/health', methods=['GET'])
def health_check():
    logger.info("Health check requested")
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'service': 'email-validation-api'
    }), 200

@app.before_request
def log_request_info():
    logger.info(f"Request: {request.method} {request.url} from {request.remote_addr}")

@app.after_request
def log_response_info(response):
    logger.info(f"Response: {response.status_code} for {request.method} {request.url}")
    return response

if __name__ == '__main__':
    logger.info("Starting Email Validation API server...")
    logger.info("Server configuration: host=0.0.0.0, port=8080, debug=True")
    app.run(debug=True, host='0.0.0.0', port=8080)