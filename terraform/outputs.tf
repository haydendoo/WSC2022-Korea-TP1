output "team_role_arn" {
  description = "ARN of TeamRole - attach this to your Lambda function as its execution role, per the spec's Gentle reminder #4."
  value       = aws_iam_role.team_role.arn
}

output "ec2_role_arn" {
  description = "ARN of EC2Role, behind the ec2-prole instance profile."
  value       = aws_iam_role.ec2_role.arn
}

output "ec2_instance_profile_name" {
  description = "Name of the instance profile to attach to your EC2 instance, per the spec's Gentle reminder #5 (\"attach EC2Role as ec2-prole for your EC2 instance\")."
  value       = aws_iam_instance_profile.ec2_role.name
}
