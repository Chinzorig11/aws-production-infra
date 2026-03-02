/**
 * # Monitoring Module
 *
 * CloudWatch alarms, dashboards, composite alarms, and SNS alerting.
 */

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts-${var.environment}"
  kms_master_key_id = var.kms_key_id != "" ? var.kms_key_id : null
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# --- EC2 CPU ---
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-cpu-high-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_threshold
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions          = { AutoScalingGroupName = var.asg_name }
  tags                = { Name = "${var.project_name}-cpu-high-${var.environment}" }
}

# --- RDS Storage ---
resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  count               = var.rds_instance_id != "" ? 1 : 0
  alarm_name          = "${var.project_name}-rds-storage-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_storage_threshold_bytes
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions          = { DBInstanceIdentifier = var.rds_instance_id }
}

# --- RDS CPU ---
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  count               = var.rds_instance_id != "" ? 1 : 0
  alarm_name          = "${var.project_name}-rds-cpu-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions          = { DBInstanceIdentifier = var.rds_instance_id }
}

# --- ALB 5xx ---
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  count               = var.alb_arn_suffix != "" ? 1 : 0
  alarm_name          = "${var.project_name}-alb-5xx-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb_5xx_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
}

# --- ALB Latency ---
resource "aws_cloudwatch_metric_alarm" "alb_latency" {
  count               = var.alb_arn_suffix != "" ? 1 : 0
  alarm_name          = "${var.project_name}-alb-latency-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "p95"  # Senior: p95 instead of Average
  threshold           = var.latency_threshold_seconds
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
}

# --- Senior: Composite Alarm (multiple conditions) ---
resource "aws_cloudwatch_composite_alarm" "critical" {
  count             = var.alb_arn_suffix != "" ? 1 : 0
  alarm_name        = "${var.project_name}-CRITICAL-${var.environment}"
  alarm_description = "Critical: Multiple infrastructure issues detected"

  alarm_rule = "ALARM(\"${aws_cloudwatch_metric_alarm.cpu_high.alarm_name}\") AND ALARM(\"${aws_cloudwatch_metric_alarm.alb_5xx[0].alarm_name}\")"

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# --- Dashboard ---
resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "${var.project_name}-${var.environment}"
  dashboard_body = jsonencode({
    widgets = [
      { type = "metric", x = 0, y = 0, width = 12, height = 6,
        properties = { title = "EC2 CPU", metrics = [["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.asg_name]], period = 300, stat = "Average", region = var.region } },
      { type = "metric", x = 12, y = 0, width = 12, height = 6,
        properties = { title = "ALB Requests", metrics = var.alb_arn_suffix != "" ? [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix]] : [], period = 300, stat = "Sum", region = var.region } },
      { type = "metric", x = 0, y = 6, width = 12, height = 6,
        properties = { title = "ALB Response Time (p95)", metrics = var.alb_arn_suffix != "" ? [["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix]] : [], period = 300, stat = "p95", region = var.region } },
      { type = "metric", x = 12, y = 6, width = 12, height = 6,
        properties = { title = "RDS CPU & Connections", metrics = var.rds_instance_id != "" ? [["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instance_id], ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.rds_instance_id]] : [], period = 300, region = var.region } },
    ]
  })
}
