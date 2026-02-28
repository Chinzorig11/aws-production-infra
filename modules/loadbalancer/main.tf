/**
 * # Load Balancer Module
 *
 * ALB with WAF integration, SSL-ready, and access logging.
 */

resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  description = "ALB security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-alb-sg-${var.environment}" }

  lifecycle { create_before_destroy = true }
}

resource "aws_lb" "this" {
  name               = "${var.project_name}-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.environment == "prod"

  # Senior: Access logs to S3
  dynamic "access_logs" {
    for_each = var.access_log_bucket != "" ? [1] : []
    content {
      bucket  = var.access_log_bucket
      prefix  = "alb/${var.project_name}-${var.environment}"
      enabled = true
    }
  }

  tags = { Name = "${var.project_name}-alb-${var.environment}" }
}

resource "aws_lb_target_group" "this" {
  name     = "${var.project_name}-${var.environment}"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  # Senior: Slow start for new instances
  slow_start = var.environment == "prod" ? 60 : 0

  stickiness {
    type    = "lb_cookie"
    enabled = var.enable_stickiness
  }

  tags = { Name = "${var.project_name}-tg-${var.environment}" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# --- Senior: WAF Web ACL ---
resource "aws_wafv2_web_acl" "this" {
  count       = var.enable_waf ? 1 : 0
  name        = "${var.project_name}-waf-${var.environment}"
  description = "WAF for ${var.project_name}"
  scope       = "REGIONAL"

  default_action { allow {} }

  # Rate limiting
  rule {
    name     = "rate-limit"
    priority = 1
    action { block {} }
    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-rate-limit"
    }
  }

  # AWS Managed Rules - Common
  rule {
    name     = "aws-managed-common"
    priority = 2
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-common-rules"
    }
  }

  # AWS Managed Rules - SQL Injection
  rule {
    name     = "aws-managed-sqli"
    priority = 3
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-sqli-rules"
    }
  }

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf"
  }

  tags = { Name = "${var.project_name}-waf-${var.environment}" }
}

resource "aws_wafv2_web_acl_association" "this" {
  count        = var.enable_waf ? 1 : 0
  resource_arn = aws_lb.this.arn
  web_acl_arn  = aws_wafv2_web_acl.this[0].arn
}
