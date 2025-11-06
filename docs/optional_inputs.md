# Optional inputs

```hcl
module "pipeline" {
  ...
  branch                = "main"
  mode                  = "SUPERSEDED"
  detect_changes        = false
  kms_key               = aws_kms_key.this.arn
  access_logging_bucket = aws_s3_bucket.this.id
  artifact_retention    = 90
  log_retention         = 90
}
```

`branch` is the branch to source. It defaults to `main`.

`mode` is [pipeline execution mode](https://docs.aws.amazon.com/codepipeline/latest/userguide/concepts-how-it-works.html#concepts-how-it-works-executions). It defaults to `SUPERSEDED`.

`detect_changes` is used with third-party services, like GitHub. It enables AWS CodeConnections to invoke the pipeline when there is a commit to the repo. It defaults to `false`.

`kms_key` is the arn of an *existing* AWS KMS key. This input will encrypt the Amazon S3 bucket with a AWS KMS key of your choice. Otherwise the bucket will be encrypted using SSE-S3. Your AWS KMS key policy will need to allow codebuild and codepipeline to `kms:GenerateDataKey*` and `kms:Decrypt`.

`access_logging_bucket` S3 server access logs bucket ARN, enables server access logging on the S3 artifact bucket.

`artifact_retention` controls the S3 artifact bucket retention period. It defaults to 90 (days). 

`log_retention` controls the CloudWatch log group retention period. It defaults to 90 (days).

```hcl
module "pipeline" {
  ...
  codebuild_policy  = aws_iam_policy.this.arn
  build_timeout     = 10
  terraform_version = "1.8.0"
  checkov_version   = "3.2.0"
  tflint_version    = "0.55.0"

  build_override = {
    plan_buildspec  = file("./my_plan.yml")
    plan_image      = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    apply_buildspec = file("./my_apply.yml")
    apply_image     = "hashicorp/terraform:latest"
  }
}
```

`codebuild_policy` replaces the [AWSAdministratorAccess](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AdministratorAccess.html) IAM policy. This can be used if you want to scope the permissions of the pipeline. 

`build_timeout` is the CodeBuild project build timeout. It defaults to 10 (minutes). 

`terraform_version` controls the terraform version. It defaults to 1.5.7.

`checkov_version` controls the [Checkov](https://www.checkov.io/) version. It defaults to latest.

`tflint_version` controls the [tflint](https://github.com/terraform-linters/tflint) version. It defaults to 0.48.0.

`build_override` can replace the existing CodeBuild buildspecs and images with your own.

```hcl
module "pipeline" {
  ...
  vpc = {
    vpc_id             = "vpc-011a22334455bb66c",
    subnets            = ["subnet-011aabbcc2233d4ef"],
    security_group_ids = ["sg-001abcd2233ee4455"],
  }

  notifications = {
    sns_topic   = aws_sns_topic.this.arn
    detail_type = "BASIC"
    events = [
      "codepipeline-pipeline-pipeline-execution-failed",
      "codepipeline-pipeline-pipeline-execution-succeeded"
    ]
  }
  
  tags = join(",", [
    "Environment[Dev,Prod]",
    "Source"
  ])
  tagnag_version = "0.7.9"

  checkov_skip = [
    "CKV_AWS_144", #Ensure that S3 bucket has cross-region replication enabled
  ]
}
```

`vpc` configures the CodeBuild projects to [run in a VPC](https://docs.aws.amazon.com/codebuild/latest/userguide/vpc-support.html).  

`notifications` creates a [CodeStar notification](https://docs.aws.amazon.com/dtconsole/latest/userguide/welcome.html) for the pipeline. `sns_topic` is the SNS topic arn. `events` are the [notification events](https://docs.aws.amazon.com/dtconsole/latest/userguide/concepts.html#events-ref-pipeline). `detail_type` is either BASIC or FULL. The SNS topic must allow [codestar-notifications.amazonaws.com to publush to the topic](https://docs.aws.amazon.com/dtconsole/latest/userguide/notification-target-create.html). 

`tags` enables tag validation with [tag-nag](https://github.com/jakebark/tag-nag). Input a list of tag keys and/or tag keys and values to enforce. Input must be passed as a string, see [commands](https://github.com/jakebark/tag-nag?tab=readme-ov-file#commands). 

`tagnag_version` controls the [tag-nag](https://github.com/jakebark/tag-nag) version. It defaults to 0.5.8.

`checkov_skip` defines [Checkov](https://www.checkov.io/) skips for the pipeline. This is useful for organization-wide policies, removing the need to add individual resource skips. 
