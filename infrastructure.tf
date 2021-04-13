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

# load balancer security group
resource "aws_security_group" "lb_sg" {
  vpc_id      = aws_vpc.csye6225_vpc.id
  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "csye6225_lb_sg"
  }
}

# application security group
resource "aws_security_group" "application_sg" {
  vpc_id      = aws_vpc.csye6225_vpc.id

  ingress {
    protocol        = "tcp"
    from_port       = "8080"
    to_port         = "8080"
    security_groups = [aws_security_group.lb_sg.id]
  }
  ingress {
    protocol        = "tcp"
    from_port       = "443"
    to_port         = "443"
    security_groups = [aws_security_group.lb_sg.id]
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

# S3 bucket --------------------------------------------------------------------------
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

# KMS key for RDS
resource "aws_kms_key" "rds_kms_key" {
  description  = "rds_encryption"
}

resource "aws_kms_alias" "rds_kms_key_alias" {
  name          = "alias/rdsKey"
  target_key_id = aws_kms_key.rds_kms_key.key_id
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
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.rds_kms_key.arn
  ca_cert_identifier     = "rds-ca-2019"

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
        "codedeploy:*"
      ],
      "Resource": [
        "arn:aws:codedeploy:${var.region}:${data.aws_caller_identity.current.account_id}:application:${var.codedeploy_appname}",
        "arn:aws:codedeploy:${var.region}:${data.aws_caller_identity.current.account_id}:function:EmailNotification*"
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

# iam policy to allow gh to perform on cloud formation
resource "aws_iam_policy" "GH_Cloudformation_Lambda" {
  name   = "GH_Cloudformation_Lambda"
  policy = <<EOF
{
  "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Stmt1449904348000",
            "Effect": "Allow",
            "Action": [
                "cloudformation:*",
                "iam:*",
                "codedeploy:*",
                "lambda:*"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF
}

# attach GH_Cloudformation_Lambda policy to ghactions user
resource "aws_iam_user_policy_attachment" "gh_GH_Cloudformation_Lambda_attacher" {
  user       = var.ghactions_name
  policy_arn = aws_iam_policy.GH_Cloudformation_Lambda.arn
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

# EC2Role ---------------------------------------------------------------------------

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

# attach CloudWatchAgentServerPolicy for CodeDeployEC2ServiceRole
resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  role       = aws_iam_role.CodeDeployEC2ServiceRole.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
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

# Application Load Balancer -----------------------------------------------------------

# application load balancer
resource "aws_lb" "alb" {
  name               = "application-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id, aws_subnet.subnet3.id]
  security_groups    = [aws_security_group.lb_sg.id]
}

# alb target group
resource "aws_lb_target_group" "alb_target_group" {
  name                 = "alb-target-group"
  port                 = 8080
  protocol             = "HTTP"
  vpc_id               = aws_vpc.csye6225_vpc.id
  target_type          = "instance"

  health_check {
    path                = "/health/v1"
    protocol            = "HTTP"
    port                = 8080
    matcher             = "200"
    interval            = 10
    timeout             = 5
  }
}

data "aws_acm_certificate" "SSL_cert_comodo" {
  domain = var.route53_domain
  types    = ["IMPORTED"]
  statuses = ["ISSUED"]
}

# create listner for HTTPS
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = data.aws_acm_certificate.SSL_cert_comodo.arn
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_group.arn
  }
}

# EC2 configuration with Autoscaling ----------------------------------------------

# KMS key for EBS
resource "aws_kms_key" "ebs_kms_key" {
  description  = "rds_encryption"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Id": "key-consolepolicy-3",
  "Statement": [
    {
      "Sid": "Allow administration of the key",
      "Effect": "Allow",
      "Principal": {
          "AWS": "arn:aws:iam::597026635425:root"
      },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "Allow ServiceLinked Role CMK",
      "Effect": "Allow",
      "Principal": {
          "AWS": [
              "arn:aws:iam::597026635425:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
          ]
      },
      "Action": [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:Update*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Allow attachment of persistent resources",
      "Effect": "Allow",
      "Principal": {
          "AWS": [
              "arn:aws:iam::597026635425:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
          ]
      },
      "Action": [
          "kms:CreateGrant"
      ],
      "Resource": "*"
    }
  ]}
EOF
}

resource "aws_kms_alias" "ebs_kms_key_alias" {
  name          = "alias/ebsKey"
  target_key_id = aws_kms_key.ebs_kms_key.key_id
}

data "template_file" "output" {
  template = <<-EOF
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
}

resource "aws_launch_template" "asg_launch_template" {
  name                        = "asg_launch_template"
  image_id                    = var.ec2_ami
  instance_type               = var.ec2_instance_type
  key_name                    = var.ec2_key_name
  user_data = base64encode(data.template_file.output.rendered)
  
  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.application_sg.id]
  }

  iam_instance_profile {
    name  = aws_iam_instance_profile.ec2_profile.name
  }
  
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      kms_key_id     = aws_kms_key.ebs_kms_key.arn
      encrypted         = true
      volume_type           = var.ec2_volume_type
      volume_size           = var.ec2_volume_size
      delete_on_termination = var.ec2_ebs_delete_on_termination
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

# Autoscaling group
resource "aws_autoscaling_group" "asg" {
  name                 = "autoscaling_group"
  launch_template {
    id      = aws_launch_template.asg_launch_template.id
  }
  vpc_zone_identifier  = [aws_subnet.subnet1.id, aws_subnet.subnet2.id, aws_subnet.subnet3.id]
  target_group_arns    = [aws_lb_target_group.alb_target_group.arn]
  default_cooldown     = 30
  desired_capacity     = 3
  min_size             = 3
  max_size             = 5
  health_check_type    = "EC2"

  tag {
    key                 = "Name"
    value               = "csye6225_ec2"
    propagate_at_launch = true
  }
}

# scale up policy
resource "aws_autoscaling_policy" "autoscaling_scale_up" {
  name                   = "autoscaling_scale_up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 30
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

# scale down policy
resource "aws_autoscaling_policy" "autoscaling_scale_down" {
  name                   = "autoscaling_scale_down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 30
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

# cloudwatch scale up metric
resource "aws_cloudwatch_metric_alarm" "cpu_alarm_high" {
  alarm_name          = "cpu_alarm_high"
  alarm_description   = "Scale-up if CPU > 5% for 60 seconds"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  statistic           = "Average"
  period              = "60"
  evaluation_periods  = "2"
  threshold           = "5"
  comparison_operator = "GreaterThanThreshold"  
  alarm_actions       = [aws_autoscaling_policy.autoscaling_scale_up.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}

# cloudwatch scale down metric
resource "aws_cloudwatch_metric_alarm" "cpu_alarm_low" {
  alarm_name          = "cpu_alarm_low"
  alarm_description   = "Scale-down if CPU < 3% for 60 seconds"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  statistic           = "Average"
  period              = "60"
  evaluation_periods  = "2"
  threshold           = "3"
  comparison_operator = "LessThanThreshold"
  alarm_actions       = [aws_autoscaling_policy.autoscaling_scale_down.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}

# CodeDeploy app ------------------------------------------------------------------

# code deploy application
resource "aws_codedeploy_app" "codedeploy_app" {
  compute_platform = "Server"
  name             = var.codedeploy_appname
}

# codedeploy deployment group
resource "aws_codedeploy_deployment_group" "example" {
  app_name               = aws_codedeploy_app.codedeploy_app.name
  deployment_group_name  = "csye6225-webapp-deployment"
  service_role_arn       = aws_iam_role.CodeDeployServiceRole.arn
  deployment_config_name = "CodeDeployDefault.OneAtATime"
  autoscaling_groups = [aws_autoscaling_group.asg.name]

  deployment_style {
    deployment_type   = "IN_PLACE"
  }
  
  load_balancer_info {
    target_group_info {
      name = aws_lb_target_group.alb_target_group.name
    }
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

# Route 53 ----------------------------------------------------------------------------
data "aws_route53_zone" "primary" {
  name = var.route53_domain
}
 
# A Record for ec2
resource "aws_route53_record" "primary_A_record" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name = var.route53_domain
  type = "A"

  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

# SNS --------------------------------------------------------------------------------

resource "aws_sns_topic" "notification_email" {
  name         = "Notification_Email"
}

# grant ec2 access to SNS topic
resource "aws_iam_policy" "webapp_sns_policy" {
  name   = "webapp_sns_policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sns:*"
      ],
      "Resource": [
        "${aws_sns_topic.notification_email.arn}"
      ]
    }
  ]
}
EOF
}

# attach webapp_sns_policy to CodeDeployEC2ServiceRole
resource "aws_iam_role_policy_attachment" "ec2_role_webappSNS_attacher" {
  role       = aws_iam_role.CodeDeployEC2ServiceRole.name
  policy_arn = aws_iam_policy.webapp_sns_policy.arn
}

# DynamoDB ---------------------------------------------------------------------------

resource "aws_dynamodb_table" "dynamodb_table" {
  name           = "Emails_Sent"
  hash_key       = "id"
  read_capacity  = 5
  write_capacity = 5
  attribute {
    name = "id"
    type = "S"
  }
}

# Lambda IAM -------------------------------------------------------------------------

resource "aws_iam_role" "LambdaServiceRole" {
  name               = "LambdaServiceRole"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17", 
  "Statement": [
    {
      "Action": "sts:AssumeRole", 
      "Effect": "Allow", 
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ]
}
EOF
  tags = {
    "Name" = "csye6225_lambda_role"
  }
}

# grant lambda with basic execution
resource "aws_iam_policy_attachment" "aws_lambda_basic_execution" {
  name       = "lambda_basic_execution"
  roles      = [aws_iam_role.LambdaServiceRole.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# grant lambda access to sns
resource "aws_iam_policy_attachment" "aws_sns_lambda_policy" {
  name       = "sns_lambda_policy"
  roles      = [aws_iam_role.LambdaServiceRole.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

# grant lambda access to dynamodb
resource "aws_iam_policy_attachment" "aws_dynamodb_lambda_policy" {
  name       = "dynamodb_lambda_policy"
  roles      = [aws_iam_role.LambdaServiceRole.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# grant lambda access to ses
resource "aws_iam_policy_attachment" "aws_ses_lambda_policy" {
  name       = "ses_lambda_policy"
  roles      = [aws_iam_role.LambdaServiceRole.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSESFullAccess"
}

# Lambda -----------------------------------------------------------------------------

resource "aws_lambda_function" "lambda_function" {
  function_name = "EmailNotification"
  role          = aws_iam_role.LambdaServiceRole.arn
  s3_bucket     = var.codedeploy_bucket_name
  s3_key        = var.lambda_deployment_jar
  handler       = var.lambda_handler
  runtime       = "java11"
  timeout = 120
  memory_size = 256
  publish       = true
  
  environment {
    variables = {
      table_name = aws_dynamodb_table.dynamodb_table.id
      sender     = "no-reply@${var.route53_domain}"
    }
  }
}

resource "aws_lambda_alias" "lambda_alias" {
  name             = "EmailNotificationAlias"
  function_name    = aws_lambda_function.lambda_function.arn
  function_version = aws_lambda_function.lambda_function.version
  depends_on = [aws_lambda_function.lambda_function]
}

# lambda subscription to SNS
resource "aws_sns_topic_subscription" "lambda_subscription_sns" {
  protocol  = "lambda"
  topic_arn = aws_sns_topic.notification_email.arn
  endpoint  = var.lambda_arn
}

# lambda to be triggered from SNS
resource "aws_lambda_permission" "lambda_permission" {
  statement_id  = "AllowExecutionFromSNS"
  principal     = "sns.amazonaws.com"
  action        = "lambda:*"
  function_name = var.lambda_arn
  source_arn    = aws_sns_topic.notification_email.arn
}

# iam policy to allow gh to deploy app with ec2
resource "aws_iam_policy" "GH_Lambda_Deploy" {
  name   = "GH_Lambda_Deploy"
  policy = <<EOF
{
  "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Stmt1482712489000",
            "Effect": "Allow",
            "Action": [
                "lambda:CreateFunction",
                "lambda:InvokeAsync",
                "lambda:InvokeFunction",
                "lambda:UpdateAlias",
                "lambda:CreateAlias",
                "lambda:GetFunctionConfiguration",
                "lambda:AddPermission",
                "lambda:UpdateFunctionCode"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF
}

# attach GH_Upload_To_S3 policy to ghactions user
resource "aws_iam_user_policy_attachment" "gh_lambda_attacher" {
  user       = var.ghactions_name
  policy_arn = aws_iam_policy.GH_Lambda_Deploy.arn
}

# CodeDeploy app ------------------------------------------------------------------


# CodeDeployServiceRole
resource "aws_iam_role" "CodeDeployLambdaServiceRole" {
  name = "CodeDeployLambdaServiceRole"
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
    "Name" = "csye6225_codedeploy_lambda_role"
  }
}

# attach AWSCodeDeployRole policy to CodeDeployServiceRole
resource "aws_iam_role_policy_attachment" "CodeDeployLambdaServiceRole_attacher" {
  role       = aws_iam_role.CodeDeployLambdaServiceRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRoleForLambda"
}

# attach AWSCodeDeployRole policy to CodeDeployServiceRole
resource "aws_iam_role_policy_attachment" "CodeDeployLambdaServiceRole_S3_attacher" {
  role       = aws_iam_role.CodeDeployLambdaServiceRole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# code deploy application
resource "aws_codedeploy_app" "codedeploy_lambda" {
  compute_platform = "Lambda"
  name             = "EmailNotification"
}

# codedeploy deployment group
resource "aws_codedeploy_deployment_group" "lambda_deployment_group" {
  app_name               = aws_codedeploy_app.codedeploy_lambda.name
  deployment_group_name  = "csye6225-emailNotification-deployment"
  service_role_arn       = aws_iam_role.CodeDeployLambdaServiceRole.arn
  deployment_config_name = "CodeDeployDefault.LambdaAllAtOnce"

  deployment_style {
    deployment_type = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }
  
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}