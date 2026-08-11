variable "aws_region" {
  description = "AWS region to deploy the baseline environment into."
  type        = string
  default     = "ap-southeast-1"
}

variable "name_prefix" {
  description = "Prefix applied to the names of all resources created by this baseline module."
  type        = string
  default     = "unicorn-gameday-day1"
}

variable "tags" {
  description = "Additional tags merged into every resource created by this module."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# IAM (see iam.tf)
# ---------------------------------------------------------------------------

variable "unicorn_resource_name_pattern" {
  description = <<-EOT
    Naming pattern (with a trailing "*") used to scope TeamRole's S3
    access to the bucket you create for your IoT certificates/keys,
    without granting access to every bucket in the account. Name your
    actual bucket to match this pattern (default matches the "unicorn-*"
    style names used across the WSC2022 TP53 example configs).
  EOT
  type        = string
  default     = "unicorn-*"
}

variable "team_role_extra_managed_policy_arns" {
  description = <<-EOT
    Additional AWS-managed or customer-managed policy ARNs to attach to
    TeamRole (the Lambda execution role), on top of the baseline
    AWSLambdaBasicExecutionRole + team_role_baseline policies this module
    always attaches.
  EOT
  type        = list(string)
  default     = []
}

variable "ec2_role_extra_managed_policy_arns" {
  description = <<-EOT
    Additional AWS-managed or customer-managed policy ARNs to attach to
    EC2Role (behind the "ec2-prole" instance profile), on top of the
    baseline SSM + ec2_role_baseline policies this module always attaches.
  EOT
  type        = list(string)
  default     = []
}
