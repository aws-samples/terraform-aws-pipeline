// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

variable "pipeline_name" {
  type = string
}

variable "repo" {
  description = "source repo name"
  type        = string
}

// optional

variable "access_logging_bucket" {
  description = "s3 server access logging bucket arn"
  type        = string
  default     = null
}

variable "artifact_retention" {
  description = "s3 artifact bucket retention, in days"
  type        = number
  default     = 90
}

variable "branch" {
  description = "branch to source"
  type        = string
  default     = "main"
}

variable "build_timeout" {
  description = "CodeBuild project build timeout"
  type        = number
  default     = 10
}

variable "build_override" {
  description = "Override CodeBuild images and buildspecs"
  type = object({
    plan_buildspec  = optional(string)
    plan_image      = optional(string)
    apply_buildspec = optional(string)
    apply_image     = optional(string)
  })
  default = {}
}

variable "checkov_skip" {
  description = "list of checkov checks to skip"
  type        = list(string)
  default     = [""]
}

variable "checkov_version" {
  type    = string
  default = "3.2.0"
  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+$", var.checkov_version))
    error_message = "checkov version must use format x.y.z"
  }
}

variable "codebuild_policy" {
  description = "replaces CodeBuild's AWSAdministratorAccess IAM policy"
  type        = string
  default     = null
}

variable "connection" {
  description = "arn of the CodeConnection"
  type        = string
  default     = null
}

variable "detect_changes" {
  description = "allows third-party servicesm like GitHub to invoke the pipeline"
  type        = bool
  default     = false
}

variable "kms_key" {
  description = "AWS KMS key ARN"
  type        = string
  default     = null
}

variable "log_retention" {
  description = "CloudWatch log group retention, in days"
  type        = number
  default     = 90
}

variable "mode" {
  description = "pipeline execution mode"
  type        = string
  default     = "SUPERSEDED"
  validation {
    condition = contains([
      "SUPERSEDED",
      "PARALLEL",
      "QUEUED"
    ], var.mode)
    error_message = "unsupported pipeline mode"
  }
}

variable "notifications" {
  description = "SNS notification configuration"
  type = object({
    sns_topic   = string
    events      = list(string)
    detail_type = string
  })
  default = null
}

variable "tags" {
  description = "tags to check for"
  type        = string
  default     = ""
}

variable "tagnag_version" {
  type    = string
  default = "0.7.9"
  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+$", var.tagnag_version))
    error_message = "tagnag version must use format x.y.z"
  }
}

variable "terraform_directory" {
  type    = string
  default = "."
}

variable "terraform_version" {
  type    = string
  default = "1.8.0"
  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+$", var.terraform_version))
    error_message = "terraform version must use format x.y.z"
  }
}

variable "tflint_version" {
  type    = string
  default = "0.55.0"
  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+$", var.tflint_version))
    error_message = "tflint version must use format x.y.z"
  }
}

variable "vpc" {
  type = object({
    vpc_id             = string
    subnets            = list(string)
    security_group_ids = list(string)
  })
  default = null
}
