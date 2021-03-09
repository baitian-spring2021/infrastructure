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
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks  = ["0.0.0.0/0"]
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
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks  = ["0.0.0.0/0"]
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
  allocated_storage      = var.db_allocated_storage
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
  skip_final_snapshot    = true

  tags = {
    "Name" = "csye6225_rds"
  }
}

# ghactions ----------------------------------------------------------------------------

# get current aws account id
data "aws_caller_identity" "current" {}

# iam policy to allow gh to upload artifact to S3
resource "aws_iam_policy" "GH_Upload_To_S3" {
  name   = var.GH_Upload_To_S3
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:Get*",
        "s3:List*",
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "${var.codedeploy_bucket_arn}",
        "${var.codedeploy_bucket_arn}/*"
      ]
    }
  ]
}
EOF
}

# iam policy to allow gh to deploy app with ec2
resource "aws_iam_policy" "GH_Code_Deploy" {
  name   = var.GH_Code_Deploy
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:RegisterApplicationRevision",
        "codedeploy:GetApplicationRevision"
      ],
      "Resource": [
        "arn:aws:codedeploy:${var.region}:${data.aws_caller_identity.current.account_id}:application:${var.codedeploy_appname}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:CreateDeployment",
        "codedeploy:GetDeployment"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:GetDeploymentConfig"
      ],
      "Resource": [
        "arn:aws:codedeploy:${var.region}:${data.aws_caller_identity.current.account_id}:deploymentconfig:CodeDeployDefault.OneAtATime",
        "arn:aws:codedeploy:${var.region}:${data.aws_caller_identity.current.account_id}:deploymentconfig:CodeDeployDefault.HalfAtATime",
        "arn:aws:codedeploy:${var.region}:${data.aws_caller_identity.current.account_id}:deploymentconfig:CodeDeployDefault.AllAtOnce"
      ]
    }
  ]
}
EOF
}

# iam policy to allow gh to upload artifact to S3
resource "aws_iam_policy" "GH_EC2_AMI" {
  name   = var.GH_EC2_AMI
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AttachVolume",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CopyImage",
        "ec2:CreateImage",
        "ec2:CreateKeypair",
        "ec2:CreateSecurityGroup",
        "ec2:CreateSnapshot",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:DeleteKeyPair",
        "ec2:DeleteSecurityGroup",
        "ec2:DeleteSnapshot",
        "ec2:DeleteVolume",
        "ec2:DeregisterImage",
        "ec2:DescribeImageAttribute",
        "ec2:DescribeImages",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeRegions",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSnapshots",
        "ec2:DescribeSubnets",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:DetachVolume",
        "ec2:GetPasswordData",
        "ec2:ModifyImageAttribute",
        "ec2:ModifyInstanceAttribute",
        "ec2:ModifySnapshotAttribute",
        "ec2:RegisterImage",
        "ec2:RunInstances",
        "ec2:StopInstances",
        "ec2:TerminateInstances"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

# attach GH_Upload_To_S3 policy to ghactions user
resource "aws_iam_user_policy_attachment" "gh_GH_Upload_To_S3_attacher" {
  user       = var.ghactions_name
  policy_arn = aws_iam_policy.GH_Upload_To_S3.arn
}

# attach GH_Code_Deploy policy to ghactions user
resource "aws_iam_user_policy_attachment" "gh_GH_Code_Deploy_attacher" {
  user       = var.ghactions_name
  policy_arn = aws_iam_policy.GH_Code_Deploy.arn
}

# attach GH_EC2_AMI policy to ghactions user
resource "aws_iam_user_policy_attachment" "gh_GH_EC2_AMI_attacher" {
  user       = var.ghactions_name
  policy_arn = aws_iam_policy.GH_EC2_AMI.arn
}

# CodeDeployEC2ServiceRole -------------------------------------------------------------

# iam role CodeDeployEC2ServiceRole for ec2
resource "aws_iam_role" "CodeDeployEC2ServiceRole" {
  name = var.CodeDeployEC2ServiceRole
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

# iam policy for ec2 role to access s3 for webapp
resource "aws_iam_policy" "webapp_s3_policy" {
  name   = var.webapp_s3_policy
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
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

# iam policy for ec2 role to retrieve webapp from S3
resource "aws_iam_policy" "CodeDeploy_EC2_S3" {
  name   = var.CodeDeploy_EC2_S3
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:Get*",
        "s3:List*"
      ],
      "Effect": "Allow",
      "Resource": [
        "${var.codedeploy_bucket_arn}",
        "${var.codedeploy_bucket_arn}/*"
      ]
    }
  ]
}
EOF
}

