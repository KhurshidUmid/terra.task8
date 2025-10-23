# Define local names for resources based on the project variable
locals {
  template_name         = "${var.project_name}-template"
  asg_name              = "${var.project_name}-asg"
  lb_name               = "${var.project_name}-loadbalancer"
  tg_name               = "${var.project_name}-tg"
  instance_profile_name = "${var.project_name}-instance_profile"
}

# --- Data Sources to fetch pre-existing resources ---

data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-vpc"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  # Filter by the exact CIDRs provided in the prerequisites
  filter {
    name   = "cidr-block"
    values = ["10.0.1.0/24", "10.0.3.0/24"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  # Filter by the exact CIDRs provided in the prerequisites
  filter {
    name   = "cidr-block"
    values = ["10.0.2.0/24", "10.0.4.0/24"]
  }
}

data "aws_security_group" "ec2_sg" {
  filter {
    name   = "group-name"
    values = ["${var.project_name}-ec2_sg"]
  }
}

data "aws_security_group" "http_sg" {
  filter {
    name   = "group-name"
    values = ["${var.project_name}-http_sg"]
  }
}

data "aws_security_group" "sglb" {
  filter {
    name   = "group-name"
    values = ["${var.project_name}-sglb"]
  }
}

data "aws_iam_instance_profile" "main" {
  name = local.instance_profile_name
}

# --- Resource: AWS Launch Template ---

resource "aws_launch_template" "main" {
  name          = local.template_name
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.ssh_key_name

  vpc_security_group_ids = [
    data.aws_security_group.ec2_sg.id,
    data.aws_security_group.http_sg.id
  ]

  iam_instance_profile {
    name = data.aws_iam_instance_profile.main.name
  }

  #  network_interfaces {
  #    delete_on_termination = true
  #  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional" # As specified in the lab description
  }

  user_data = filebase64("${path.module}/user_data.sh")

  tags = var.common_tags
}

# --- Resource: ALB Target Group ---

resource "aws_lb_target_group" "main" {
  name     = local.tg_name
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = var.common_tags
}

# --- Resource: Application Load Balancer (ALB) ---

resource "aws_lb" "main" {
  name               = local.lb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [data.aws_security_group.sglb.id]
  subnets            = data.aws_subnets.public.ids

  tags = var.common_tags
}

# --- Resource: ALB Listener ---

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# --- Resource: Auto Scaling Group (ASG) ---

resource "aws_autoscaling_group" "main" {
  name                = local.asg_name
  desired_capacity    = 2
  min_size            = 1
  max_size            = 2
  vpc_zone_identifier = data.aws_subnets.private.ids

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  # Add lifecycle block as required
  lifecycle {
    ignore_changes = [load_balancers, target_group_arns]
  }

  # Tags for the ASG resource itself
  #tags = var.common_tags

  # Tags to be propagated to instances launched by this ASG
  tag {
    key                 = "Name"
    value               = "${var.project_name}-instance"
    propagate_at_launch = true
  }
  tag {
    key                 = "Terraform"
    value               = var.common_tags.Terraform
    propagate_at_launch = true
  }
  tag {
    key                 = "Project"
    value               = var.common_tags.Project
    propagate_at_launch = true
  }
}

# --- Resource: ASG Attachment ---

resource "aws_autoscaling_attachment" "main" {
  autoscaling_group_name = aws_autoscaling_group.main.name
  lb_target_group_arn    = aws_lb_target_group.main.arn
}
