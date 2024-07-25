provider "aws" {
  region = "ap-southeast-1"
}

#Creating my VPC

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "VPC-Lab"
  }
}

#Creating Internet gateway for the access point

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

#RouteTable configuration for my public subnet to have a path to internet, another route table for my nat gateway

resource "aws_route_table" "Public-routetable" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Main-routetable"
  }
}

resource "aws_route_table" "Natgateway-route" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.Natgateway-a.id
  }

  tags = {
    Name = "Private-natgateway-routetable"
  }
}


resource "aws_route_table" "s3-private-connection" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = "aws_vpc_endpoint.s3"
  }
}

#Creating 4 Subnets, 2 Private Subnets and 2 Public Subnets

resource "aws_subnet" "public-a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name = "public-subnet-a"
  }
}

resource "aws_subnet" "public-c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "ap-southeast-1c"

  tags = {
    Name = "public-subnet-c"
  }
}

resource "aws_subnet" "private-a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.100.0/24"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name = "private-subnet-a"
  }
}

resource "aws_subnet" "private-c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.200.0/24"
  availability_zone = "ap-southeast-1c"

  tags = {
    Name = "private-subnet-c"
  }
}

#Routetable association

resource "aws_route_table_association" "Public-a" {
  subnet_id      = aws_subnet.public-a.id
  route_table_id = aws_route_table.Public-routetable.id
}

resource "aws_route_table_association" "Public-c" {
  subnet_id      = aws_subnet.public-c.id
  route_table_id = aws_route_table.Public-routetable.id
}

resource "aws_route_table_association" "private-natgateway" {
  subnet_id      = aws_subnet.private-a.id
  route_table_id = aws_route_table.Natgateway-route.id
}

resource "aws_route_table_association" "private-s3-a" {
  subnet_id      = aws_subnet.private-a.id
  route_table_id = aws_route_table.s3-private-connection.id
}

resource "aws_route_table_association" "private-s3-c" {
  subnet_id      = aws_subnet.private-c.id
  route_table_id = aws_route_table.s3-private-connection.id
}

#Creation of EIP

resource "aws_eip" "one" {
  domain = "vpc"
}

#Creating Nat Gateway

resource "aws_nat_gateway" "Natgateway-a" {
  allocation_id = aws_eip.one.id
  subnet_id     = aws_subnet.public-a.id

  tags = {
    Name = "gw NAT"
  }
  depends_on = [aws_internet_gateway.gw]
}


#Creating a VPC endpoint so that my S3 can communicate with my private subnet within AWS without going to the internet

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.ap-southeast-1.s3"
  #Service name usually com.amazonaws.{region}.{service_name}
  vpc_endpoint_type = "Gateway"
}