terraform {
#  required_version = "~> 3.0"

required_providers {
  aws = {
    source = "hashicorp/aws"
    version = "~> 3.0"

  }
}
}

provider "aws" {
    region = "us-east-1"
}

resource "aws_instance" "instance_1" {
    #count = 2
    ami = "ami-011899242bb902164"
    instance_type = "t2.micro"
    security_groups = [aws_security_group.instances.name]
    user_data       = <<-EOF
              #!/bin/bash
              echo "Hello, World 2" > index.html
              python3 -m http.server 8080 &
              EOF
}

resource "aws_instance" "instance_2" {
    #count = 2
    ami = "ami-011899242bb902164"
    instance_type = "t2.micro"
    security_groups = [aws_security_group.instances.name]
    user_data       = <<-EOF
              #!/bin/bash
              echo "Hello, World 2" > index.html
              python3 -m http.server 8080 &
              EOF

}

#definir las subnets publicas y privadas

resource "aws_subnet" "private" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.2.0/24"
    availability_zone= "us-east-1a"
}

resource "aws_subnet" "public" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.1.0/24"
    availability_zone= "us-east-1a"
}


# Definir el load balancer

resource "aws_lb" "alb" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public.id]
  enable_deletion_protection = true
}

#Security group del alb


resource "aws_security_group" "alb" {
  name = "alb-security-group"
}

#Security Group Rule para el alb

resource "aws_security_group_rule" "allow_alb_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.alb.id

  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

}

#target group para el alb

resource "aws_lb_target_group" "albtg" {
  name     = "example-target-group"
  port     = 8080
  protocol = "HTTP"
  target_type = "instance"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

#attachar cada instancia al target group

resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = aws_lb_target_group.albtg.arn
  target_id        = aws_instance.instance_1.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "test2" {
  target_group_arn = aws_lb_target_group.albtg.arn
  target_id        = aws_instance.instance_2.id
  port             = 8080
}


#listener para al alb 

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"
  # ssl_policy        = "ELBSecurityPolicy-2016-08"
  # certificate_arn   = "arn:aws:iam::187416307283:server-certificate/test_cert_rab3wuqwgja25ct3n4jdj2tzu4"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.albtg.arn 
  }
}


#segun la documentacion hay que definir la salida porque terraform por default niega un allow all de salida

# resource "aws_security_group_rule" "allow_alb_all_outbound" {
#   type              = "egress"
#   security_group_id = aws_security_group.alb.id

#   from_port   = 0
#   to_port     = 0
#   protocol    = "-1"
#   cidr_blocks = ["0.0.0.0/0"]

# }

#Security Group para instances Ec2

resource "aws_security_group" "instances" {
  name = "instance-security-group"
}


resource "aws_security_group" "allow_8080" {
  name        = "allow_8080"
  description = "Allow tcp 8080 inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["10.0.2.0/24"]
    # cidr_blocks      = [aws_vpc.main.cidr_block]
    # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = ["::/0"]
  }

  # tags = {
  #   Name = "allow_tls"
  # }
}








# Bloques de data que hacen referencia a cosas que ya existen
# Se usan los default vpc y subnets

# data "aws_vpc" "default_vpc" {
#   default = true
# }

# data "aws_subnet_ids" "default_subnet" {
#   vpc_id = data.aws_vpc.default_vpc.id
# }

#Definir el VPC

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}