# attach webapp_s3_policy to CodeDeployEC2ServiceRole
resource "aws_iam_role_policy_attachment" "ec2_role_webapps3_attacher" {
  role       = aws_iam_role.CodeDeployEC2ServiceRole.name
  policy_arn = aws_iam_policy.webapp_s3_policy.arn
}

# attach CodeDeploy_EC2_S3 policy to CodeDeployEC2ServiceRole
resource "aws_iam_role_policy_attachment" "ec2_role_codedeploy_attacher" {
  role       = aws_iam_role.CodeDeployEC2ServiceRole.name
  policy_arn = aws_iam_policy.CodeDeploy_EC2_S3.arn
}

# ec2 profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.CodeDeployEC2ServiceRole.name
}

# CodeDeployServiceRole ----------------------------------------------------------------

# iam role CodeDeployServiceRole for codedeploy
resource "aws_iam_role" "CodeDeployServiceRole" {
  name = var.CodeDeployServiceRole
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17", 
  "Statement": [
    {
      "Action": "sts:AssumeRole", 
      "Effect": "Allow", 
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      }
    }
  ]
}
EOF
  tags = {
    "Name" = "csye6225_codedeploy_role"
  }
}

# attach AWSCodeDeployRole policy to CodeDeployServiceRole
resource "aws_iam_role_policy_attachment" "CodeDeployServiceRole_policy_attacher" {
  role       = aws_iam_role.CodeDeployServiceRole.name
  policy_arn = var.AWSCodeDeployRole_policy
}

# launch ec2 instance and code deploy app ----------------------------------------------

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
    device_name           = "/dev/sda1"
    volume_type           = var.ec2_volume_type
    volume_size           = var.ec2_volume_size
    delete_on_termination = var.ec2_ebs_delete_on_termination
  }

  user_data = <<-EOF
    #!/bin/bash

    ######################
    # Setting S3 for EC2 #
    ######################

    sudo echo export "DB_USERNAME=${var.db_username}" >> /etc/environment
    sudo echo export "DB_PASSWORD=${var.db_password}" >> /etc/environment
    sudo echo export "DB_ENDPOINT=${aws_db_instance.rds.endpoint}"  >> /etc/environment
    sudo echo export "DB_NAME=${var.db_name}" >> /etc/environment
    sudo echo export "S3_BUCKET_NAME=${var.bucket_name}" >> /etc/environment
    sudo echo export "AWS_DEFAULT_REGION=${var.region}" >> /etc/environment
  EOF

  tags = {
    "Name" = "csye6225_ec2"
  }

  depends_on = [aws_db_instance.rds]
}

# code deploy application
resource "aws_codedeploy_app" "codedeploy_app" {
  compute_platform = "Server"
  name             = var.codedeploy_appname
  depends_on       = [aws_instance.ec2]
}

# codedeploy deployment group
resource "aws_codedeploy_deployment_group" "example" {
  app_name               = aws_codedeploy_app.codedeploy_app.name
  deployment_group_name  = "csye6225-webapp-deployment"
  service_role_arn       = aws_iam_role.CodeDeployServiceRole.arn
  deployment_config_name = "CodeDeployDefault.AllAtOnce"
  deployment_style {
    deployment_type   = "IN_PLACE"
  }
  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = "csye6225_ec2"
    }
  }
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}

output "ec2_address" {
    value = aws_instance.ec2.*.public_ip
}

output "rds_endpoint" {
    value = aws_db_instance.rds.endpoint
}