output "pipeline" {
  description = "The CodePipeline resource"
  value       = aws_codepipeline.this
}

output "pipeline_role" {
  description = "IAM role used by CodePipeline"
  value       = aws_iam_role.codepipeline_role
}

output "codebuild_validate_role" {
  description = "IAM role used by validation CodeBuild projects"
  value       = aws_iam_role.codebuild_validate
}

output "codebuild_execution_role" {
  description = "IAM role used by plan and apply CodeBuild projects"
  value       = aws_iam_role.codebuild_execution
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for CodeBuild projects"
  value       = aws_cloudwatch_log_group.this
}

output "bucket" {
  description = "S3 bucket used for pipeline artifacts"
  value       = aws_s3_bucket.this
}
