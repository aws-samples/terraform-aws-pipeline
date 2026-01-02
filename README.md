# terraform-aws-pipeline
 
Deploy Terraform with Terraform. 

🐓 🥚 ?

(If you want to deploy to multiple AWS accounts use [terraform-multi-account-pipeline](https://github.com/aws-samples/terraform-multi-account-pipeline))

## Prerequisites
- An existing AWS CodeCommit repository *OR* an [AWS CodeConnection connection](https://docs.aws.amazon.com/dtconsole/latest/userguide/welcome-connections.html) to the third-party source and repo of your choice (GitHub, Gitlab, etc)
- [Remote state](https://developer.hashicorp.com/terraform/language/state/remote) that the pipeline can access (using the CodeBuild IAM role)  

## Module Inputs

AWS Codecommit:
```hcl
module "pipeline" {
  source        = "aws-samples/pipeline/aws"
  version       = "2.4.x"
  pipeline_name = "pipeline-name"
  repo          = "codecommit-repo-name"
}
```
If you are using CodeCommit, the module must be deployed to a separate repository to the code that you want to push through it. See [codecommit deployment](./docs/codecommit_deployment.md)

Third-party service:
```hcl
module "pipeline" {
  source        = "aws-samples/pipeline/aws"
  version       = "2.4.x"
  pipeline_name = "pipeline-name"
  repo          = "organization/repo"
  connection    = aws_codestarconnections_connection.this.arn
}
```
`pipeline_name` is used to name the pipeline and prefix other resources created, like IAM roles. 

`repo` is the name of your existing repo that the pipeline will use as a source. If you are using a third-party service, the format is "my-organization/repo"  

`connection` is the connection arn of the [connection](https://docs.aws.amazon.com/dtconsole/latest/userguide/welcome-connections.html) to the third-party repo. 

### Optional Inputs

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

  codebuild_policy  = aws_iam_policy.this.arn
  build_timeout     = 10
  terraform_version = "1.8.0"
  checkov_version   = "3.2.0"
  tflint_version    = "0.55.0"

  build_override = {
    directory       = "terraform"
    plan_buildspec  = file("./my_plan.yml")
    plan_image      = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    apply_buildspec = file("./my_apply.yml")
    apply_image     = "hashicorp/terraform:latest"
  }

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

See [optional inputs](./docs/optional_inputs.md) for descriptions. 

## Docs

- [Optional inputs](./docs/optional_inputs.md)
- [Architecture](./docs/architecture.md)
- [Setup a cross account pipeline](./docs/cross_account_pipeline.md)
- [Codecommit deployment](./docs/codecommit_deployment.md)
- [Troubleshooting](./docs/troubleshooting.md)

## Related Resources

- [terraform-multi-account-pipeline](https://github.com/aws-samples/terraform-multi-account-pipeline)
- [Terraform Registry: aws-samples/pipeline/aws](https://registry.terraform.io/modules/aws-samples/pipeline/aws/latest)

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.
