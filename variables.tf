variable "region" {
  default     = "us-east-1"
}

variable "a_zone" {
  default     = ["a", "b", "c"]
}

variable "cidr_vpc" {
  default     = "10.0.0.0/16"
}

variable "cidr_subnet" {
  default     = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
}