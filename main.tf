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

#Creating 4 Subnets, 2 Private Subnets and 2 Public Subnets, 2 more private subnets for my DB instances

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

resource "aws_subnet" "private-d" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.250.0/24"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name = "private-subnet-d"
  }
}

resource "aws_subnet" "private-e" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.255.0/24"
  availability_zone = "ap-southeast-1c"

  tags = {
    Name = "private-subnet-e"
  }
}

resource "aws_db_subnet_group" "subnet_group"{
  name  = "aws_db_cluster"
  description = "for my db cluster as we can't specify the subnets within the cluster and only the availability zones"
  subnet_ids = [aws_subnet.private-d.id, aws_subnet.private-e.id]
  
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

#Creating AWS instance for AMIs

resource "aws_instance" "Linux" {
  ami             = "ami-012c2e8e24e2ae21d"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public-a.id
  security_groups = [aws_security_group.allow_ssh.id]

  root_block_device {
    volume_size           = 8
    volume_type           = "gp2"
    delete_on_termination = true
  }

  user_data = <<EOF
                #!/bin/sh
                #Install a LAMP stack
                dnf install -y httpd wget php-fpm php-mysqli php-json php php-devel
                dnf install -y mariadb105-server
                dnf install -y httpd php-mbstring
                #Start the web server
                chkconfig httpd on
                systemctl start httpd
                #Install the web pages for our lab
                if [ ! -f /var/www/html/immersion-day-app-php7.zip ]; then
                  cd /var/www/html
                  wget -O 'immersion-day-app-php7.zip' 'https://static.us-east-1.prod.workshops.aws/public/05de623f-34ae-4f69-b11c-e8ec6086573d/assets/immersion-day-app-php7.zip'
                  unzip immersion-day-app-php7.zip
                fi
                #Install the AWS SDK for PHP
                if [ ! -f /var/www/html/aws.zip ]; then
                  cd /var/www/html
                  mkdir vendor
                  cd vendor
                  wget https://docs.aws.amazon.com/aws-sdk-php/v3/download/aws.zip
                  unzip aws.zip
                  fi
                # Update existing packages
                dnf update -y
                EOF

}

#Creating Security Group for my instances, load balancer

resource "aws_security_group" "allow_ssh" {
  name        = "allow_SSH"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_SSH_HTTP"
  }
}

resource "aws_security_group" "allow_HTTP" {
  name        = "allow_HTTP"
  description = "Allow HTTP inbound & outbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_HTTP"
  }
}
resource "aws_security_group" "allow_HTTP_from_ALB_only" {
  name        = "ASG-Web-Inst-SG"
  description = "Allow HTTP inbound traffic from ALB only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = aws_lb.Web-ALB.security_groups
    
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "ASG-Web-Inst-SG"
  }
}

resource "aws_security_group" "ec2-rds" {
  name = "EC2-RDS"
  description = "Security Group for my ec2 outbound"
  vpc_id      = aws_vpc.main.id

  egress{
    description  = "MYSQL/Aurora"
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "RDS-SG"
  description = "Allow inbound traffic from EC2 instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.ec2-rds.id]
  }
}

#associate with the RDS instances



#Creating AMIs for my instance

resource "aws_ami_from_instance" "web-server" {
  name               = "Webserver"
  source_instance_id = aws_instance.Linux.id
}

#WHERE Creating the target group for my load balancer - where the traffic will be headed to 

resource "aws_lb_target_group" "HTTP" {
  name     = "HTTP-Targetgroup"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "instance"
}



#SYSTEM Creating load balancer for my instances - a system to distribute the traffic 

resource "aws_lb" "Web-ALB" {
  name               = "Web-ALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_HTTP.id]
  subnets            = [aws_subnet.public-a.id, aws_subnet.public-c.id]

  enable_deletion_protection = true

  tags = {
    Name = "Web-ALB"
  }
}

#HOW Creating my listener for the load balancer - the system to listen to request and passing them on, determines how the traffic will go

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.Web-ALB.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn =  aws_lb_target_group.HTTP.arn
  }
  
}

#Creating my launch template for my auto scaling group

resource "aws_launch_template" "auto_scaling_template" {
  name = "web"
  description = "Immersion Day Web Instances Template - Web only"
  image_id = aws_ami_from_instance.web-server.id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_HTTP_from_ALB_only.id, aws_security_group.ec2-rds.id]
  }

#Creating my autoscaling group 

resource "aws_autoscaling_group" "Web-ASG" {
  desired_capacity   = 2
  max_size           = 4
  min_size           = 2
  target_group_arns = aws_lb_target_group.HTTP.load_balancer_arns
  vpc_zone_identifier = [aws_subnet.private-a.id, aws_subnet.private-c.id]

  launch_template {
    id      = aws_launch_template.auto_scaling_template.id
    version = "$Latest"
  }

  tag {
    key = "Name"
    value = "ASG-Web-Instance"
    propagate_at_launch = true
  }
}
#Creating my target tracking scaling policy - if my CPU exceeds 30% in target value, it will add instances, if it drops, it will decrease the number of instances.

resource "aws_autoscaling_policy" "ASG_Policy_30" {
  autoscaling_group_name = aws_autoscaling_group.Web-ASG.arn
  name = "Over_30"
  policy_type = "TargetTrackingScaling"

  target_tracking_configuration {
    target_value = 30
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}

#Here I will launch my RDS cluster 

resource "aws_rds_cluster" "rdscluster" {
  cluster_identifier      = "rdscluster"
  engine                  = "aurora-mysql"
  engine_version          = "5.7.mysql_aurora.2.11.4"
  availability_zones      = ["ap-southeast-1a"]
  database_name           = "immersionday"
  master_username         = "awsuser"
  master_password         = "awspassword"
  backup_retention_period = 5
  preferred_backup_window = "07:00-09:00"
  db_cluster_instance_class = "db.r5.large"
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name = aws_db_subnet_group.subnet_group.id
  
}

#Launching my read replica for high availability

resource "aws_db_instance" "read_replica" {
  identifier  = "aws-rds-read-replica"
  engine = "aurora"
  engine_version = "5.7.mysql_aurora.2.11.4"
  availability_zone = "ap-southeast-1c"
  multi_az = false
  instance_class = "db.r5.large"
  publicly_accessible   = false
  auto_minor_version_upgrade = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  replicate_source_db = "rdscluster"
}
