// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

resource "aws_cloudwatch_event_rule" "this" {
  name        = var.pipeline_name
  description = "Invokes pipeline when there is a new CodeCommit repo commit"
  event_pattern = jsonencode({

    "source" : [
      "aws.codecommit"
    ],
    "detail-type" : [
      "CodeCommit Repository State Change"
    ],
    "resources" : [
      "arn:aws:codecommit:${local.region}:${data.aws_caller_identity.current.account_id}:${var.repo}"
    ],
    "detail" : {
      "event" : [
        "referenceCreated",
        "referenceUpdated"
      ],
      "referenceType" : [
        "branch"
      ],
      "referenceName" : [
        "${var.branch}",
      ]
    }

  })
}

resource "aws_cloudwatch_event_target" "this" {
  rule      = aws_cloudwatch_event_rule.this.name
  target_id = var.pipeline_name
  arn       = aws_codepipeline.this.arn
  role_arn  = aws_iam_role.eventbridge.arn
}

resource "aws_iam_role" "eventbridge" {
  name               = "${var.pipeline_name}-eventbridge"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume.json
}

data "aws_iam_policy_document" "eventbridge_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values = [
        data.aws_caller_identity.current.account_id
      ]
    }
  }
}

resource "aws_iam_role_policy_attachment" "eventbridge" {
  role       = aws_iam_role.eventbridge.name
  policy_arn = aws_iam_policy.eventbridge.arn
}

resource "aws_iam_policy" "eventbridge" {
  name   = "${var.pipeline_name}-eventbridge"
  policy = data.aws_iam_policy_document.eventbridge.json
}

data "aws_iam_policy_document" "eventbridge" {
  statement {
    effect = "Allow"
    actions = [
      "codepipeline:StartPipelineExecution"
    ]
    resources = [
      aws_codepipeline.this.arn
    ]
  }
}

