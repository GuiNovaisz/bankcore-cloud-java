terraform {

  required_version = "= 1.17.2"
  required_providers {

    aws = {
      source = "hashicorp/aws", version = "= 6.73.0"
    }
    random = {
      source = "hashicorp/random", version = "= 3.9.1"
    }

  }

}
provider "aws" {

  region = var.region
  default_tags {
    tags = {
      project = "bankcore-cloud", environment = "sandbox", managed-by = "terraform", owner = "portfolio"
    }
  }

}

