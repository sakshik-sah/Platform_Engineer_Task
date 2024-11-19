# AWS Infrastructure and Application Deployment 🚀

Welcome to the AWS Infrastructure and Application Deployment project! This project demonstrates how to deploy a complete AWS infrastructure using Terraform and implement a Python Flask application that interacts with various AWS services.

## Features 🌟

- **Infrastructure as Code (IaC)**: Complete AWS infrastructure deployment using Terraform
- **AWS Services Integration**:
  - S3 for file storage
  - SQS for message queuing
  - Secrets Manager for secure data
  - EC2 for application hosting
- **Containerized Application**: Dockerized Flask application
- **RESTful API**: Well-structured endpoints for all services
- **Security**: IAM roles, security groups, and VPC configuration

## Architecture Overview 🏗️

The project consists of:
- VPC with public subnet
- EC2 instance running Docker
- S3 bucket for file storage
- SQS queue for message processing
- Secrets Manager for secret storage
- IAM roles and policies for security

## Getting Started 🎯

### Prerequisites

- AWS Account and AWS CLI configured
- Terraform installed
- Docker and Docker Compose
- Python 3.9+
- Git

### 📁 Project Structure
```
app/
└── main.tf
└── app.py
└── requirements.txt
└── Dockerfile
└── docker-compose.yml
└── README.md
```

### Installation 📥

1. Clone the repository
```bash
git clone https://github.com/yourusername/aws-infrastructure-project.git
cd aws-infrastructure-project
```

2. Configure AWS credentials
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter default region (ap-south-1)
# Enter output format (json)
```

3. Initialize Terraform
```bash
cd terraform
terraform init
```

### Deployment 🚀

1. Deploy Infrastructure
```bash
terraform apply -auto-approve
```

2. Save Output Values
```bash
export EC2_IP=$(terraform output -raw ec2_public_ip)
export BUCKET_NAME=$(terraform output -raw s3_bucket_name)
export QUEUE_URL=$(terraform output -raw sqs_queue_url)
export SECRET_NAME=$(terraform output -raw secret_name)
```

3. Connect to EC2 Instance
```bash
ssh -i demo-app-key.pem ec2-user@$EC2_IP
```

4. Deploy Application
```bash
cd /app
docker-compose up -d --build
```

## API Endpoints 🔌

### Health Check
```bash
curl http://localhost:5000/health
```

### File Operations (S3)
```bash
# Upload file
curl -X POST -F "file=@test.txt" http://localhost:5000/upload

# List files
curl http://localhost:5000/files
```

### Message Queue (SQS)
```bash
# Send message
curl -X POST -H "Content-Type: application/json" \
  -d '{"message":"Hello World"}' \
  http://localhost:5000/message

# Receive message
curl http://localhost:5000/message
```

### Secret Management
```bash
# Get secret
curl http://localhost:5000/secret
```

## Troubleshooting 🔧

### Common Issues

1. **S3 Upload Fails**
```bash
# Check bucket exists
aws s3 ls s3://$BUCKET_NAME
```

2. **SQS Message Fails**
```bash
# Check queue URL
aws sqs list-queues
```

3. **Container Issues**
```bash
# Check container status
docker ps
docker-compose logs app
```

## Security Considerations 🔒

- IAM roles with least privilege
- Security groups with minimal ports
- Encrypted secrets in Secrets Manager
- VPC with proper networking
- No hardcoded credentials

## Cleanup 🧹

To destroy all created resources:
```bash
terraform destroy -auto-approve
```

## Acknowledgments 🙏

- AWS Documentation
- Terraform Documentation
- Flask Documentation
- Docker Documentation
- Chatgpt & Claude