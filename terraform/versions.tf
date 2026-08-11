# Baseline environment generator for WSC2022 TP53 Day 1 (IoT + AI + Web service).
#
# This module answers "what did the participant receive when the
# competition started?" - it provisions ONLY the pre-existing IAM
# baseline the spec's "Gentle reminder" section references (TeamRole for
# the Lambda execution role, EC2Role/"ec2-prole" instance profile for the
# EC2 instance). It intentionally does NOT provision IoT Core resources,
# S3 buckets, Lambda functions, DynamoDB tables, or EC2 instances - those
# are the participant's Day 1 solution (Phases I-III of the re-platform
# schedule).

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
