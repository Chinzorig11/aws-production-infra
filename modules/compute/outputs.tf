output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.this.name
}

output "security_group_id" {
  description = "EC2 security group ID"
  value       = aws_security_group.ec2.id
}

output "iam_role_arn" {
  description = "EC2 IAM role ARN"
  value       = aws_iam_role.ec2.arn
}

output "launch_template_id" {
  description = "Launch template ID"
  value       = aws_launch_template.this.id
}
