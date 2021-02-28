provider "aws" {
  region = var.region
}

# create vpc
resource "aws_vpc" "csye6225_vpc" {
  cidr_block = var.cidr_vpc
  tags = {
    Name = "csye6225_vpc"
  }
}

# subnet 1
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.csye6225_vpc.id
  cidr_block              = var.cidr_subnet[0]
  availability_zone       = join("", [var.region, var.a_zone[0]])
  map_public_ip_on_launch = true
  tags = {
    Name = "csye6225_subnet1"
  }
}

# subnet 2
resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.csye6225_vpc.id
  cidr_block              = var.cidr_subnet[1]
  availability_zone       = join("", [var.region, var.a_zone[1]])
  map_public_ip_on_launch = true
  tags = {
    Name = "csye6225_subnet2"
  }
}

# subnet 3
resource "aws_subnet" "subnet3" {
  vpc_id                  = aws_vpc.csye6225_vpc.id
  cidr_block              = var.cidr_subnet[2]
  availability_zone       = join("", [var.region, var.a_zone[2]])
  map_public_ip_on_launch = true
  tags = {
    Name = "csye6225_subnet3"
  }
}

# create internet gateway, attach to VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.csye6225_vpc.id
  tags = {
    Name = "csye6225_igw"
  }
}

# create public route table
resource "aws_route_table" "routeTable" {
  vpc_id = aws_vpc.csye6225_vpc.id
  tags = {
    Name = "csye6225_routeTable"
  }
}

# create public route
resource "aws_route" "route1" {
  route_table_id            = aws_route_table.routeTable.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_internet_gateway.igw.id
}

# attach all 3 subnets to route table 
resource "aws_route_table_association" "assoc1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.routeTable.id
}
resource "aws_route_table_association" "assoc2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.routeTable.id
}
resource "aws_route_table_association" "assoc3" {
  subnet_id      = aws_subnet.subnet3.id
  route_table_id = aws_route_table.routeTable.id
}

# application security group
resource "aws_security_group" "application_sg" {
  vpc_id      = aws_vpc.csye6225_vpc.id
  ingress {
    protocol        = "tcp"
    from_port       = "22"
    to_port         = "22"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol        = "tcp"
    from_port       = "80"
    to_port         = "80"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol        = "tcp"
    from_port       = "443"
    to_port       = "443"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol        = "tcp"
    from_port       = "8080"
    to_port         = "8080"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    "Name" = "csye6225_application_sg"
  }
}

# database security group
resource "aws_security_group" "database_sg" {
  vpc_id      = aws_vpc.csye6225_vpc.id
  ingress {
    protocol        = "tcp"
    from_port       = "3306"
    to_port         = "3306"
    security_groups = [aws_security_group.application_sg.id]
  }
  tags = {
    "Name" = "csye6225_database_sg"
  }
}

# S3 bucket
resource "aws_s3_bucket" "s3_bucket" {
  bucket        = var.bucket_name
  acl           = "private"
  force_destroy = true

  lifecycle_rule {
    id      = "StorageRule"
    enabled = true
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
  tags = {
    Name = "csye6225_s3_bucket"
  }
}

# database rds subnet group
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "csye6225_db_subnet_group"
  subnet_ids = [aws_subnet.subnet1.id, aws_subnet.subnet2.id, aws_subnet.subnet3.id]

  tags = {
    Name = "csye6225_subnet_group"
  }
}

# RDS instance
resource "aws_db_instance" "rds" {
  engine                 = var.db_engine
  instance_class         = var.db_instance_class
  multi_az               = var.db_multi_az
  identifier             = var.db_identifier
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  publicly_accessible    = var.db_publicly_accessible
  name                   = var.db_name
  vpc_security_group_ids = [aws_security_group.database_sg.id]
  tags = {
    "Name" = "csye6225_rds"
  }
}

#iam role for ec2
resource "aws_iam_role" "ec2_role" {
  name = var.ec2_role_name
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17", 
  "Statement": [
    {
      "Action": "sts:AssumeRole", 
      "Effect": "Allow", 
      "Principal": {
        "Service": "ec2.amazonaws.com"
      }
    }
  ]
}
EOF
  tags = {
    "Name" = "csye6225_ec2_role"
  }
}

#iam policy for ec2 role to access s3 for webapp
resource "aws_iam_role_policy" "webapp_s3_policy" {
  name   = var.webapp_s3_policy
  role   = aws_iam_role.ec2_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:ListBucket",
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.s3_bucket.arn}",
        "${aws_s3_bucket.s3_bucket.arn}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile_s3"
  role = aws_iam_role.ec2_role.name
}

# ec2 instance 
resource "aws_instance" "ec2" {
  ami                  = var.ec2_ami
  instance_type        = var.ec2_instance_type
  disable_api_termination = var.ec2_disable_api_termination
  security_groups      = [aws_security_group.application_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  subnet_id            = aws_subnet.subnet2.id
  key_name             = var.ec2_key_name

  ebs_block_device {
    device_name           = "csye6225_ec2_ebs"
    volume_type           = var.ec2_volume_type
    volume_size           = var.ec2_volume_size
    delete_on_termination = var.ec2_ebs_delete_on_termination
  }

  user_data = <<EOF
    #!/bin/bash

    ######################
    # Setting S3 for EC2 #
    ######################
    
    echo "export DB_USERNAME=${var.db_username}" >> /etc/environment
    echo "export DB_PASSWORD=${var.db_password}" >> /etc/environment
    echo "export DB_ENDPOINT=${aws_db_instance.rds.endpoint}"  >> /etc/environment
    echo "export DB_NAME=${var.db_name}" >> /etc/environment
    
    echo "export AWS_BUCKET=${aws_s3_bucket.s3_bucket.id}" >> /etc/environment
    echo "export AWS_BUCKET_NAME=${var.bucket_name}" >> /etc/environment
    
    echo "export DB_PORT=${aws_db_instance.rds.port}" >> /etc/environment
    echo "export DB_HOST=${aws_db_instance.rds.address}" >> /etc/environment
    echo "export FILESYSTEM_DRIVER=s3" >> /etc/environment
    echo "export AWS_DEFAULT_REGION=${var.region}" >> /etc/environment
    chown -R ubuntu:www-data /var/www
    usermod -a -G www-data ubuntu
  EOF

  tags = {
    "Name" = "csye6225_ec2"
  }

  depends_on = [aws_db_instance.rds]
}

output "rds_endpoint" {
    value = aws_db_instance.rds.endpoint
}