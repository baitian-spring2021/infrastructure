variable "region" {
  default     = "us-east-1"
}


variable "a_zone" {
  default     = ["d", "e", "f"]
}

variable "cidr_vpc" {
  default     = "10.0.0.0/16"
}

variable "cidr_subnet" {
  default     = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
}

variable "bucket_name" {
  default     = "webapp.tianyu.bai"
}

variable "db_allocated_storage" {
  type        = number
  default     = 20
}

variable "db_engine" {
  default     = "mysql"
}

variable "db_instance_class" {
  default     = "db.t3.micro"
}

variable "db_multi_az" {
  type        = bool
  default     = false
}

variable "db_identifier" {
  default     = "csye6225"
}

variable "db_username" {
  default     = "csye6225"
}

variable "db_password" {
  default     = "12345aA."
}

variable "db_publicly_accessible" {
  type        = bool
  default     = false
}

variable "db_name" {
  default     = "csye6225"
}

variable "ec2_role_name" {
  default     = "EC2-CSYE6225"
}

variable "webapp_s3_policy" {
  default     = "WebAppS3"
}

variable "ec2_ami" {
  default     = "ami-0ceb8ae23e7491730"
}

variable "ec2_instance_type" {
  default     = "t2.micro"
}

variable "ec2_key_name" {
  default     = "csye6225"
}

variable "ec2_disable_api_termination" {
  type        = bool
  default     = false
}

variable "ec2_volume_type" {
  type        = string
  default     = "gp2"
}

variable "ec2_volume_size" {
  type        = number
  default     = 20
}

variable "ec2_ebs_delete_on_termination" {
  type        = bool
  default     = true
}