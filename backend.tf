terraform {
    backend "s3" {
        bucket = var.bucket_name
        key    = "terraform/state.tfstate"
        region = "us-east-1"
        encrypt = true
        Versioning = true
        dynamodb_table = "terraform_lock"   
    }
    }
