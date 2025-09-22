// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

module "validation" {
  for_each              = var.tags == "" ? local.validation_stages : local.conditional_validation_stages
  source                = "./modules/codebuild"
  codebuild_name        = "${var.pipeline_name}-${each.key}"
  codebuild_role        = aws_iam_role.codebuild_validate.arn
  environment_variables = var.tags == "" ? local.env_var : local.conditional_env_var
  build_timeout         = var.build_timeout
  build_spec            = file("${path.module}/modules/codebuild/buildspecs/${each.key}.yml")
  log_group             = aws_cloudwatch_log_group.this.name
  image                 = each.value
  vpc                   = var.vpc
}

module "plan" {
  source                = "./modules/codebuild"
  codebuild_name        = "${var.pipeline_name}-plan"
  codebuild_role        = aws_iam_role.codebuild_execution.arn
  environment_variables = local.env_var
  build_timeout         = var.build_timeout
  build_spec            = var.build_override["plan_buildspec"] != null ? var.build_override["plan_buildspec"] : file("${path.module}/modules/codebuild/buildspecs/plan.yml")
  log_group             = aws_cloudwatch_log_group.this.name
  image                 = var.build_override["plan_image"] != null ? var.build_override["plan_image"] : "hashicorp/terraform:${var.terraform_version}"
  vpc                   = var.vpc
}

module "apply" {
  source                = "./modules/codebuild"
  codebuild_name        = "${var.pipeline_name}-apply"
  codebuild_role        = aws_iam_role.codebuild_execution.arn
  environment_variables = local.env_var
  build_timeout         = var.build_timeout
  build_spec            = var.build_override["apply_buildspec"] != null ? var.build_override["apply_buildspec"] : file("${path.module}/modules/codebuild/buildspecs/apply.yml")
  log_group             = aws_cloudwatch_log_group.this.name
  image                 = var.build_override["apply_image"] != null ? var.build_override["apply_image"] : "hashicorp/terraform:${var.terraform_version}"
  vpc                   = var.vpc
}

resource "aws_iam_role" "codebuild_validate" {
  name               = "${var.pipeline_name}-codebuild-validate"
  assume_role_policy = data.aws_iam_policy_document.codebuild_validate_assume.json
}

resource "aws_iam_role" "codebuild_execution" {
  name               = "${var.pipeline_name}-codebuild-execution"
  assume_role_policy = data.aws_iam_policy_document.codebuild_execution_assume.json
}

data "aws_iam_policy_document" "codebuild_validate_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:codebuild:${local.region}:${data.aws_caller_identity.current.account_id}:project/${var.pipeline_name}-*"
      ]
    }
  }
}

data "aws_iam_policy_document" "codebuild_execution_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:codebuild:${local.region}:${data.aws_caller_identity.current.account_id}:project/${var.pipeline_name}-plan",
        "arn:aws:codebuild:${local.region}:${data.aws_caller_identity.current.account_id}:project/${var.pipeline_name}-apply"
      ]
    }
  }
}

resource "aws_iam_role_policy_attachment" "codebuild_validate" {
  role       = aws_iam_role.codebuild_validate.name
  policy_arn = aws_iam_policy.codebuild_validate.arn
}

resource "aws_iam_role_policy_attachment" "codebuild_execution" {
  role       = aws_iam_role.codebuild_execution.name
  policy_arn = var.codebuild_policy == null ? "arn:aws:iam::aws:policy/AdministratorAccess" : var.codebuild_policy
}

resource "aws_iam_policy" "codebuild_validate" {
  name   = "${var.pipeline_name}-codebuild-validate"
  policy = data.aws_iam_policy_document.codebuild.json
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${local.region}:${data.aws_caller_identity.current.account_id}:log-group:*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "codebuild:CreateReport",
      "codebuild:UpdateReport",
      "codebuild:BatchPutTestCases"
    ]
    resources = [
      aws_codebuild_report_group.sast.arn
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = [
      "${aws_s3_bucket.this.arn}/*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:GenerateDataKey*",
      "kms:Decrypt"
    ]

    resources = [
      "*"
    ]
  }

  // https://docs.aws.amazon.com/codebuild/latest/userguide/auth-and-access-control-iam-identity-based-access-control.html#customer-managed-policies-example-create-vpc-network-interface
  dynamic "statement" {
    for_each = var.vpc == null ? [] : [var.vpc]
    content {
      effect = "Allow"
      actions = [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVpcs"
      ]
      resources = [
        "*"
      ]
    }
  }

  dynamic "statement" {
    for_each = var.vpc == null ? [] : [var.vpc]
    content {
      effect = "Allow"
      actions = [
        "ec2:CreateNetworkInterfacePermission"

      ]
      resources = [
        "arn:aws:ec2:${local.region}:${data.aws_caller_identity.current.account_id}:network-interface/*"
      ]
      condition {
        test     = "StringEquals"
        variable = "ec2:AuthorizedService"
        values = [
          "codebuild.amazonaws.com"
        ]
      }
      condition {
        test     = "ArnEquals"
        variable = "ec2:Subnet"
        values = [
          for id in var.vpc["subnets"] :
          "arn:aws:ec2:${local.region}:${data.aws_caller_identity.current.account_id}:subnet/${id}"
        ]
      }
    }
  }
}

resource "aws_codebuild_report_group" "sast" {
  name           = "sast-report-${var.pipeline_name}"
  type           = "TEST"
  delete_reports = true

  export_config {
    type = "S3"

    s3_destination {
      bucket              = aws_s3_bucket.this.id
      encryption_disabled = false
      encryption_key      = var.kms_key == null ? data.aws_kms_key.s3.arn : var.kms_key
      packaging           = "NONE"
      path                = "/sast"
    }
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/codebuild/${var.pipeline_name}"
  retention_in_days = var.log_retention
  kms_key_id        = var.kms_key
}
