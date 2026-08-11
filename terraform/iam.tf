# IAM baseline: recreates what the spec says already exists before the
# competition starts (see "Gentle reminder" #4-5):
#
#   4. "Please attach TeamRole to your lambda function as the execution
#      role."
#   5. "Please attach EC2Role as ec2-prole for your EC2 instance."
#
# Both roles are scoped, documented permission sets - not
# AdministratorAccess - sized to build the Day 1 solution (IoT Core -> S3
# -> Lambda -> Comprehend -> DynamoDB -> EC2 web service) without needing
# to create additional IAM users/roles, per the spec's Background section
# ("you can use any existing IAM user or role to handle the challenges...
# please don't create any other IAM user/role from IAM console").

# ---------------------------------------------------------------------------
# TeamRole - Lambda execution role (Gentle reminder #4)
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "team_role_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "team_role" {
  name               = "TeamRole"
  description        = "Lambda execution role for the Day 1 sentiment-analysis pipeline (attach to your Lambda function per the spec's Gentle reminder #4)"
  assume_role_policy = data.aws_iam_policy_document.team_role_trust.json
}

# Standard CloudWatch Logs permissions every Lambda function needs.
resource "aws_iam_role_policy_attachment" "team_role_basic_execution" {
  role       = aws_iam_role.team_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Scoped to what the Day 1 pipeline needs per the spec's Re-platform
# schedule Phase II ("Detect the sentiment from the messages, store the
# analytic result to NoSql database... DynamoDB, Lambda, Comprehend") and
# the Database section (table name fixed to "unicorn").
data "aws_iam_policy_document" "team_role_baseline" {
  statement {
    sid    = "ComprehendSentiment"
    effect = "Allow"
    actions = [
      "comprehend:DetectSentiment",
      "comprehend:BatchDetectSentiment",
    ]
    resources = ["*"] # Comprehend does not support resource-level permissions for detection APIs.
  }

  statement {
    sid    = "UnicornTableWrite"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:DescribeTable",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/unicorn",
      "arn:${data.aws_partition.current.partition}:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/unicorn/index/*",
    ]
  }

  statement {
    sid    = "CertBucketRead"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.unicorn_resource_name_pattern}",
      "arn:${data.aws_partition.current.partition}:s3:::${var.unicorn_resource_name_pattern}/*",
    ]
  }
}

resource "aws_iam_policy" "team_role_baseline" {
  name        = "TeamRoleDay1Policy"
  description = "Documented, non-admin permission set for TeamRole (Lambda execution role) - see terraform/iam.tf"
  policy      = data.aws_iam_policy_document.team_role_baseline.json
}

resource "aws_iam_role_policy_attachment" "team_role_baseline" {
  role       = aws_iam_role.team_role.name
  policy_arn = aws_iam_policy.team_role_baseline.arn
}

resource "aws_iam_role_policy_attachment" "team_role_extra" {
  for_each = toset(var.team_role_extra_managed_policy_arns)

  role       = aws_iam_role.team_role.name
  policy_arn = each.value
}

# ---------------------------------------------------------------------------
# EC2Role / "ec2-prole" instance profile (Gentle reminder #5)
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_role_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "EC2Role"
  description        = "Web-tier EC2 role for the Day 1 server-stub deployment (attach the ec2-prole instance profile per the spec's Gentle reminder #5)"
  assume_role_policy = data.aws_iam_policy_document.ec2_role_trust.json
}

# SSM Session Manager access - keeps with the "no SSH from the internet"
# posture used across the other WSC2022 TP53 days, and gives judges/admins
# a way onto the instance without a key pair.
resource "aws_iam_role_policy_attachment" "ec2_role_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch Agent - supports the spec's "monitor the traffic closely...
# through the Amazon Web Services Console with CloudWatch" instruction
# (Technical Details / Tasks #8).
resource "aws_iam_role_policy_attachment" "ec2_role_cloudwatch_agent" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Read-only access to the "unicorn" DynamoDB table - the server-stub
# binary only ever reads (GET /unicorn/{id}), it never writes.
data "aws_iam_policy_document" "ec2_role_baseline" {
  statement {
    sid    = "UnicornTableRead"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:DescribeTable",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/unicorn",
      "arn:${data.aws_partition.current.partition}:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/unicorn/index/*",
    ]
  }
}

resource "aws_iam_policy" "ec2_role_baseline" {
  name        = "EC2RoleDay1Policy"
  description = "Documented, non-admin permission set for EC2Role (web-tier instance profile) - see terraform/iam.tf"
  policy      = data.aws_iam_policy_document.ec2_role_baseline.json
}

resource "aws_iam_role_policy_attachment" "ec2_role_baseline" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_role_baseline.arn
}

resource "aws_iam_role_policy_attachment" "ec2_role_extra" {
  for_each = toset(var.ec2_role_extra_managed_policy_arns)

  role       = aws_iam_role.ec2_role.name
  policy_arn = each.value
}

# Literal name "ec2-prole" per the spec's exact wording in Gentle reminder
# #5 (most likely a typo for "ec2-profile" in the original document, but
# reproduced verbatim since it's the literal instance-profile name the
# spec instructs participants to attach).
resource "aws_iam_instance_profile" "ec2_role" {
  name = "ec2-prole"
  role = aws_iam_role.ec2_role.name
}
