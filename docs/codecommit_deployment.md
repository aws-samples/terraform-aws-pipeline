# Codecommit deployment

If you are using CodeCommit, the module must be deployed to a separate repository to the code that you want to push through it.

```
your repo
   modules
   backend.tf 
   main.tf
   provider.tf
   variables.tf    

pipeline repo 
   main.tf <--module deployed here
```

Segregation enables the pipeline to run commands against the code in "your repo" without affecting the pipeline infrastructure. 

## Example deployment

Pipeline repo `main.tf`
```hcl
resource "aws_codecommit_repository" "this" {
  repository_name = "demo"
  description     = "demo infrastructure"
}
module "pipeline" {
  source        = "aws-samples/pipeline/aws"
  version       = "2.4.0"
  pipeline_name = aws_codecommit_repository.this.repository_name
  repo          = aws_codecommit_repository.this.repository_name
  kms_key       = aws_kms_key.this.arn
}
```

The above will build a paired repo and pipeline to use. Any code pushed to the `demo` repository will run through the pipeline. 
