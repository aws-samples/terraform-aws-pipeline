resource "aws_codepipeline" "pr" {
  count          = var.pr_pipeline ? 1 : 0
  name           = local.pr_pipeline
  pipeline_type  = "V2"
  role_arn       = aws_iam_role.codepipeline_role.arn
  execution_mode = var.mode

  artifact_store {
    location = aws_s3_bucket.this.id
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = var.connection == null ? "CodeCommit" : "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        RepositoryName       = var.connection == null ? var.repo : null
        FullRepositoryId     = var.connection == null ? null : var.repo
        ConnectionArn        = var.connection
        BranchName           = var.connection == null ? "main" : var.branch
        PollForSourceChanges = false
        DetectChanges        = var.connection == null ? null : false
      }
    }
  }

  stage {
    name = "Validation"
    dynamic "action" {
      for_each = var.tags == "" ? local.validation_stages : local.conditional_validation_stages
      content {
        name            = action.key
        category        = "Test"
        owner           = "AWS"
        provider        = "CodeBuild"
        input_artifacts = ["source_output"]
        version         = "1"

        configuration = {
          ProjectName = module.validation[action.key].codebuild_project.name
        }
      }
    }
  }

  stage {

    name = "Plan"
    action {
      name            = "Plan"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source_output"]
      version         = "1"
      run_order       = 1

      configuration = {
        ProjectName = module.plan.codebuild_project.name
      }
    }
  }
}

resource "aws_ssm_document" "this" {
  count           = var.pr_pipeline && var.connection == null ? 1 : 0
  name            = local.pr_pipeline
  document_type   = "Automation"
  document_format = "YAML"

  content = <<DOC
schemaVersion: '0.3'
assumeRole: '${aws_iam_role.ssm[0].arn}'
parameters:
  BranchName:
    type: String
  CommitId:
    type: String
mainSteps:
  - name: StartPipelineExecution
    action: 'aws:executeAwsApi'
    inputs:
      Service: codepipeline
      Api: StartPipelineExecution
      pipelineName: '${var.pipeline_name}-PR'
      sourceRevisions:
        - actionName: Source
          revisionType: COMMIT_ID
          revision: '{{ CommitId }}'
DOC
}

resource "aws_iam_role" "ssm" {
  count = var.pr_pipeline && var.connection == null ? 1 : 0
  name  = "${var.pipeline_name}-pr-automation"

  assume_role_policy = data.aws_iam_policy_document.ssm_assume.json

}

data "aws_iam_policy_document" "ssm_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
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

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm[0].name
  policy_arn = aws_iam_policy.ssm[0].arn
}

resource "aws_iam_policy" "ssm" {
  name   = "${var.pipeline_name}-ssm"
  policy = data.aws_iam_policy_document.ssm.json
}

data "aws_iam_policy_document" "ssm" {
  statement {
    effect = "Allow"
    actions = [
      "codepipeline:StartPipelineExecution"
    ]
    resources = [
      aws_codepipeline.pr[0].arn
    ]
  }
}

resource "aws_cloudwatch_event_rule" "pr" {
  count       = var.pr_pipeline && var.connection == null ? 1 : 0
  name        = "${var.pipeline_name}-pr-created"
  description = "Trigger PR pipeline on pull request creation"

  event_pattern = jsonencode({
    source      = ["aws.codecommit"]
    detail-type = ["CodeCommit Pull Request State Change"]
    detail = {
      event          = ["pullRequestCreated"]
      repositoryName = [var.repo]
    }
  })
}

resource "aws_cloudwatch_event_target" "ssm" {
  count     = var.pr_pipeline && var.connection == null ? 1 : 0
  rule      = aws_cloudwatch_event_rule.pr[0].name
  target_id = "PRAutomationTarget"
  arn       = "arn:aws:ssm:${local.region}:${data.aws_caller_identity.current.account_id}:automation-definition/${aws_ssm_document.this[0].name}"
  role_arn  = aws_iam_role.eventbridge.arn

  input_transformer {
    input_paths = {
      branch = "$.detail.sourceReference"
      commit = "$.detail.sourceCommit"
    }
    input_template = jsonencode({
      BranchName = "<branch>"
      CommitId   = "<commit>"
    })
  }
}
