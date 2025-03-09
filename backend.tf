terraform {
    backend "s3" {
        bucket = "my-terraform-state-bucket7878"
        key    = "terraform/state.tfstate"
        region = "ap-south-1"
        encrypt = true  
    }
}
