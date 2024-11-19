import os
import json
import boto3
import logging
from flask import Flask, request, jsonify
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Initialize AWS clients with explicit region
AWS_REGION = os.getenv('AWS_DEFAULT_REGION', 'ap-south-1')
BUCKET_NAME = os.getenv('BUCKET_NAME')
QUEUE_URL = os.getenv('QUEUE_URL')
SECRET_NAME = os.getenv('SECRET_NAME')

# Initialize AWS clients
session = boto3.Session(region_name=AWS_REGION)
s3_client = session.client('s3')
sqs_client = session.client('sqs')
secrets_client = session.client('secretsmanager')

logger.info(f"AWS Region: {AWS_REGION}")
logger.info(f"Bucket Name: {BUCKET_NAME}")
logger.info(f"Queue URL: {QUEUE_URL}")
logger.info(f"Secret Name: {SECRET_NAME}")

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'aws_region': AWS_REGION,
        'bucket_name': BUCKET_NAME,
        'queue_url': QUEUE_URL,
        'secret_name': SECRET_NAME
    }), 200

@app.route('/upload', methods=['POST'])
def upload_file():
    if 'file' not in request.files:
        return jsonify({'error': 'No file provided'}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No file selected'}), 400
        
    try:
        logger.info(f"Attempting to upload file {file.filename} to bucket {BUCKET_NAME}")
        s3_client.upload_fileobj(file, BUCKET_NAME, file.filename)
        return jsonify({
            'message': f'File {file.filename} uploaded successfully',
            'bucket': BUCKET_NAME,
            'key': file.filename
        }), 200
    except ClientError as e:
        logger.error(f"Error uploading file: {str(e)}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/message', methods=['POST'])
def send_message():
    try:
        data = request.get_json()
        if not data or 'message' not in data:
            return jsonify({'error': 'No message provided'}), 400
        
        logger.info(f"Attempting to send message to queue {QUEUE_URL}")
        response = sqs_client.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json.dumps(data)
        )
        return jsonify({
            'message': 'Message sent successfully',
            'message_id': response['MessageId']
        }), 200
    except ClientError as e:
        logger.error(f"Error sending message: {str(e)}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/message', methods=['GET'])
def receive_message():
    try:
        logger.info(f"Attempting to receive message from queue {QUEUE_URL}")
        response = sqs_client.receive_message(
            QueueUrl=QUEUE_URL,
            MaxNumberOfMessages=1,
            WaitTimeSeconds=0
        )
        
        messages = response.get('Messages', [])
        if not messages:
            return jsonify({'message': 'No messages available'}), 200
            
        message = messages[0]
        receipt_handle = message['ReceiptHandle']
        
        # Delete the message after receiving it
        sqs_client.delete_message(
            QueueUrl=QUEUE_URL,
            ReceiptHandle=receipt_handle
        )
        
        return jsonify({
            'message_id': message['MessageId'],
            'body': json.loads(message['Body'])
        }), 200
    except ClientError as e:
        logger.error(f"Error receiving message: {str(e)}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/secret', methods=['GET'])
def get_secret():
    try:
        logger.info(f"Attempting to get secret {SECRET_NAME}")
        response = secrets_client.get_secret_value(
            SecretId=SECRET_NAME
        )
        secret = json.loads(response['SecretString'])
        return jsonify({'api_key': secret['API_KEY']}), 200
    except ClientError as e:
        logger.error(f"Error getting secret: {str(e)}")
        return jsonify({'error': str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)