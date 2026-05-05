/**
 * # Compute Module
 *
 * EC2 instances with Auto Scaling, mixed instance types,
 * SSM access (no SSH keys), and CloudWatch agent.
 */

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- Security Group ---
resource "aws_security_group" "ec2" {
  name_prefix = "${var.project_name}-ec2-"
  description = "Security group for EC2 instances"
  vpc_id      = var.vpc_id

  ingress {
    description     = "App traffic from ALB"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = var.alb_security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2-sg-${var.environment}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --- Launch Template ---
resource "aws_launch_template" "this" {
  name_prefix   = "${var.project_name}-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  vpc_security_group_ids = [aws_security_group.ec2.id]

  # Senior: IMDSv2 required (security best practice)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Enforce IMDSv2
    http_put_response_hop_limit = 1
  }

  # Senior: EBS encryption by default
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = true # Detailed monitoring
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    project_name = var.project_name
    environment  = var.environment
    app_port     = var.app_port
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-${var.environment}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# --- Auto Scaling Group ---
resource "aws_autoscaling_group" "this" {
  name_prefix               = "${var.project_name}-${var.environment}-"
  desired_capacity          = var.desired_size
  min_size                  = var.min_size
  max_size                  = var.max_size
  vpc_zone_identifier       = var.public_subnets
  target_group_arns         = var.target_group_arns
  health_check_type         = "ELB"
  health_check_grace_period = 300

  # Senior: Instance refresh for zero-downtime deployments
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 120
    }
  }

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  # Senior: Warm pool for faster scaling
  dynamic "warm_pool" {
    for_each = var.enable_warm_pool ? [1] : []
    content {
      pool_state                  = "Stopped"
      min_size                    = 1
      max_group_prepared_capacity = var.max_size
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-${var.environment}"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity] # Don't override auto-scaling decisions
  }
}

# --- Target Tracking Scaling (Senior: better than step scaling) ---
resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${var.project_name}-cpu-target-${var.environment}"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value     = var.cpu_target_value
    disable_scale_in = false
  }
}

resource "aws_autoscaling_policy" "request_target" {
  count                  = var.enable_request_scaling ? 1 : 0
  name                   = "${var.project_name}-request-target-${var.environment}"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = var.alb_resource_label
    }
    target_value = var.request_target_value
  }
}

# --- IAM Role ---
resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-ec2-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Senior: Scoped S3 access for logs only
resource "aws_iam_role_policy" "s3_logs" {
  count = var.log_bucket_arn != "" ? 1 : 0
  name  = "${var.project_name}-s3-logs"
  role  = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:GetObject"]
      Resource = ["${var.log_bucket_arn}/*"]
    }]
  })
}

# Senior: Secrets Manager access (scoped to project)
resource "aws_iam_role_policy" "secrets" {
  count = var.secrets_arn != "" ? 1 : 0
  name  = "${var.project_name}-secrets"
  role  = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.secrets_arn]
    }]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile-${var.environment}"
  role = aws_iam_role.ec2.name
}
