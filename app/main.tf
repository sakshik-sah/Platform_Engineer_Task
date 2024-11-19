provider "aws" {
  region = "ap-south-1"  #our region
}

# S3 Bucket
resource "aws_s3_bucket" "app_bucket" {
  bucket_prefix = "demo-app-bucket-" 
}

resource "aws_s3_bucket_versioning" "app_bucket" {
  bucket = aws_s3_bucket.app_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "app_bucket" {
  bucket = aws_s3_bucket.app_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SQS Queue
resource "aws_sqs_queue" "app_queue" {
  name_prefix = "demo-app-queue-"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 86400
  receive_wait_time_seconds = 0

  tags = {
    Environment = "demo"
  }
}

# Secrets Manager Secret
resource "aws_secretsmanager_secret" "app_secret" {
  name_prefix = "demo-app-secret-"
  
  tags = {
    Environment = "demo"
  }
}

resource "aws_secretsmanager_secret_version" "app_secret_version" {
  secret_id     = aws_secretsmanager_secret.app_secret.id
  secret_string = jsonencode({
    "API_KEY" = "demo-secret-key-12345"
  })
}

# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "demo-app-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1a"  

  tags = {
    Name = "demo-app-subnet"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "demo-app-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "demo-app-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# IAM Role and Instance Profile for EC2
resource "aws_iam_role" "ec2_role" {
  name_prefix = "demo-app-ec2-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "ec2_policy" {
  name_prefix = "demo-app-ec2-policy-"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:*",
        "sqs:*",
        "secretsmanager:GetSecretValue"
      ]
      Resource = [
        aws_s3_bucket.app_bucket.arn,
        "${aws_s3_bucket.app_bucket.arn}/*",
        aws_sqs_queue.app_queue.arn,
        aws_secretsmanager_secret.app_secret.arn
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name_prefix = "demo-app-ec2-profile-"
  role = aws_iam_role.ec2_role.name
}

# Security Group
resource "aws_security_group" "app_sg" {
  name_prefix = "demo-app-sg-"
  description = "Security group for demo app"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "demo-app-sg"
  }
}

# Get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Instance
resource "aws_instance" "app_instance" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  
  # Make sure to create this key pair in AWS first
  key_name = "demo-app-key"  

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker git python3-pip
              systemctl start docker
              systemctl enable docker
              usermod -a -G docker ec2-user

              # Install Docker Compose
              curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose

              # Create app directory
              mkdir -p /app
              cd /app

              # Create application files
              cat > app.py << 'EOL'
              ${file("app.py")}
              EOL

              cat > requirements.txt << 'EOL'
              flask==2.0.1
              boto3==1.26.137
              python-dotenv==0.19.0
              EOL

              cat > Dockerfile << 'EOL'
              FROM python:3.9-slim
              WORKDIR /app
              COPY requirements.txt .
              RUN pip install --no-cache-dir -r requirements.txt
              COPY app.py .
              EXPOSE 5000
              CMD ["python", "app.py"]
              EOL

              cat > docker-compose.yml << 'EOL'
              version: '3'
              services:
                app:
                  build: .
                  ports:
                    - "5000:5000"
                  environment:
                    - AWS_DEFAULT_REGION=${data.aws_region.current.name}
                    - BUCKET_NAME=${aws_s3_bucket.app_bucket.id}
                    - QUEUE_URL=${aws_sqs_queue.app_queue.url}
                    - SECRET_NAME=${aws_secretsmanager_secret.app_secret.name}
                  restart: always
              EOL

              # Build and run the application
              docker-compose up -d
              EOF

  tags = {
    Name = "demo-app-instance"
  }

  depends_on = [
    aws_internet_gateway.main
  ]
}

# Get current region
data "aws_region" "current" {}

# Outputs
output "ec2_public_ip" {
  value = aws_instance.app_instance.public_ip
  description = "Public IP of EC2 instance"
}

output "s3_bucket_name" {
  value = aws_s3_bucket.app_bucket.id
  description = "Name of the S3 bucket"
}

output "sqs_queue_url" {
  value = aws_sqs_queue.app_queue.url
  description = "URL of the SQS queue"
}

output "secret_name" {
  value = aws_secretsmanager_secret.app_secret.name
  description = "Name of the Secrets Manager secret"
}