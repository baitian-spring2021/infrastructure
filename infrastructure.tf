provider "aws" {
  region = "us-east-1"
}

# create vpc
resource "aws_vpc" "csye2665_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "csye6225_vpc"
  }
}

# subnet 1
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.csye2665_vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1d"
  map_public_ip_on_launch = true
  tags = {
    Name = "csye6225_subnet1"
  }
}

# subnet 2
resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.csye2665_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1e"
  map_public_ip_on_launch = true
  tags = {
    Name = "csye6225_subnet2"
  }
}

# subnet 3
resource "aws_subnet" "subnet3" {
  vpc_id                  = aws_vpc.csye2665_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1f"
  map_public_ip_on_launch = true
  tags = {
    Name = "csye6225_subnet3"
  }
}

# create internet gateway, attach to VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.csye2665_vpc.id
  tags = {
    Name = "csye6225_igw"
  }
}

# create public route table
resource "aws_route_table" "routeTable" {
  vpc_id = aws_vpc.csye2665_vpc.id
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

